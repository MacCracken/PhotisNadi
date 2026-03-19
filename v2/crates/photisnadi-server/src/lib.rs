//! Photis Nadi Server — Axum REST API matching v1 Dart contract

use std::sync::{Arc, Mutex};

use axum::{
    Json, Router,
    body::Body,
    extract::{Path, Query, State},
    http::{HeaderMap, Request, StatusCode},
    middleware::{self, Next},
    response::{IntoResponse, Response},
    routing::{get, patch, post},
};
use chrono::{DateTime, Utc};
use serde::Deserialize;
use serde_json::json;
use tower_http::cors::CorsLayer;

use photisnadi_agnos::AgnosIntegration;
use photisnadi_core::*;
use photisnadi_mcp::{execute_tool, tool_definitions};
use photisnadi_store::Store;

/// Shared application state.
#[derive(Clone)]
pub struct AppState {
    pub store: Arc<Mutex<Store>>,
    pub agnos: Option<Arc<AgnosIntegration>>,
    pub api_key: String,
    handshake_allowed: bool,
    handshake_claimed: Arc<Mutex<bool>>,
}

impl AppState {
    pub fn new(store: Store, api_key: String) -> Self {
        Self {
            store: Arc::new(Mutex::new(store)),
            agnos: None,
            api_key,
            handshake_allowed: false,
            handshake_claimed: Arc::new(Mutex::new(false)),
        }
    }

    pub fn with_agnos(mut self, agnos: AgnosIntegration) -> Self {
        self.agnos = Some(Arc::new(agnos));
        self
    }

    pub fn with_handshake(mut self, allowed: bool) -> Self {
        self.handshake_allowed = allowed;
        self
    }
}

/// Build the full axum router.
pub fn router(state: AppState) -> Router {
    let api = Router::new()
        // Health & handshake (no auth)
        .route("/api/v1/health", get(health))
        .route("/api/v1/handshake", post(handshake))
        // Tasks
        .route("/api/v1/tasks", get(list_tasks).post(create_task))
        .route(
            "/api/v1/tasks/{id}",
            patch(update_task).delete(delete_task),
        )
        // Projects
        .route("/api/v1/projects", get(list_projects).post(create_project))
        .route(
            "/api/v1/projects/{id}",
            patch(update_project).delete(delete_project),
        )
        // Rituals
        .route("/api/v1/rituals", get(list_rituals).post(create_ritual))
        .route(
            "/api/v1/rituals/{id}",
            patch(update_ritual).delete(delete_ritual),
        )
        .route("/api/v1/rituals/{id}/complete", post(complete_ritual))
        // Analytics
        .route("/api/v1/analytics", get(analytics))
        // MCP endpoints
        .route("/tools", get(mcp_list_tools))
        .route("/tools/{tool_name}", post(mcp_call_tool))
        .layer(middleware::from_fn_with_state(state.clone(), auth_middleware))
        .layer(CorsLayer::permissive())
        .with_state(state);

    api
}

/// Start the server on the given address.
pub async fn serve(state: AppState, addr: &str) -> anyhow::Result<()> {
    let app = router(state);
    let listener = tokio::net::TcpListener::bind(addr).await?;
    tracing::info!("photisnadi-server listening on {addr}");
    axum::serve(listener, app).await?;
    Ok(())
}

// ── Auth Middleware ──

const PUBLIC_PATHS: &[&str] = &["/api/v1/health", "/api/v1/handshake"];

async fn auth_middleware(
    State(state): State<AppState>,
    headers: HeaderMap,
    request: Request<Body>,
    next: Next,
) -> Response {
    let path = request.uri().path();

    // Strip trailing slashes for consistent matching
    let normalized = path.trim_end_matches('/');
    if PUBLIC_PATHS.contains(&normalized) {
        return next.run(request).await;
    }

    let auth_header = match headers.get("authorization").and_then(|v| v.to_str().ok()) {
        Some(h) => h.to_string(),
        None => {
            return (
                StatusCode::UNAUTHORIZED,
                Json(json!({"error": "Missing or invalid Authorization header"})),
            )
                .into_response();
        }
    };

    if !auth_header.to_lowercase().starts_with("bearer ") {
        return (
            StatusCode::UNAUTHORIZED,
            Json(json!({"error": "Missing or invalid Authorization header"})),
        )
            .into_response();
    }

    let token = &auth_header[7..];
    if !constant_time_equals(token, &state.api_key) {
        return (
            StatusCode::FORBIDDEN,
            Json(json!({"error": "Invalid API key"})),
        )
            .into_response();
    }

    next.run(request).await
}

