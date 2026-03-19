//! Photis Nadi Store — SQLite-backed storage for tasks, projects, rituals, and tags

use anyhow::Result;
use chrono::{Duration, Utc};
use rusqlite::{Connection, params};
use photisnadi_core::*;

pub struct Store {
    conn: Connection,
}

impl Store {
    pub fn new(path: &str) -> Result<Self> {
        let conn = Connection::open(path)?;
        let store = Self { conn };
        store.run_migrations()?;
        Ok(store)
    }

    pub fn new_in_memory() -> Result<Self> {
        let conn = Connection::open_in_memory()?;
        let store = Self { conn };
        store.run_migrations()?;
        Ok(store)
    }

    fn run_migrations(&self) -> Result<()> {
        self.conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS tasks (
                id TEXT PRIMARY KEY,
                data TEXT NOT NULL,
                project_id TEXT,
                status TEXT NOT NULL,
                priority TEXT NOT NULL,
                modified_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS projects (
                id TEXT PRIMARY KEY,
                data TEXT NOT NULL,
                name TEXT NOT NULL,
                is_archived INTEGER NOT NULL DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS rituals (
                id TEXT PRIMARY KEY,
                data TEXT NOT NULL,
                frequency TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS tags (
                id TEXT PRIMARY KEY,
                data TEXT NOT NULL,
                project_id TEXT NOT NULL
            );",
        )?;
        Ok(())
    }

    // ── Tasks ──

    pub fn add_task(&self, task: &Task) -> Result<()> {
        let data = serde_json::to_string(task)?;
        self.conn.execute(
            "INSERT INTO tasks (id, data, project_id, status, priority, modified_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                task.id,
                data,
                task.project_id,
                serde_json::to_value(&task.status)?.as_str().unwrap_or("todo"),
                serde_json::to_value(&task.priority)?.as_str().unwrap_or("medium"),
                task.modified_at.to_rfc3339(),
            ],
        )?;
        Ok(())
    }

    pub fn get_task(&self, id: &str) -> Result<Option<Task>> {
        let mut stmt = self.conn.prepare("SELECT data FROM tasks WHERE id = ?1")?;
        let mut rows = stmt.query(params![id])?;
        match rows.next()? {
            Some(row) => {
                let data: String = row.get(0)?;
                Ok(Some(serde_json::from_str(&data)?))
            }
            None => Ok(None),
        }
    }

    pub fn list_tasks(&self, filter: &TaskFilter) -> Result<Vec<Task>> {
        let mut sql = "SELECT data FROM tasks WHERE 1=1".to_string();
        let mut params_vec: Vec<Box<dyn rusqlite::types::ToSql>> = vec![];

        if let Some(pid) = &filter.project_id {
            sql.push_str(" AND project_id = ?");
            params_vec.push(Box::new(pid.clone()));
        }
        if let Some(status) = &filter.status {
            let s = serde_json::to_value(status)?;
            sql.push_str(" AND status = ?");
            params_vec.push(Box::new(s.as_str().unwrap_or("todo").to_string()));
        }
        if let Some(priority) = &filter.priority {
            let p = serde_json::to_value(priority)?;
            sql.push_str(" AND priority = ?");
            params_vec.push(Box::new(p.as_str().unwrap_or("medium").to_string()));
        }

        sql.push_str(" ORDER BY modified_at DESC");

        let limit = filter.limit.unwrap_or(50).min(1000);
        sql.push_str(&format!(" LIMIT {limit}"));

        let mut stmt = self.conn.prepare(&sql)?;
        let param_refs: Vec<&dyn rusqlite::types::ToSql> =
            params_vec.iter().map(|p| p.as_ref()).collect();
        let rows = stmt.query_map(param_refs.as_slice(), |row| {
            let data: String = row.get(0)?;
            Ok(data)
        })?;

        let mut tasks = Vec::new();
        for row in rows {
            let data = row?;
            tasks.push(serde_json::from_str(&data)?);
        }
        Ok(tasks)
    }

    pub fn update_task(&self, task: &Task) -> Result<()> {
        let data = serde_json::to_string(task)?;
        self.conn.execute(
            "UPDATE tasks SET data = ?1, project_id = ?2, status = ?3, priority = ?4, modified_at = ?5 WHERE id = ?6",
            params![
                data,
                task.project_id,
                serde_json::to_value(&task.status)?.as_str().unwrap_or("todo"),
                serde_json::to_value(&task.priority)?.as_str().unwrap_or("medium"),
                task.modified_at.to_rfc3339(),
                task.id,
            ],
        )?;
        Ok(())
    }

    pub fn delete_task(&self, id: &str) -> Result<bool> {
        let rows = self.conn.execute("DELETE FROM tasks WHERE id = ?1", params![id])?;
        Ok(rows > 0)
    }

    pub fn remove_task_dependency(&self, task_id: &str) -> Result<()> {
        let all_tasks = self.list_tasks(&TaskFilter::default())?;
        for mut task in all_tasks {
            if task.depends_on.contains(&task_id.to_string()) {
                task.depends_on.retain(|d| d != task_id);
                task.modified_at = Utc::now();
                self.update_task(&task)?;
            }
        }
        Ok(())
    }

    // ── Projects ──

    pub fn add_project(&self, project: &Project) -> Result<()> {
        let data = serde_json::to_string(project)?;
        self.conn.execute(
            "INSERT INTO projects (id, data, name, is_archived) VALUES (?1, ?2, ?3, ?4)",
            params![project.id, data, project.name, project.is_archived as i32],
        )?;
        Ok(())
    }

    pub fn get_project(&self, id: &str) -> Result<Option<Project>> {
        let mut stmt = self.conn.prepare("SELECT data FROM projects WHERE id = ?1")?;
        let mut rows = stmt.query(params![id])?;
        match rows.next()? {
            Some(row) => {
                let data: String = row.get(0)?;
                Ok(Some(serde_json::from_str(&data)?))
            }
            None => Ok(None),
        }
    }

    pub fn list_projects(&self, include_archived: bool) -> Result<Vec<Project>> {
        let sql = if include_archived {
            "SELECT data FROM projects ORDER BY name ASC"
        } else {
            "SELECT data FROM projects WHERE is_archived = 0 ORDER BY name ASC"
        };

        let mut stmt = self.conn.prepare(sql)?;
        let rows = stmt.query_map([], |row| {
            let data: String = row.get(0)?;
            Ok(data)
        })?;

        let mut projects = Vec::new();
        for row in rows {
            let data = row?;
            projects.push(serde_json::from_str(&data)?);
        }
        Ok(projects)
    }

    pub fn update_project(&self, project: &Project) -> Result<()> {
        let data = serde_json::to_string(project)?;
        self.conn.execute(
            "UPDATE projects SET data = ?1, name = ?2, is_archived = ?3 WHERE id = ?4",
            params![data, project.name, project.is_archived as i32, project.id],
        )?;
        Ok(())
    }

    pub fn delete_project(&self, id: &str) -> Result<bool> {
        // Delete all tasks belonging to this project
        self.conn.execute("DELETE FROM tasks WHERE project_id = ?1", params![id])?;
        // Delete all tags belonging to this project
        self.conn.execute("DELETE FROM tags WHERE project_id = ?1", params![id])?;
        let rows = self.conn.execute("DELETE FROM projects WHERE id = ?1", params![id])?;
        Ok(rows > 0)
    }

    // ── Rituals ──

    pub fn add_ritual(&self, ritual: &Ritual) -> Result<()> {
        let data = serde_json::to_string(ritual)?;
        let freq = serde_json::to_value(&ritual.frequency)?;
        self.conn.execute(
            "INSERT INTO rituals (id, data, frequency) VALUES (?1, ?2, ?3)",
            params![ritual.id, data, freq.as_str().unwrap_or("daily")],
        )?;
        Ok(())
    }

    pub fn get_ritual(&self, id: &str) -> Result<Option<Ritual>> {
        let mut stmt = self.conn.prepare("SELECT data FROM rituals WHERE id = ?1")?;
        let mut rows = stmt.query(params![id])?;
        match rows.next()? {
            Some(row) => {
                let data: String = row.get(0)?;
                Ok(Some(serde_json::from_str(&data)?))
            }
            None => Ok(None),
        }
    }

    pub fn list_rituals(&self, frequency: Option<&RitualFrequency>) -> Result<Vec<Ritual>> {
        let mut rituals = if let Some(freq) = frequency {
            let freq_str = serde_json::to_value(freq)?;
            let mut stmt = self.conn.prepare(
                "SELECT data FROM rituals WHERE frequency = ?1 ORDER BY id",
            )?;
            let rows = stmt.query_map(params![freq_str.as_str().unwrap_or("daily")], |row| {
                let data: String = row.get(0)?;
                Ok(data)
            })?;
            let mut v: Vec<Ritual> = Vec::new();
            for row in rows {
                let data = row?;
                v.push(serde_json::from_str(&data)?);
            }
            v
        } else {
            let mut stmt = self.conn.prepare("SELECT data FROM rituals ORDER BY id")?;
            let rows = stmt.query_map([], |row| {
                let data: String = row.get(0)?;
                Ok(data)
            })?;
            let mut v: Vec<Ritual> = Vec::new();
            for row in rows {
                let data = row?;
                v.push(serde_json::from_str(&data)?);
            }
            v
        };

        // Auto-reset rituals that need it
        for ritual in &mut rituals {
            ritual.reset_if_needed();
            // Persist the reset
            self.update_ritual(ritual)?;
        }

        // Sort by title
        rituals.sort_by(|a, b| a.title.cmp(&b.title));
        Ok(rituals)
    }

    pub fn update_ritual(&self, ritual: &Ritual) -> Result<()> {
        let data = serde_json::to_string(ritual)?;
        let freq = serde_json::to_value(&ritual.frequency)?;
        self.conn.execute(
            "UPDATE rituals SET data = ?1, frequency = ?2 WHERE id = ?3",
            params![data, freq.as_str().unwrap_or("daily"), ritual.id],
        )?;
        Ok(())
    }

    pub fn delete_ritual(&self, id: &str) -> Result<bool> {
        let rows = self.conn.execute("DELETE FROM rituals WHERE id = ?1", params![id])?;
        Ok(rows > 0)
    }

    // ── Tags ──

    pub fn add_tag(&self, tag: &Tag) -> Result<()> {
        let data = serde_json::to_string(tag)?;
        self.conn.execute(
            "INSERT INTO tags (id, data, project_id) VALUES (?1, ?2, ?3)",
            params![tag.id, data, tag.project_id],
        )?;
        Ok(())
    }

    pub fn list_tags(&self, project_id: Option<&str>) -> Result<Vec<Tag>> {
        let (sql, params_vec): (String, Vec<Box<dyn rusqlite::types::ToSql>>) =
            if let Some(pid) = project_id {
                (
                    "SELECT data FROM tags WHERE project_id = ?1 ORDER BY id".to_string(),
                    vec![Box::new(pid.to_string())],
                )
            } else {
                (
                    "SELECT data FROM tags ORDER BY id".to_string(),
                    vec![],
                )
            };

        let mut stmt = self.conn.prepare(&sql)?;
        let param_refs: Vec<&dyn rusqlite::types::ToSql> =
            params_vec.iter().map(|p| p.as_ref()).collect();
        let rows = stmt.query_map(param_refs.as_slice(), |row| {
            let data: String = row.get(0)?;
            Ok(data)
        })?;

        let mut tags = Vec::new();
        for row in rows {
            let data = row?;
            tags.push(serde_json::from_str(&data)?);
        }
        Ok(tags)
    }

    pub fn delete_tag(&self, id: &str) -> Result<bool> {
        let rows = self.conn.execute("DELETE FROM tags WHERE id = ?1", params![id])?;
        Ok(rows > 0)
    }

    // ── Analytics ──

    pub fn task_analytics(&self) -> Result<serde_json::Value> {
        let all_tasks = self.list_tasks(&TaskFilter { limit: Some(10000), ..Default::default() })?;
        let now = Utc::now();
        let week_ago = now - Duration::days(7);

        let mut by_status = serde_json::Map::new();
        let mut by_priority = serde_json::Map::new();
        let mut overdue = 0i64;
        let mut due_today = 0i64;
        let mut blocked = 0i64;
        let mut completed_this_week = 0i64;

        for task in &all_tasks {
            let status_str = serde_json::to_value(&task.status)?
                .as_str()
                .unwrap_or("todo")
                .to_string();
            let priority_str = serde_json::to_value(&task.priority)?
                .as_str()
                .unwrap_or("medium")
                .to_string();

            *by_status
                .entry(status_str)
                .or_insert_with(|| serde_json::Value::Number(0.into())) = {
                let n = by_status
                    .get(&serde_json::to_value(&task.status)?.as_str().unwrap_or("todo").to_string())
                    .and_then(|v| v.as_i64())
                    .unwrap_or(0);
                serde_json::Value::Number((n + 1).into())
            };

            *by_priority
                .entry(priority_str)
                .or_insert_with(|| serde_json::Value::Number(0.into())) = {
                let n = by_priority
                    .get(&serde_json::to_value(&task.priority)?.as_str().unwrap_or("medium").to_string())
                    .and_then(|v| v.as_i64())
                    .unwrap_or(0);
                serde_json::Value::Number((n + 1).into())
            };

            if let Some(due) = task.due_date {
                if task.status != TaskStatus::Done {
                    if due < now {
                        overdue += 1;
                    }
                    if due.date_naive() == now.date_naive() {
                        due_today += 1;
                    }
                }
            }

            if !task.depends_on.is_empty() && task.status != TaskStatus::Done {
                blocked += 1;
            }

            if task.status == TaskStatus::Done && task.modified_at > week_ago {
                completed_this_week += 1;
            }
        }

        Ok(serde_json::json!({
            "total": all_tasks.len(),
            "by_status": by_status,
            "by_priority": by_priority,
            "overdue": overdue,
            "due_today": due_today,
            "blocked": blocked,
            "completed_this_week": completed_this_week,
        }))
    }

    // ── Counts (for health endpoint) ──

    pub fn task_count(&self) -> Result<i64> {
        Ok(self.conn.query_row("SELECT COUNT(*) FROM tasks", [], |row| row.get(0))?)
    }

    pub fn project_count(&self) -> Result<i64> {
        Ok(self.conn.query_row("SELECT COUNT(*) FROM projects", [], |row| row.get(0))?)
    }

    pub fn ritual_count(&self) -> Result<i64> {
        Ok(self.conn.query_row("SELECT COUNT(*) FROM rituals", [], |row| row.get(0))?)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn create_in_memory() {
        let store = Store::new_in_memory().unwrap();
        let tasks = store.list_tasks(&TaskFilter::default()).unwrap();
        assert!(tasks.is_empty());
    }

    #[test]
    fn add_and_get_task() {
        let store = Store::new_in_memory().unwrap();
        let task = Task::new("Test".to_string());
        store.add_task(&task).unwrap();
        let found = store.get_task(&task.id).unwrap().unwrap();
        assert_eq!(found.title, "Test");
    }

    #[test]
    fn list_tasks_with_filter() {
        let store = Store::new_in_memory().unwrap();
        let mut t1 = Task::new("High".to_string());
        t1.priority = TaskPriority::High;
        let mut t2 = Task::new("Low".to_string());
        t2.priority = TaskPriority::Low;
        store.add_task(&t1).unwrap();
        store.add_task(&t2).unwrap();

        let filter = TaskFilter {
            priority: Some(TaskPriority::High),
            ..Default::default()
        };
        let tasks = store.list_tasks(&filter).unwrap();
        assert_eq!(tasks.len(), 1);
        assert_eq!(tasks[0].title, "High");
    }

    #[test]
    fn update_task() {
        let store = Store::new_in_memory().unwrap();
        let mut task = Task::new("Original".to_string());
        store.add_task(&task).unwrap();
        task.title = "Updated".to_string();
        store.update_task(&task).unwrap();
        let found = store.get_task(&task.id).unwrap().unwrap();
        assert_eq!(found.title, "Updated");
    }

    #[test]
    fn delete_task() {
        let store = Store::new_in_memory().unwrap();
        let task = Task::new("Delete Me".to_string());
        store.add_task(&task).unwrap();
        assert!(store.delete_task(&task.id).unwrap());
        assert!(store.get_task(&task.id).unwrap().is_none());
    }

    #[test]
    fn add_and_list_projects() {
        let store = Store::new_in_memory().unwrap();
        let p = Project::new("Test".to_string(), "TST".to_string());
        store.add_project(&p).unwrap();
        let projects = store.list_projects(false).unwrap();
        assert_eq!(projects.len(), 1);
        assert_eq!(projects[0].name, "Test");
    }

    #[test]
    fn archived_projects_filtered() {
        let store = Store::new_in_memory().unwrap();
        let p = Project::new("Active".to_string(), "ACT".to_string());
        store.add_project(&p).unwrap();
        let mut archived = Project::new("Old".to_string(), "OLD".to_string());
        archived.is_archived = true;
        store.add_project(&archived).unwrap();

        assert_eq!(store.list_projects(false).unwrap().len(), 1);
        assert_eq!(store.list_projects(true).unwrap().len(), 2);
    }

    #[test]
    fn delete_project_cascades() {
        let store = Store::new_in_memory().unwrap();
        let p = Project::new("P".to_string(), "PP".to_string());
        let mut t = Task::new("Task in project".to_string());
        t.project_id = Some(p.id.clone());
        store.add_project(&p).unwrap();
        store.add_task(&t).unwrap();

        store.delete_project(&p.id).unwrap();
        assert!(store.get_task(&t.id).unwrap().is_none());
    }

    #[test]
    fn add_and_list_rituals() {
        let store = Store::new_in_memory().unwrap();
        let r = Ritual::new("Meditate".to_string());
        store.add_ritual(&r).unwrap();
        let rituals = store.list_rituals(None).unwrap();
        assert_eq!(rituals.len(), 1);
        assert_eq!(rituals[0].title, "Meditate");
    }

    #[test]
    fn delete_ritual() {
        let store = Store::new_in_memory().unwrap();
        let r = Ritual::new("Delete me".to_string());
        store.add_ritual(&r).unwrap();
        assert!(store.delete_ritual(&r.id).unwrap());
        assert!(store.get_ritual(&r.id).unwrap().is_none());
    }

    #[test]
    fn task_analytics_empty() {
        let store = Store::new_in_memory().unwrap();
        let analytics = store.task_analytics().unwrap();
        assert_eq!(analytics["total"], 0);
    }

    #[test]
    fn task_analytics_counts() {
        let store = Store::new_in_memory().unwrap();
        let t1 = Task::new("A".to_string());
        let mut t2 = Task::new("B".to_string());
        t2.status = TaskStatus::Done;
        store.add_task(&t1).unwrap();
        store.add_task(&t2).unwrap();
        let analytics = store.task_analytics().unwrap();
        assert_eq!(analytics["total"], 2);
    }

    #[test]
    fn counts() {
        let store = Store::new_in_memory().unwrap();
        assert_eq!(store.task_count().unwrap(), 0);
        assert_eq!(store.project_count().unwrap(), 0);
        assert_eq!(store.ritual_count().unwrap(), 0);
    }
}
