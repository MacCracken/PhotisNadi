//! Photis Nadi Core — models, enums, and validators

use chrono::{DateTime, Datelike, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// ── Enums ──

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum TaskStatus {
    Todo,
    InProgress,
    InReview,
    Blocked,
    Done,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum TaskPriority {
    Low,
    Medium,
    High,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum RitualFrequency {
    Daily,
    Weekly,
    Monthly,
}

// ── Subtask ──

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Subtask {
    pub title: String,
    pub done: bool,
}

// ── Task ──

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    pub id: String,
    pub title: String,
    pub description: Option<String>,
    pub status: TaskStatus,
    pub priority: TaskPriority,
    pub created_at: DateTime<Utc>,
    pub modified_at: DateTime<Utc>,
    pub due_date: Option<DateTime<Utc>>,
    pub project_id: Option<String>,
    pub tags: Vec<String>,
    pub task_key: Option<String>,
    pub depends_on: Vec<String>,
    pub subtasks: Vec<Subtask>,
    pub estimated_minutes: Option<i32>,
    pub tracked_minutes: i32,
    pub recurrence: Option<String>,
    pub attachments: Vec<String>,
}

impl Task {
    pub fn new(title: String) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4().to_string(),
            title,
            description: None,
            status: TaskStatus::Todo,
            priority: TaskPriority::Medium,
            created_at: now,
            modified_at: now,
            due_date: None,
            project_id: None,
            tags: vec![],
            task_key: None,
            depends_on: vec![],
            subtasks: vec![],
            estimated_minutes: None,
            tracked_minutes: 0,
            recurrence: None,
            attachments: vec![],
        }
    }
}

// ── Board & BoardColumn ──

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BoardColumn {
    pub id: String,
    pub title: String,
    pub task_ids: Vec<String>,
    pub order: i32,
    pub color: String,
    pub status: TaskStatus,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Board {
    pub id: String,
    pub title: String,
    pub description: Option<String>,
    pub created_at: DateTime<Utc>,
    pub column_ids: Vec<String>,
    pub color: String,
    pub columns: Vec<BoardColumn>,
}

impl Board {
    pub fn default_board() -> Self {
        let now = Utc::now();
        let columns = default_columns();
        let column_ids = columns.iter().map(|c| c.id.clone()).collect();
        Self {
            id: Uuid::new_v4().to_string(),
            title: "Default Board".to_string(),
            description: None,
            created_at: now,
            column_ids,
            color: "#4A90E2".to_string(),
            columns,
        }
    }
}

pub fn default_columns() -> Vec<BoardColumn> {
    vec![
        BoardColumn {
            id: Uuid::new_v4().to_string(),
            title: "To Do".to_string(),
            task_ids: vec![],
            order: 0,
            color: "#808080".to_string(),
            status: TaskStatus::Todo,
        },
        BoardColumn {
            id: Uuid::new_v4().to_string(),
            title: "In Progress".to_string(),
            task_ids: vec![],
            order: 1,
            color: "#4A90E2".to_string(),
            status: TaskStatus::InProgress,
        },
        BoardColumn {
            id: Uuid::new_v4().to_string(),
            title: "In Review".to_string(),
            task_ids: vec![],
            order: 2,
            color: "#F5A623".to_string(),
            status: TaskStatus::InReview,
        },
        BoardColumn {
            id: Uuid::new_v4().to_string(),
            title: "Blocked".to_string(),
            task_ids: vec![],
            order: 3,
            color: "#D0021B".to_string(),
            status: TaskStatus::Blocked,
        },
        BoardColumn {
            id: Uuid::new_v4().to_string(),
            title: "Done".to_string(),
            task_ids: vec![],
            order: 4,
            color: "#7ED321".to_string(),
            status: TaskStatus::Done,
        },
    ]
}

// ── Project ──

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Project {
    pub id: String,
    pub name: String,
    pub project_key: String,
    pub description: Option<String>,
    pub created_at: DateTime<Utc>,
    pub modified_at: DateTime<Utc>,
    pub color: String,
    pub icon_name: Option<String>,
    pub task_counter: i32,
    pub is_archived: bool,
    pub boards: Vec<Board>,
    pub active_board_id: Option<String>,
}

impl Project {
    pub fn new(name: String, project_key: String) -> Self {
        let now = Utc::now();
        let board = Board::default_board();
        let active_board_id = Some(board.id.clone());
        Self {
            id: Uuid::new_v4().to_string(),
            name,
            project_key,
            description: None,
            created_at: now,
            modified_at: now,
            color: "#4A90E2".to_string(),
            icon_name: None,
            task_counter: 0,
            is_archived: false,
            boards: vec![board],
            active_board_id,
        }
    }

    pub fn generate_next_task_key(&mut self) -> String {
        self.task_counter += 1;
        format!("{}-{}", self.project_key, self.task_counter)
    }
}

// ── Ritual ──

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Ritual {
    pub id: String,
    pub title: String,
    pub description: Option<String>,
    pub is_completed: bool,
    pub created_at: DateTime<Utc>,
    pub last_completed: Option<DateTime<Utc>>,
    pub reset_time: Option<DateTime<Utc>>,
    pub streak_count: i32,
    pub frequency: RitualFrequency,
}

impl Ritual {
    pub fn new(title: String) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            title,
            description: None,
            is_completed: false,
            created_at: Utc::now(),
            last_completed: None,
            reset_time: None,
            streak_count: 0,
            frequency: RitualFrequency::Daily,
        }
    }

    pub fn mark_completed(&mut self) {
        self.is_completed = true;
        self.last_completed = Some(Utc::now());
        self.streak_count += 1;
    }

    pub fn reset_if_needed(&mut self) {
        let now = Utc::now();
        let last_reset = self.reset_time.unwrap_or(self.created_at);

        let should_reset = match self.frequency {
            RitualFrequency::Daily => {
                now.day() != last_reset.day()
                    || now.month() != last_reset.month()
                    || now.year() != last_reset.year()
            }
            RitualFrequency::Weekly => {
                let now_week = week_number(now);
                let last_week = week_number(last_reset);
                now_week != last_week || now.year() != last_reset.year()
            }
            RitualFrequency::Monthly => {
                now.month() != last_reset.month() || now.year() != last_reset.year()
            }
        };

        if should_reset {
            if self.is_completed {
                self.is_completed = false;
            } else {
                self.streak_count = 0;
            }
            self.reset_time = Some(now);
        }
    }
}