fn constant_time_equals(a: &str, b: &str) -> bool {
    if a.len() != b.len() {
        return false;
    }
    let mut result = 0u8;
    for (x, y) in a.bytes().zip(b.bytes()) {
        result |= x ^ y;
    }
    result == 0
}

// ── Health & Handshake ──

async fn health(State(state): State<AppState>) -> Json<serde_json::Value> {
    let store = state.store.lock().unwrap();
    Json(json!({
        "status": "ok",
        "timestamp": Utc::now().to_rfc3339(),
        "tasks": store.task_count().unwrap_or(0),
        "projects": store.project_count().unwrap_or(0),
        "rituals": store.ritual_count().unwrap_or(0),
    }))
}

async fn handshake(State(state): State<AppState>) -> (StatusCode, Json<serde_json::Value>) {
    if !state.handshake_allowed {
        return (
            StatusCode::NOT_FOUND,
            Json(json!({"error": "Handshake not available — API key was pre-configured via PHOTISNADI_API_KEY"})),
        );
    }

    let mut claimed = state.handshake_claimed.lock().unwrap();
    if *claimed {
        return (
            StatusCode::FORBIDDEN,
            Json(json!({"error": "Handshake already claimed"})),
        );
    }
    *claimed = true;

    (
        StatusCode::OK,
        Json(json!({
            "api_key": state.api_key,
            "message": "API key granted. Use Authorization: Bearer <key> for subsequent requests.",
        })),
    )
}

// ── Tasks ──

#[derive(Debug, Deserialize)]
struct TaskQueryParams {
    project_id: Option<String>,
    status: Option<String>,
    priority: Option<String>,
    limit: Option<String>,
}

async fn list_tasks(
    State(state): State<AppState>,
    Query(params): Query<TaskQueryParams>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let status = if let Some(s) = &params.status {
        match serde_json::from_value::<TaskStatus>(serde_json::Value::String(s.clone())) {
            Ok(st) => Some(st),
            Err(_) => {
                return Err((
                    StatusCode::BAD_REQUEST,
                    Json(json!({"error": "Invalid status value"})),
                ));
            }
        }
    } else {
        None
    };

    let priority = if let Some(p) = &params.priority {
        match serde_json::from_value::<TaskPriority>(serde_json::Value::String(p.clone())) {
            Ok(pr) => Some(pr),
            Err(_) => {
                return Err((
                    StatusCode::BAD_REQUEST,
                    Json(json!({"error": "Invalid priority value"})),
                ));
            }
        }
    } else {
        None
    };

    let limit_val = params
        .limit
        .as_deref()
        .and_then(|s| s.parse::<usize>().ok())
        .unwrap_or(50)
        .min(1000);

    let filter = TaskFilter {
        project_id: params.project_id,
        status,
        priority,
        limit: Some(limit_val),
    };

    let store = state.store.lock().unwrap();
    let tasks = store.list_tasks(&filter).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )
    })?;

    Ok(Json(serde_json::to_value(&tasks).unwrap_or_default()))
}

