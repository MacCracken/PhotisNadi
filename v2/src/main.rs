//! Photis Nadi — AI-native task management and ritual tracking for AGNOS

use std::sync::{Arc, Mutex};

use clap::Parser;

use photisnadi_agnos::AgnosIntegration;
use photisnadi_mcp::tool_definitions;
use photisnadi_server::AppState;
use photisnadi_store::Store;

#[derive(Parser)]
#[command(name = "photisnadi", version, about = "AI-native task management and ritual tracking for AGNOS")]
struct Cli {
    /// Path to SQLite database file
    #[arg(long, default_value = "photisnadi.db")]
    db: String,

    /// Run in headless mode (HTTP server only, no UI)
    #[arg(long)]
    headless: bool,

    /// Run as MCP server over stdin/stdout
    #[arg(long)]
    mcp: bool,

    /// Bind address for HTTP server
    #[arg(long, default_value = "0.0.0.0")]
    bind: String,

    /// Port for HTTP server
    #[arg(long, default_value = "8094")]
    port: u16,

    /// API key for authentication (overrides PHOTISNADI_API_KEY env var)
    #[arg(long)]
    api_key: Option<String>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info".into()),
        )
        .with_writer(std::io::stderr)
        .init();

    let cli = Cli::parse();

    // MCP mode: stdio transport, no HTTP
    if cli.mcp {
        let store = Store::new(&cli.db)?;
        let store = Arc::new(Mutex::new(store));
        tracing::info!("Starting Photis Nadi MCP server (stdio)");
        photisnadi_mcp::transport::run_mcp_stdio(store).await;
        return Ok(());
    }

    // Resolve API key
    let env_key = std::env::var("PHOTISNADI_API_KEY").ok();
    let api_key = cli.api_key.or(env_key.clone());
    let allow_handshake = api_key.is_none();
    let api_key = api_key.unwrap_or_else(|| {
        use rand::Rng;
        let key: String = rand::thread_rng()
            .sample_iter(&rand::distributions::Alphanumeric)
            .take(32)
            .map(char::from)
            .collect();
        tracing::info!("Generated API key (use handshake endpoint to retrieve): {key}");
        key
    });

    let store = Store::new(&cli.db)?;
    let addr = format!("{}:{}", cli.bind, cli.port);

    let mut state = AppState::new(store, api_key.clone()).with_handshake(allow_handshake);

    // AGNOS integration (env-var driven)
    let agent_registry_url = std::env::var("AGNOS_AGENT_REGISTRY_URL").ok();
    let audit_url = std::env::var("AGNOS_AUDIT_URL").ok();
    let api_url = std::env::var("PHOTISNADI_API_URL")
        .unwrap_or_else(|_| format!("http://localhost:{}", cli.port));

    if agent_registry_url.is_some() || audit_url.is_some() {
        let agnos = AgnosIntegration::new(
            api_url,
            api_key.clone(),
            agent_registry_url,
            audit_url,
        );
        state = state.with_agnos(agnos);
    }

    // Register with AGNOS if configured
    if let Some(agnos) = &state.agnos {
        if agnos.is_agent_registry_enabled() {
            agnos.register_agent().await;

            // Register MCP tools
            let tools: Vec<serde_json::Value> = tool_definitions()
                .into_iter()
                .map(|t| {
                    serde_json::json!({
                        "name": t.name,
                        "description": t.description,
                        "inputSchema": t.input_schema,
                    })
                })
                .collect();
            agnos.register_mcp_tools(tools).await;
        }
    }

    tracing::info!("Starting Photis Nadi server on {addr}");

    // Graceful shutdown
    let agnos_for_shutdown = state.agnos.clone();
    let server = photisnadi_server::serve(state, &addr);

    tokio::select! {
        result = server => {
            result?;
        }
        _ = tokio::signal::ctrl_c() => {
            tracing::info!("Shutting down...");
            if let Some(agnos) = agnos_for_shutdown {
                agnos.shutdown().await;
            }
        }
    }

    Ok(())
}