/// ISO 8601 week number.
pub fn week_number(date: DateTime<Utc>) -> u32 {
    date.iso_week().week()
}

// ── Tag ──

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Tag {
    pub id: String,
    pub name: String,
    pub color: String,
    pub project_id: String,
}

// ── TaskFilter ──

#[derive(Debug, Clone, Default)]
pub struct TaskFilter {
    pub project_id: Option<String>,
    pub status: Option<TaskStatus>,
    pub priority: Option<TaskPriority>,
    pub limit: Option<usize>,
}

// ── Validators ──

pub fn is_valid_hex_color(s: &str) -> bool {
    let s = s.strip_prefix('#').unwrap_or(s);
    (s.len() == 6 || s.len() == 8) && s.chars().all(|c| c.is_ascii_hexdigit())
}

pub fn normalize_hex_color(s: &str) -> String {
    let s = s.strip_prefix('#').unwrap_or(s);
    format!("#{}", &s[..6].to_uppercase())
}

pub fn is_valid_project_key(s: &str) -> bool {
    let len = s.len();
    (2..=5).contains(&len) && s.chars().all(|c| c.is_ascii_uppercase() || c.is_ascii_digit())
}

pub fn is_valid_uuid(s: &str) -> bool {
    Uuid::parse_str(s).is_ok()
}

pub fn generate_project_key(name: &str) -> String {
    name.split_whitespace()
        .take(3)
        .filter_map(|w| w.chars().next())
        .collect::<String>()
        .to_uppercase()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_hex_colors() {
        assert!(is_valid_hex_color("#4A90E2"));
        assert!(is_valid_hex_color("#4A90E2FF"));
        assert!(is_valid_hex_color("4A90E2"));
        assert!(!is_valid_hex_color("#ZZZ"));
        assert!(!is_valid_hex_color(""));
        assert!(!is_valid_hex_color("#12345"));
    }

    #[test]
    fn normalize_color() {
        assert_eq!(normalize_hex_color("#4a90e2"), "#4A90E2");
        assert_eq!(normalize_hex_color("4a90e2ff"), "#4A90E2");
    }

    #[test]
    fn valid_project_keys() {
        assert!(is_valid_project_key("PN"));
        assert!(is_valid_project_key("PROJ1"));
        assert!(!is_valid_project_key("p"));
        assert!(!is_valid_project_key("toolong"));
        assert!(!is_valid_project_key("ab"));
    }

    #[test]
    fn valid_uuids() {
        assert!(is_valid_uuid(&Uuid::new_v4().to_string()));
        assert!(!is_valid_uuid("not-a-uuid"));
    }

    #[test]
    fn generate_key_from_name() {
        assert_eq!(generate_project_key("Photis Nadi"), "PN");
        assert_eq!(generate_project_key("My Cool Project"), "MCP");
        assert_eq!(generate_project_key("single"), "S");
    }

    #[test]
    fn task_status_serde() {
        assert_eq!(
            serde_json::to_string(&TaskStatus::InProgress).unwrap(),
            "\"inProgress\""
        );
        assert_eq!(
            serde_json::from_str::<TaskStatus>("\"inReview\"").unwrap(),
            TaskStatus::InReview
        );
    }

    #[test]
    fn task_new_defaults() {
        let task = Task::new("Test".to_string());
        assert_eq!(task.title, "Test");
        assert_eq!(task.status, TaskStatus::Todo);
        assert_eq!(task.priority, TaskPriority::Medium);
        assert!(task.tags.is_empty());
    }

    #[test]
    fn project_generate_task_key() {
        let mut project = Project::new("Test".to_string(), "TST".to_string());
        assert_eq!(project.generate_next_task_key(), "TST-1");
        assert_eq!(project.generate_next_task_key(), "TST-2");
    }

    #[test]
    fn ritual_mark_completed() {
        let mut ritual = Ritual::new("Meditate".to_string());
        assert!(!ritual.is_completed);
        assert_eq!(ritual.streak_count, 0);
        ritual.mark_completed();
        assert!(ritual.is_completed);
        assert_eq!(ritual.streak_count, 1);
    }

    #[test]
    fn ritual_frequency_serde() {
        assert_eq!(
            serde_json::to_string(&RitualFrequency::Daily).unwrap(),
            "\"daily\""
        );
        assert_eq!(
            serde_json::from_str::<RitualFrequency>("\"weekly\"").unwrap(),
            RitualFrequency::Weekly
        );
    }

    #[test]
    fn week_number_basic() {
        let w = week_number(Utc::now());
        assert!(w >= 1 && w <= 53);
    }

    #[test]
    fn board_default_has_five_columns() {
        let board = Board::default_board();
        assert_eq!(board.columns.len(), 5);
        assert_eq!(board.column_ids.len(), 5);
    }
}