async fn create_task(
    State(state): State<AppState>,
    Json(body): Json<serde_json::Value>,
) -> Result<(StatusCode, Json<serde_json::Value>), (StatusCode, Json<serde_json::Value>)> {
    let title = body
        .get("title")
        .and_then(|v| v.as_str())
        .filter(|s| !s.trim().is_empty())
        .ok_or_else(|| {
            (
                StatusCode::BAD_REQUEST,
                Json(json!({"error": "title is required"})),
            )
        })?;

    let mut task = Task::new(title.to_string());

    if let Some(desc) = body.get("description").and_then(|v| v.as_str()) {
        task.description = Some(desc.to_string());
    }
    if let Some(pid) = body.get("project_id").and_then(|v| v.as_str()) {
        task.project_id = Some(pid.to_string());
    }
    if let Some(s) = body.get("status").and_then(|v| v.as_str()) {
        task.status = serde_json::from_value(serde_json::Value::String(s.to_string()))
            .unwrap_or(TaskStatus::Todo);
    }
    if let Some(p) = body.get("priority").and_then(|v| v.as_str()) {
        task.priority = serde_json::from_value(serde_json::Value::String(p.to_string()))
            .unwrap_or(TaskPriority::Medium);
    }
    if let Some(d) = body.get("due_date").and_then(|v| v.as_str()) {
        task.due_date = d.parse::<DateTime<Utc>>().ok();
    }
    if let Some(tags) = body.get("tags").and_then(|v| v.as_array()) {
        task.tags = tags
            .iter()
            .filter_map(|v| v.as_str())
            .filter(|s| !s.is_empty())
            .map(String::from)
            .collect();
    }

    let store = state.store.lock().unwrap();

    // Auto-generate task key if project exists
    if let Some(pid) = &task.project_id {
        if let Ok(Some(mut project)) = store.get_project(pid) {
            task.task_key = Some(project.generate_next_task_key());
            project.modified_at = Utc::now();
            let _ = store.update_project(&project);
        }
    }

    store.add_task(&task).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )
    })?;

    if let Some(agnos) = &state.agnos {
        agnos.forward_audit_event(
            "create",
            "task",
            &task.id,
            Some(json!({"title": task.title, "project_id": task.project_id})),
        );
    }

    Ok((
        StatusCode::CREATED,
        Json(serde_json::to_value(&task).unwrap_or_default()),
    ))
}

async fn update_task(
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(body): Json<serde_json::Value>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let store = state.store.lock().unwrap();
    let mut task = store
        .get_task(&id)
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": e.to_string()})),
            )
        })?
        .ok_or_else(|| {
            (
                StatusCode::NOT_FOUND,
                Json(json!({"error": "Task not found"})),
            )
        })?;

    if body.get("title").is_some() {
        let title = body
            .get("title")
            .and_then(|v| v.as_str())
            .filter(|s| !s.trim().is_empty())
            .ok_or_else(|| {
                (
                    StatusCode::BAD_REQUEST,
                    Json(json!({"error": "title cannot be empty"})),
                )
            })?;
        task.title = title.to_string();
    }
    if body.get("description").is_some() {
        task.description = body.get("description").and_then(|v| v.as_str()).map(String::from);
    }
    if let Some(s) = body.get("status").and_then(|v| v.as_str()) {
        match serde_json::from_value::<TaskStatus>(serde_json::Value::String(s.to_string())) {
            Ok(st) => task.status = st,
            Err(_) => {
                return Err((
                    StatusCode::BAD_REQUEST,
                    Json(json!({"error": "Invalid status"})),
                ));
            }
        }
    }
    if let Some(p) = body.get("priority").and_then(|v| v.as_str()) {
        match serde_json::from_value::<TaskPriority>(serde_json::Value::String(p.to_string())) {
            Ok(pr) => task.priority = pr,
            Err(_) => {
                return Err((
                    StatusCode::BAD_REQUEST,
                    Json(json!({"error": "Invalid priority"})),
                ));
            }
        }
    }
    if body.get("due_date").is_some() {
        task.due_date = body
            .get("due_date")
            .and_then(|v| v.as_str())
            .and_then(|s| s.parse::<DateTime<Utc>>().ok());
    }
    if let Some(tags) = body.get("tags").and_then(|v| v.as_array()) {
        task.tags = tags
            .iter()
            .filter_map(|v| v.as_str())
            .filter(|s| !s.is_empty())
            .map(String::from)
            .collect();
    }

    task.modified_at = Utc::now();
    store.update_task(&task).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )
    })?;

    if let Some(agnos) = &state.agnos {
        agnos.forward_audit_event("update", "task", &id, Some(body));
    }

    Ok(Json(serde_json::to_value(&task).unwrap_or_default()))
}

async fn delete_task(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let store = state.store.lock().unwrap();

    if store
        .get_task(&id)
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": e.to_string()})),
            )
        })?
        .is_none()
    {
        return Err((
            StatusCode::NOT_FOUND,
            Json(json!({"error": "Task not found"})),
        ));
    }

    // Clean up dependency references
    let _ = store.remove_task_dependency(&id);

    store.delete_task(&id).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )
    })?;

    if let Some(agnos) = &state.agnos {
        agnos.forward_audit_event("delete", "task", &id, None);
    }

    Ok(StatusCode::NO_CONTENT)
}

