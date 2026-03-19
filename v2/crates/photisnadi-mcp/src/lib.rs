//! Photis Nadi MCP Server — 6 MCP tools + stdio transport

pub mod transport;

use std::sync::{Arc, Mutex};

use chrono::{DateTime, Utc};
use photisnadi_core::*;
use photisnadi_store::Store;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolDescription {
    pub name: String,
    pub description: String,
    pub input_schema: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolResult {
    pub content: serde_json::Value,
    pub is_error: bool,
}

impl ToolResult {
    fn ok(value: serde_json::Value) -> Self {
        Self {
            content: value,
            is_error: false,
        }
    }

    fn err(message: &str) -> Self {
        Self {
            content: serde_json::json!({ "error": message }),
            is_error: true,
        }
    }
}

pub fn tool_definitions() -> Vec<ToolDescription> {
    vec![
        ToolDescription {
            name: "photis_list_tasks".to_string(),
            description: "List tasks from Photis Nadi with optional filters for project, status, and priority.".to_string(),
            input_schema: serde_json::json!({
                "type": "object",
                "properties": {
                    "project_id": {"type": "string", "description": "Filter by project ID"},
                    "status": {"type": "string", "enum": ["todo", "inProgress", "inReview", "blocked", "done"], "description": "Filter by task status"},
                    "priority": {"type": "string", "enum": ["low", "medium", "high"], "description": "Filter by priority"},
                    "limit": {"type": "number", "description": "Max results (default 50)"}
                }
            }),
        },
        ToolDescription {
            name: "photis_create_task".to_string(),
            description: "Create a new task in Photis Nadi.".to_string(),
            input_schema: serde_json::json!({
                "type": "object",
                "properties": {
                    "title": {"type": "string", "description": "Task title"},
                    "description": {"type": "string", "description": "Task description"},
                    "project_id": {"type": "string", "description": "Project ID"},
                    "priority": {"type": "string", "enum": ["low", "medium", "high"]},
                    "status": {"type": "string", "enum": ["todo", "inProgress", "inReview", "blocked", "done"]},
                    "due_date": {"type": "string", "format": "date-time"},
                    "tags": {"type": "array", "items": {"type": "string"}}
                },
                "required": ["title"]
            }),
        },
        ToolDescription {
            name: "photis_update_task".to_string(),
            description: "Update an existing task in Photis Nadi.".to_string(),
            input_schema: serde_json::json!({
                "type": "object",
                "properties": {
                    "task_id": {"type": "string", "description": "Task ID to update"},
                    "title": {"type": "string"},
                    "description": {"type": "string"},
                    "status": {"type": "string", "enum": ["todo", "inProgress", "inReview", "blocked", "done"]},
                    "priority": {"type": "string", "enum": ["low", "medium", "high"]},
                    "due_date": {"type": "string", "format": "date-time"},
                    "tags": {"type": "array", "items": {"type": "string"}}
                },
                "required": ["task_id"]
            }),
        },
        ToolDescription {
            name: "photis_list_projects".to_string(),
            description: "List projects from Photis Nadi.".to_string(),
            input_schema: serde_json::json!({
                "type": "object",
                "properties": {
                    "include_archived": {"type": "boolean", "description": "Include archived projects"}
                }
            }),
        },
        ToolDescription {
            name: "photis_list_rituals".to_string(),
            description: "List rituals with completion status and streak data from Photis Nadi.".to_string(),
            input_schema: serde_json::json!({
                "type": "object",
                "properties": {
                    "frequency": {"type": "string", "enum": ["daily", "weekly", "monthly"], "description": "Filter by frequency"}
                }
            }),
        },
        ToolDescription {
            name: "photis_task_analytics".to_string(),
            description: "Get task analytics and productivity insights from Photis Nadi.".to_string(),
            input_schema: serde_json::json!({
                "type": "object",
                "properties": {}
            }),
        },
    ]
}

pub fn execute_tool(store: &Arc<Mutex<Store>>, name: &str, params: &serde_json::Value) -> ToolResult {
    match name {
        "photis_list_tasks" => handle_list_tasks(store, params),
        "photis_create_task" => handle_create_task(store, params),
        "photis_update_task" => handle_update_task(store, params),
        "photis_list_projects" => handle_list_projects(store, params),
        "photis_list_rituals" => handle_list_rituals(store, params),
        "photis_task_analytics" => handle_task_analytics(store),
        _ => ToolResult::err(&format!("Unknown tool: {name}")),
    }
}

fn handle_list_tasks(store: &Arc<Mutex<Store>>, params: &serde_json::Value) -> ToolResult {
    let filter = TaskFilter {
        project_id: params.get("project_id").and_then(|v| v.as_str()).map(String::from),
        status: params.get("status").and_then(|v| v.as_str()).and_then(|s| serde_json::from_value(serde_json::Value::String(s.to_string())).ok()),
        priority: params.get("priority").and_then(|v| v.as_str()).and_then(|s| serde_json::from_value(serde_json::Value::String(s.to_string())).ok()),
        limit: params.get("limit").and_then(|v| v.as_u64()).map(|n| n as usize),
    };

    let store = store.lock().unwrap();
    match store.list_tasks(&filter) {
        Ok(tasks) => ToolResult::ok(serde_json::to_value(&tasks).unwrap_or_default()),
        Err(e) => ToolResult::err(&e.to_string()),
    }
}

fn handle_create_task(store: &Arc<Mutex<Store>>, params: &serde_json::Value) -> ToolResult {
    let title = match params.get("title").and_then(|v| v.as_str()) {
        Some(t) if !t.trim().is_empty() => t.to_string(),
        _ => return ToolResult::err("title is required"),
    };

    let mut task = Task::new(title);

    if let Some(desc) = params.get("description").and_then(|v| v.as_str()) {
        task.description = Some(desc.to_string());
    }
    if let Some(pid) = params.get("project_id").and_then(|v| v.as_str()) {
        task.project_id = Some(pid.to_string());
    }
    if let Some(s) = params.get("status").and_then(|v| v.as_str()) {
        if let Ok(status) = serde_json::from_value(serde_json::Value::String(s.to_string())) {
            task.status = status;
        }
    }
    if let Some(p) = params.get("priority").and_then(|v| v.as_str()) {
        if let Ok(priority) = serde_json::from_value(serde_json::Value::String(p.to_string())) {
            task.priority = priority;
        }
    }
    if let Some(d) = params.get("due_date").and_then(|v| v.as_str()) {
        if let Ok(dt) = d.parse::<DateTime<Utc>>() {
            task.due_date = Some(dt);
        }
    }
    if let Some(tags) = params.get("tags").and_then(|v| v.as_array()) {
        task.tags = tags.iter().filter_map(|v| v.as_str().map(String::from)).collect();
    }

    // Generate task key if project exists
    let store = store.lock().unwrap();
    if let Some(pid) = &task.project_id {
        if let Ok(Some(mut project)) = store.get_project(pid) {
            task.task_key = Some(project.generate_next_task_key());
            project.modified_at = Utc::now();
            let _ = store.update_project(&project);
        }
    }

    match store.add_task(&task) {
        Ok(()) => ToolResult::ok(serde_json::to_value(&task).unwrap_or_default()),
        Err(e) => ToolResult::err(&e.to_string()),
    }
}

fn handle_update_task(store: &Arc<Mutex<Store>>, params: &serde_json::Value) -> ToolResult {
    let task_id = match params.get("task_id").and_then(|v| v.as_str()) {
        Some(id) => id,
        None => return ToolResult::err("task_id is required"),
    };

    let store = store.lock().unwrap();
    let mut task = match store.get_task(task_id) {
        Ok(Some(t)) => t,
        Ok(None) => return ToolResult::err("Task not found"),
        Err(e) => return ToolResult::err(&e.to_string()),
    };

    if let Some(t) = params.get("title").and_then(|v| v.as_str()) {
        if t.trim().is_empty() {
            return ToolResult::err("title cannot be empty");
        }
        task.title = t.to_string();
    }
    if let Some(d) = params.get("description") {
        task.description = d.as_str().map(String::from);
    }
    if let Some(s) = params.get("status").and_then(|v| v.as_str()) {
        if let Ok(status) = serde_json::from_value(serde_json::Value::String(s.to_string())) {
            task.status = status;
        }
    }
    if let Some(p) = params.get("priority").and_then(|v| v.as_str()) {
        if let Ok(priority) = serde_json::from_value(serde_json::Value::String(p.to_string())) {
            task.priority = priority;
        }
    }
    if let Some(d) = params.get("due_date") {
        task.due_date = d.as_str().and_then(|s| s.parse::<DateTime<Utc>>().ok());
    }
    if let Some(tags) = params.get("tags").and_then(|v| v.as_array()) {
        task.tags = tags.iter().filter_map(|v| v.as_str().map(String::from)).collect();
    }

    task.modified_at = Utc::now();

    match store.update_task(&task) {
        Ok(()) => ToolResult::ok(serde_json::to_value(&task).unwrap_or_default()),
        Err(e) => ToolResult::err(&e.to_string()),
    }
}

fn handle_list_projects(store: &Arc<Mutex<Store>>, params: &serde_json::Value) -> ToolResult {
    let include_archived = params
        .get("include_archived")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    let store = store.lock().unwrap();
    match store.list_projects(include_archived) {
        Ok(projects) => ToolResult::ok(serde_json::to_value(&projects).unwrap_or_default()),
        Err(e) => ToolResult::err(&e.to_string()),
    }
}

fn handle_list_rituals(store: &Arc<Mutex<Store>>, params: &serde_json::Value) -> ToolResult {
    let frequency: Option<RitualFrequency> = params
        .get("frequency")
        .and_then(|v| v.as_str())
        .and_then(|s| serde_json::from_value(serde_json::Value::String(s.to_string())).ok());

    let store = store.lock().unwrap();
    match store.list_rituals(frequency.as_ref()) {
        Ok(rituals) => ToolResult::ok(serde_json::to_value(&rituals).unwrap_or_default()),
        Err(e) => ToolResult::err(&e.to_string()),
    }
}

fn handle_task_analytics(store: &Arc<Mutex<Store>>) -> ToolResult {
    let store = store.lock().unwrap();
    match store.task_analytics() {
        Ok(analytics) => ToolResult::ok(analytics),
        Err(e) => ToolResult::err(&e.to_string()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_store() -> Arc<Mutex<Store>> {
        Arc::new(Mutex::new(Store::new_in_memory().unwrap()))
    }

    #[test]
    fn tool_definitions_count() {
        assert_eq!(tool_definitions().len(), 6);
    }

    #[test]
    fn tool_names() {
        let tools = tool_definitions();
        let names: Vec<&str> = tools.iter().map(|t| t.name.as_str()).collect();
        assert!(names.contains(&"photis_list_tasks"));
        assert!(names.contains(&"photis_create_task"));
        assert!(names.contains(&"photis_update_task"));
        assert!(names.contains(&"photis_list_projects"));
        assert!(names.contains(&"photis_list_rituals"));
        assert!(names.contains(&"photis_task_analytics"));
    }

    #[test]
    fn list_tasks_empty() {
        let store = test_store();
        let result = execute_tool(&store, "photis_list_tasks", &serde_json::json!({}));
        assert!(!result.is_error);
        assert_eq!(result.content.as_array().unwrap().len(), 0);
    }

    #[test]
    fn create_task() {
        let store = test_store();
        let result = execute_tool(
            &store,
            "photis_create_task",
            &serde_json::json!({"title": "Test Task"}),
        );
        assert!(!result.is_error);
        assert_eq!(result.content["title"], "Test Task");
    }

    #[test]
    fn create_task_requires_title() {
        let store = test_store();
        let result = execute_tool(&store, "photis_create_task", &serde_json::json!({}));
        assert!(result.is_error);
    }

    #[test]
    fn update_task_not_found() {
        let store = test_store();
        let result = execute_tool(
            &store,
            "photis_update_task",
            &serde_json::json!({"task_id": "nonexistent"}),
        );
        assert!(result.is_error);
    }

    #[test]
    fn create_and_update_task() {
        let store = test_store();
        let created = execute_tool(
            &store,
            "photis_create_task",
            &serde_json::json!({"title": "Original"}),
        );
        let id = created.content["id"].as_str().unwrap();
        let updated = execute_tool(
            &store,
            "photis_update_task",
            &serde_json::json!({"task_id": id, "title": "Updated"}),
        );
        assert!(!updated.is_error);
        assert_eq!(updated.content["title"], "Updated");
    }

    #[test]
    fn list_projects_empty() {
        let store = test_store();
        let result = execute_tool(&store, "photis_list_projects", &serde_json::json!({}));
        assert!(!result.is_error);
    }

    #[test]
    fn list_rituals_empty() {
        let store = test_store();
        let result = execute_tool(&store, "photis_list_rituals", &serde_json::json!({}));
        assert!(!result.is_error);
    }

    #[test]
    fn task_analytics_empty() {
        let store = test_store();
        let result = execute_tool(&store, "photis_task_analytics", &serde_json::json!({}));
        assert!(!result.is_error);
        assert_eq!(result.content["total"], 0);
    }

    #[test]
    fn unknown_tool() {
        let store = test_store();
        let result = execute_tool(&store, "unknown_tool", &serde_json::json!({}));
        assert!(result.is_error);
    }
}
