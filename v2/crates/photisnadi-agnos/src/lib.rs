//! Photis Nadi AGNOS Integration — agent registration, heartbeats, audit forwarding

use std::sync::Arc;

use chrono::Utc;
use serde_json::json;
use tokio::sync::Mutex;

/// AGNOS daimon integration for the Photis Nadi API server.
pub struct AgnosIntegration {
    client: reqwest::Client,
    agent_registry_url: Option<String>,
    audit_url: Option<String>,
    api_url: String,
    api_key: String,
    agent_id: Arc<Mutex<Option<String>>>,
    heartbeat_handle: Arc<Mutex<Option<tokio::task::JoinHandle<()>>>>,
}

impl AgnosIntegration {
    pub fn new(
        api_url: String,
        api_key: String,
        agent_registry_url: Option<String>,
        audit_url: Option<String>,
    ) -> Self {
        Self {
            client: reqwest::Client::new(),
            agent_registry_url,
            audit_url,
            api_url,
            api_key,
            agent_id: Arc::new(Mutex::new(None)),
            heartbeat_handle: Arc::new(Mutex::new(None)),
        }
    }

    pub fn is_agent_registry_enabled(&self) -> bool {
        self.agent_registry_url.is_some()
    }

    pub fn is_audit_enabled(&self) -> bool {
        self.audit_url.is_some()
    }

    pub async fn is_registered(&self) -> bool {
        self.agent_id.lock().await.is_some()
    }

    /// Register this server as an agent with daimon's agent runtime.
    pub async fn register_agent(&self) -> bool {
        let registry_url = match &self.agent_registry_url {
            Some(url) => url.clone(),
            None => return false,
        };

        let payload = json!({
            "name": "photisnadi",
            "display_name": "Photis Nadi",
            "description": "Task management and ritual tracking productivity app",
            "version": env!("CARGO_PKG_VERSION"),
            "endpoint": self.api_url,
            "health_endpoint": format!("{}/api/v1/health", self.api_url),
            "capabilities": ["tasks", "projects", "rituals", "analytics"],
        });

        match self
            .client
            .post(format!("{registry_url}/v1/agents/register"))
            .json(&payload)
            .timeout(std::time::Duration::from_secs(10))
            .send()
            .await
        {
            Ok(resp) if resp.status().is_success() => {
                if let Ok(data) = resp.json::<serde_json::Value>().await {
                    let id = data
                        .get("agent_id")
                        .or_else(|| data.get("id"))
                        .and_then(|v| v.as_str())
                        .map(String::from);

                    if let Some(id) = id {
                        tracing::info!("Registered with AGNOS daimon as agent {id}");
                        *self.agent_id.lock().await = Some(id);
                        self.start_heartbeat();
                        return true;
                    }
                }
                false
            }
            Ok(resp) => {
                tracing::warn!("AGNOS agent registration failed: {}", resp.status());
                false
            }
            Err(e) => {
                tracing::warn!("AGNOS agent registration error: {e}");
                false
            }
        }
    }

    /// Deregister this agent from daimon on shutdown.
    pub async fn deregister_agent(&self) {
        // Cancel heartbeat
        if let Some(handle) = self.heartbeat_handle.lock().await.take() {
            handle.abort();
        }

        let registry_url = match &self.agent_registry_url {
            Some(url) => url.clone(),
            None => return,
        };

        let agent_id = match self.agent_id.lock().await.take() {
            Some(id) => id,
            None => return,
        };

        let _ = self
            .client
            .delete(format!("{registry_url}/v1/agents/{agent_id}"))
            .timeout(std::time::Duration::from_secs(5))
            .send()
            .await;

        tracing::info!("Deregistered from AGNOS daimon");
    }

    fn start_heartbeat(&self) {
        let client = self.client.clone();
        let registry_url = self.agent_registry_url.clone().unwrap();
        let agent_id = self.agent_id.clone();

        let handle = tokio::spawn(async move {
            let mut interval = tokio::time::interval(std::time::Duration::from_secs(30));
            loop {
                interval.tick().await;

                let id = match agent_id.lock().await.clone() {
                    Some(id) => id,
                    None => break,
                };

                let payload = json!({
                    "status": "healthy",
                    "timestamp": Utc::now().to_rfc3339(),
                });

                match client
                    .post(format!("{registry_url}/v1/agents/{id}/heartbeat"))
                    .json(&payload)
                    .timeout(std::time::Duration::from_secs(5))
                    .send()
                    .await
                {
                    Ok(resp) if resp.status().as_u16() == 404 => {
                        tracing::warn!("Agent dropped from registry, clearing agent_id");
                        *agent_id.lock().await = None;
                        break;
                    }
                    Ok(resp) if resp.status().is_client_error() || resp.status().is_server_error() => {
                        tracing::warn!("AGNOS heartbeat failed: {}", resp.status());
                    }
                    Err(e) => {
                        tracing::warn!("AGNOS heartbeat error: {e}");
                    }
                    _ => {}
                }
            }
        });

        let heartbeat_handle = self.heartbeat_handle.clone();
        tokio::spawn(async move {
            *heartbeat_handle.lock().await = Some(handle);
        });
    }

    /// Register MCP tools with daimon.
    pub async fn register_mcp_tools(&self, tools: Vec<serde_json::Value>) -> bool {
        let registry_url = match &self.agent_registry_url {
            Some(url) => url.clone(),
            None => return false,
        };

        let agent_id = self.agent_id.lock().await.clone();

        let payload = json!({
            "agent_id": agent_id,
            "server_name": "Photis Nadi",
            "transport": "streamable-http",
            "endpoint": self.api_url,
            "auth": {
                "type": "bearer",
                "token": self.api_key,
            },
            "tools": tools,
        });

        match self
            .client
            .post(format!("{registry_url}/v1/mcp/tools"))
            .json(&payload)
            .timeout(std::time::Duration::from_secs(10))
            .send()
            .await
        {
            Ok(resp) if resp.status().is_success() => {
                tracing::info!("Registered {} MCP tools with AGNOS daimon", tools.len());
                true
            }
            Ok(resp) => {
                tracing::warn!("AGNOS MCP tool registration failed: {}", resp.status());
                false
            }
            Err(e) => {
                tracing::warn!("AGNOS MCP tool registration error: {e}");
                false
            }
        }
    }

    /// Forward a CRUD event to the AGNOS audit chain. Fire-and-forget.
    pub fn forward_audit_event(
        &self,
        action: &str,
        entity_type: &str,
        entity_id: &str,
        payload: Option<serde_json::Value>,
    ) {
        let audit_url = match &self.audit_url {
            Some(url) => url.clone(),
            None => return,
        };

        let client = self.client.clone();
        let action = action.to_string();
        let entity_type = entity_type.to_string();
        let entity_id = entity_id.to_string();

        tokio::spawn(async move {
            let mut body = json!({
                "source": "photisnadi",
                "action": action,
                "entity_type": entity_type,
                "entity_id": entity_id,
                "timestamp": Utc::now().to_rfc3339(),
            });

            if let Some(p) = payload {
                body["payload"] = p;
            }

            if let Err(e) = client
                .post(format!("{audit_url}/v1/audit/forward"))
                .json(&body)
                .timeout(std::time::Duration::from_secs(5))
                .send()
                .await
            {
                tracing::warn!("AGNOS audit forward error ({action} {entity_type}): {e}");
            }
        });
    }

    /// Clean shutdown: deregister agent and cancel timers.
    pub async fn shutdown(&self) {
        self.deregister_agent().await;
    }
}