// ── Projects ──

#[derive(Debug, Deserialize)]
struct ProjectQueryParams {
    include_archived: Option<String>,
}

async fn list_projects(
    State(state): State<AppState>,
    Query(params): Query<ProjectQueryParams>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let include_archived = params.include_archived.as_deref() == Some("true");
    let store = state.store.lock().unwrap();
    let projects = store.list_projects(include_archived).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )
    })?;
    Ok(Json(serde_json::to_value(&projects).unwrap_or_default()))
}

async fn create_project(
    State(state): State<AppState>,
    Json(body): Json<serde_json::Value>,
) -> Result<(StatusCode, Json<serde_json::Value>), (StatusCode, Json<serde_json::Value>)> {
    let name = body
        .get("name")
        .and_then(|v| v.as_str())
        .filter(|s| !s.trim().is_empty())
        .ok_or_else(|| {
            (
                StatusCode::BAD_REQUEST,
                Json(json!({"error": "name is required"})),
            )
        })?;

    let project_key = body
        .get("project_key")
        .and_then(|v| v.as_str())
        .filter(|s| !s.trim().is_empty())
        .ok_or_else(|| {
            (
                StatusCode::BAD_REQUEST,
                Json(json!({"error": "project_key is required"})),
            )
        })?;

    let normalized_key = project_key.to_uppercase().trim().to_string();
    if !is_valid_project_key(&normalized_key) {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(json!({"error": "project_key must be 2-5 uppercase alphanumeric characters"})),
        ));
    }

    let mut project = Project::new(name.to_string(), normalized_key.clone());

    if let Some(desc) = body.get("description").and_then(|v| v.as_str()) {
        project.description = Some(desc.to_string());
    }
    if let Some(color) = body.get("color").and_then(|v| v.as_str()) {
        project.color = color.to_string();
    }
    if let Some(icon) = body.get("icon_name").and_then(|v| v.as_str()) {
        project.icon_name = Some(icon.to_string());
    }

    let store = state.store.lock().unwrap();
    store.add_project(&project).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )
    })?;

    if let Some(agnos) = &state.agnos {
        agnos.forward_audit_event(
            "create",
            "project",
            &project.id,
            Some(json!({"name": name, "project_key": normalized_key})),
        );
    }

    Ok((
        StatusCode::CREATED,
        Json(serde_json::to_value(&project).unwrap_or_default()),
    ))
}

async fn update_project(
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(body): Json<serde_json::Value>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let store = state.store.lock().unwrap();
    let mut project = store
        .get_project(&id)
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": e.to_string()})),
            )
        })?
        .ok_or_else(|| {
            (
                StatusCode::NOT_FOUND,
                Json(json!({"error": "Project not found"})),
            )
        })?;

    if body.get("name").is_some() {
        let name = body
            .get("name")
            .and_then(|v| v.as_str())
            .filter(|s| !s.trim().is_empty())
            .ok_or_else(|| {
                (
                    StatusCode::BAD_REQUEST,
                    Json(json!({"error": "name cannot be empty"})),
                )
            })?;
        project.name = name.to_string();
    }
    if body.get("description").is_some() {
        project.description = body.get("description").and_then(|v| v.as_str()).map(String::from);
    }
    if let Some(color) = body.get("color").and_then(|v| v.as_str()) {
        project.color = color.to_string();
    }
    if body.get("icon_name").is_some() {
        project.icon_name = body.get("icon_name").and_then(|v| v.as_str()).map(String::from);
    }
    if let Some(archived) = body.get("is_archived").and_then(|v| v.as_bool()) {
        project.is_archived = archived;
    }

    project.modified_at = Utc::now();
    store.update_project(&project).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )
    })?;

    if let Some(agnos) = &state.agnos {
        agnos.forward_audit_event("update", "project", &id, Some(body));
    }

    Ok(Json(serde_json::to_value(&project).unwrap_or_default()))
}

async fn delete_project(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let store = state.store.lock().unwrap();

    if store
        .get_project(&id)
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": e.to_string()})),
            )
        })?
        .is_none()
    {
        return Err((
            StatusCode::NOT_FOUND,
            Json(json!({"error": "Project not found"})),
        ));
    }

    store.delete_project(&id).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )
    })?;

    if let Some(agnos) = &state.agnos {
        agnos.forward_audit_event("delete", "project", &id, None);
    }

    Ok(StatusCode::NO_CONTENT)
}

// ── Rituals ──

#[derive(Debug, Deserialize)]
struct RitualQueryParams {
    frequency: Option<String>,
}

async fn list_rituals(
    State(state): State<AppState>,
    Query(params): Query<RitualQueryParams>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let frequency = if let Some(f) = &params.frequency {
        match serde_json::from_value::<RitualFrequency>(serde_json::Value::String(f.clone())) {
            Ok(freq) => Some(freq),
            Err(_) => {
                return Err((
                    StatusCode::BAD_REQUEST,
                    Json(json!({"error": "Invalid frequency value"})),
                ));
            }
        }
    } else {
        None
    };

    let store = state.store.lock().unwrap();
    let rituals = store.list_rituals(frequency.as_ref()).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )
    })?;
    Ok(Json(serde_json::to_value(&rituals).unwrap_or_default()))
}

async fn create_ritual(
    State(state): State<AppState>,
    Json(body): Json<serde_json::Value>,
) -> Result<(StatusCode, Json<serde_json::Value>), (StatusCode, Json<serde_json::Value>)> {
    let title = body
        .get("title")
        .and_then(|v| v.as_str())
        .filter(|s| !s.trim().is_empty())
        .ok_or_else(|| {
            (
                StatusCode::BAD_REQUEST,
                Json(json!({"error": "title is required"})),
            )
        })?;

    let mut ritual = Ritual::new(title.to_string());

    if let Some(desc) = body.get("description").and_then(|v| v.as_str()) {
        ritual.description = Some(desc.to_string());
    }
    if let Some(f) = body.get("frequency").and_then(|v| v.as_str()) {
        ritual.frequency = serde_json::from_value(serde_json::Value::String(f.to_string()))
            .unwrap_or(RitualFrequency::Daily);
    }

    let store = state.store.lock().unwrap();
    store.add_ritual(&ritual).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )
    })?;

    if let Some(agnos) = &state.agnos {
        agnos.forward_audit_event(
            "create",
            "ritual",
            &ritual.id,
            Some(json!({"title": title})),
        );
    }

    Ok((
        StatusCode::CREATED,
        Json(serde_json::to_value(&ritual).unwrap_or_default()),
    ))
}

async fn update_ritual(
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(body): Json<serde_json::Value>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let store = state.store.lock().unwrap();
    let mut ritual = store
        .get_ritual(&id)
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": e.to_string()})),
            )
        })?
        .ok_or_else(|| {
            (
                StatusCode::NOT_FOUND,
                Json(json!({"error": "Ritual not found"})),
            )
        })?;

    if body.get("title").is_some() {
        let title = body
            .get("title")
            .and_then(|v| v.as_str())
            .filter(|s| !s.trim().is_empty())
            .ok_or_else(|| {
                (
                    StatusCode::BAD_REQUEST,
                    Json(json!({"error": "title cannot be empty"})),
                )
            })?;
        ritual.title = title.to_string();
    }
    if body.get("description").is_some() {
        ritual.description = body.get("description").and_then(|v| v.as_str()).map(String::from);
    }
    if let Some(f) = body.get("frequency").and_then(|v| v.as_str()) {
        if let Ok(freq) =
            serde_json::from_value::<RitualFrequency>(serde_json::Value::String(f.to_string()))
        {
            ritual.frequency = freq;
        }
    }

    store.update_ritual(&ritual).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )
    })?;

    if let Some(agnos) = &state.agnos {
        agnos.forward_audit_event("update", "ritual", &id, Some(body));
    }

    Ok(Json(serde_json::to_value(&ritual).unwrap_or_default()))
}

async fn delete_ritual(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let store = state.store.lock().unwrap();

    if store
        .get_ritual(&id)
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": e.to_string()})),
            )
        })?
        .is_none()
    {
        return Err((
            StatusCode::NOT_FOUND,
            Json(json!({"error": "Ritual not found"})),
        ));
    }

    store.delete_ritual(&id).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )
    })?;

    if let Some(agnos) = &state.agnos {
        agnos.forward_audit_event("delete", "ritual", &id, None);
    }

    Ok(StatusCode::NO_CONTENT)
}

async fn complete_ritual(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let store = state.store.lock().unwrap();
    let mut ritual = store
        .get_ritual(&id)
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": e.to_string()})),
            )
        })?
        .ok_or_else(|| {
            (
                StatusCode::NOT_FOUND,
                Json(json!({"error": "Ritual not found"})),
            )
        })?;

    ritual.mark_completed();
    store.update_ritual(&ritual).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )
    })?;

    if let Some(agnos) = &state.agnos {
        agnos.forward_audit_event("complete", "ritual", &id, None);
    }

    Ok(Json(serde_json::to_value(&ritual).unwrap_or_default()))
}

// ── Analytics ──

async fn analytics(
    State(state): State<AppState>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let store = state.store.lock().unwrap();
    let analytics = store.task_analytics().map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )
    })?;
    Ok(Json(analytics))
}

// ── MCP Endpoints ──

async fn mcp_list_tools() -> Json<serde_json::Value> {
    let tools = tool_definitions();
    Json(serde_json::to_value(&tools).unwrap())
}

async fn mcp_call_tool(
    State(state): State<AppState>,
    Path(tool_name): Path<String>,
    Json(params): Json<serde_json::Value>,
) -> (StatusCode, Json<serde_json::Value>) {
    let result = execute_tool(&state.store, &tool_name, &params);
    if result.is_error {
        (StatusCode::OK, Json(result.content))
    } else {
        (StatusCode::OK, Json(result.content))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::Body;
    use axum::http::Request;
    use tower::ServiceExt;

    fn test_state() -> AppState {
        AppState::new(Store::new_in_memory().unwrap(), "test-api-key".to_string())
    }

    fn auth_header() -> (&'static str, &'static str) {
        ("authorization", "Bearer test-api-key")
    }

    #[tokio::test]
    async fn health_check() {
        let app = router(test_state());
        let resp = app
            .oneshot(Request::get("/api/v1/health").body(Body::empty()).unwrap())
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::OK);
        let body = axum::body::to_bytes(resp.into_body(), usize::MAX).await.unwrap();
        let v: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(v["status"], "ok");
    }

    #[tokio::test]
    async fn auth_required() {
        let app = router(test_state());
        let resp = app
            .oneshot(Request::get("/api/v1/tasks").body(Body::empty()).unwrap())
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn auth_invalid_key() {
        let app = router(test_state());
        let resp = app
            .oneshot(
                Request::get("/api/v1/tasks")
                    .header("authorization", "Bearer wrong-key")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::FORBIDDEN);
    }

    #[tokio::test]
    async fn list_tasks_empty() {
        let app = router(test_state());
        let (k, v) = auth_header();
        let resp = app
            .oneshot(
                Request::get("/api/v1/tasks")
                    .header(k, v)
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::OK);
        let body = axum::body::to_bytes(resp.into_body(), usize::MAX).await.unwrap();
        let tasks: Vec<serde_json::Value> = serde_json::from_slice(&body).unwrap();
        assert!(tasks.is_empty());
    }

    #[tokio::test]
    async fn create_task_success() {
        let app = router(test_state());
        let (k, v) = auth_header();
        let resp = app
            .oneshot(
                Request::post("/api/v1/tasks")
                    .header(k, v)
                    .header("content-type", "application/json")
                    .body(Body::from(
                        serde_json::json!({"title": "Test Task"}).to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::CREATED);
        let body = axum::body::to_bytes(resp.into_body(), usize::MAX).await.unwrap();
        let task: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(task["title"], "Test Task");
    }

    #[tokio::test]
    async fn create_task_no_title() {
        let app = router(test_state());
        let (k, v) = auth_header();
        let resp = app
            .oneshot(
                Request::post("/api/v1/tasks")
                    .header(k, v)
                    .header("content-type", "application/json")
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn create_and_delete_task() {
        let state = test_state();

        // Create
        let app = router(state.clone());
        let (k, v) = auth_header();
        let resp = app
            .oneshot(
                Request::post("/api/v1/tasks")
                    .header(k, v)
                    .header("content-type", "application/json")
                    .body(Body::from(
                        serde_json::json!({"title": "Delete Me"}).to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let body = axum::body::to_bytes(resp.into_body(), usize::MAX).await.unwrap();
        let task: serde_json::Value = serde_json::from_slice(&body).unwrap();
        let id = task["id"].as_str().unwrap();

        // Delete
        let app = router(state);
        let resp = app
            .oneshot(
                Request::delete(format!("/api/v1/tasks/{id}"))
                    .header(k, v)
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::NO_CONTENT);
    }

    #[tokio::test]
    async fn create_and_list_projects() {
        let state = test_state();
        let (k, v) = auth_header();

        let app = router(state.clone());
        let resp = app
            .oneshot(
                Request::post("/api/v1/projects")
                    .header(k, v)
                    .header("content-type", "application/json")
                    .body(Body::from(
                        serde_json::json!({"name": "Test", "project_key": "TST"}).to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::CREATED);

        let app = router(state);
        let resp = app
            .oneshot(
                Request::get("/api/v1/projects")
                    .header(k, v)
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::OK);
        let body = axum::body::to_bytes(resp.into_body(), usize::MAX).await.unwrap();
        let projects: Vec<serde_json::Value> = serde_json::from_slice(&body).unwrap();
        assert_eq!(projects.len(), 1);
    }

    #[tokio::test]
    async fn create_ritual_and_complete() {
        let state = test_state();
        let (k, v) = auth_header();

        let app = router(state.clone());
        let resp = app
            .oneshot(
                Request::post("/api/v1/rituals")
                    .header(k, v)
                    .header("content-type", "application/json")
                    .body(Body::from(
                        serde_json::json!({"title": "Meditate"}).to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::CREATED);
        let body = axum::body::to_bytes(resp.into_body(), usize::MAX).await.unwrap();
        let ritual: serde_json::Value = serde_json::from_slice(&body).unwrap();
        let id = ritual["id"].as_str().unwrap();

        let app = router(state);
        let resp = app
            .oneshot(
                Request::post(format!("/api/v1/rituals/{id}/complete"))
                    .header(k, v)
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::OK);
        let body = axum::body::to_bytes(resp.into_body(), usize::MAX).await.unwrap();
        let ritual: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(ritual["is_completed"], true);
        assert_eq!(ritual["streak_count"], 1);
    }

    #[tokio::test]
    async fn analytics_endpoint() {
        let app = router(test_state());
        let (k, v) = auth_header();
        let resp = app
            .oneshot(
                Request::get("/api/v1/analytics")
                    .header(k, v)
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::OK);
        let body = axum::body::to_bytes(resp.into_body(), usize::MAX).await.unwrap();
        let analytics: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(analytics["total"], 0);
    }

    #[tokio::test]
    async fn mcp_list_tools_endpoint() {
        let app = router(test_state());
        let (k, v) = auth_header();
        let resp = app
            .oneshot(
                Request::get("/tools")
                    .header(k, v)
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::OK);
        let body = axum::body::to_bytes(resp.into_body(), usize::MAX).await.unwrap();
        let tools: Vec<serde_json::Value> = serde_json::from_slice(&body).unwrap();
        assert_eq!(tools.len(), 6);
    }

    #[tokio::test]
    async fn handshake_not_available_by_default() {
        let app = router(test_state());
        let resp = app
            .oneshot(
                Request::post("/api/v1/handshake")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn handshake_available_when_enabled() {
        let state = test_state().with_handshake(true);
        let app = router(state);
        let resp = app
            .oneshot(
                Request::post("/api/v1/handshake")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::OK);
        let body = axum::body::to_bytes(resp.into_body(), usize::MAX).await.unwrap();
        let v: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(v["api_key"], "test-api-key");
    }

    #[tokio::test]
    async fn delete_nonexistent_task() {
        let app = router(test_state());
        let (k, v) = auth_header();
        let resp = app
            .oneshot(
                Request::delete("/api/v1/tasks/nonexistent")
                    .header(k, v)
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn invalid_project_key() {
        let app = router(test_state());
        let (k, v) = auth_header();
        let resp = app
            .oneshot(
                Request::post("/api/v1/projects")
                    .header(k, v)
                    .header("content-type", "application/json")
                    .body(Body::from(
                        serde_json::json!({"name": "Test", "project_key": "toolongkey"})
                            .to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::BAD_REQUEST);
    }
}
