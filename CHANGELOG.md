# Changelog

All notable changes to Photis Nadi will be documented in this file.

## [2026.3.9]

### Added
- REST API server (Dart Shelf):
  - Standalone HTTP server at `bin/server.dart` with native AOT compilation
  - 8 REST endpoints: tasks CRUD, projects list, rituals list, analytics, health check
  - API key authentication via `Authorization: Bearer <key>` header (health endpoint exempt)
  - JSON serializers (`lib/server/serializers.dart`) decoupled from Flutter
  - Auth middleware (`lib/server/auth.dart`) with 401/403 responses
  - Hive data access in separate process from Flutter web client
  - Dockerfile updated: compiles server to native binary, exposes port 8081
  - Docker Compose: `PHOTISNADI_API_KEY` env var, port 8081 mapping, named data volume
  - Entrypoint supports `web` (API + Caddy), `api` (API only), and `linux` modes
- MCP server switched from Supabase to REST API:
  - Primary backend: Photisnadi REST API (`PHOTISNADI_API_URL` + `PHOTISNADI_API_KEY`)
  - Supabase fallback: auto-retries via Supabase if REST API is unreachable (optional)
  - `@supabase/supabase-js` moved to optional dependency
  - Server version bumped to 2.0.0
- Performance profiling:
  - `PerformanceMonitor` singleton utility with `measure`/`measureAsync` helpers
  - Auto-reports on init, slow-operation detection (>50ms threshold)
  - Instrumented repositories and service hot paths
- Multiple boards per project:
  - Board CRUD with `addBoard`, `updateBoard`, `deleteBoard`, `selectBoard`
  - 3 board templates: Default, Bug Tracking, Sprint
  - Board selector UI (chip row in project header)
  - Backwards-compatible migration from single-board model
- Export/Import:
  - JSON export (full or per-project), CSV task export
  - JSON import with summary dialog
  - File picker integration, export/import button in project header
- Docker container:
  - Multi-stage Dockerfile on `ghcr.io/maccracken/agnosticos:latest`
  - Flutter web served via Caddy with SPA fallback
  - Docker Compose setup with health checks
  - GHCR push on tagged releases
- CI/CD multi-platform builds:
  - Windows (windows-latest) and macOS (macos-latest) build jobs
  - Web build artifact
  - Docker build-only validation with GHA cache
- 16 new tests (154 total: 138 unit, 16 widget)

### Changed
- TaskService (1131 lines) decomposed into 6 focused mixins:
  - `ProjectMixin` — project CRUD, selection, sharing
  - `TaskCrudMixin` — task CRUD, dependencies, subtasks, time tracking
  - `FilterSortMixin` — filter/sort state and logic
  - `ColumnMixin` — column management (board-aware)
  - `RitualMixin` — ritual CRUD and resets
  - `TagMixin` — tag CRUD with cross-mixin filter cleanup
- Board model: relaxed ID validation, added `columns` field (HiveField 6)
- Project model: added `boards` (HiveField 13) and `activeBoardId` (HiveField 14)
- All `project.columns` references updated to `project.activeColumns`
- Boolean service methods converted to named parameters (`setEnabled({required bool enabled})`)
- 19 flutter analyze info-level issues resolved (tearoffs, named constructors, Size.zero, etc.)
- Release workflow: accepts both `v`-prefixed and plain version tags, YYYYMMDD filename format

### New Files
- `bin/server.dart` — REST API server entry point
- `lib/server/api.dart` — REST API router and endpoint handlers
- `lib/server/auth.dart` — API key authentication middleware
- `lib/server/serializers.dart` — JSON serialization helpers
- `lib/common/validators.dart` — Model validation utilities (hex colors, UUIDs, project keys)
- `lib/common/performance_monitor.dart` — Performance profiling utility
- `lib/services/mixins/project_mixin.dart` — Project management mixin
- `lib/services/mixins/task_crud_mixin.dart` — Task CRUD mixin
- `lib/services/mixins/filter_sort_mixin.dart` — Filter/sort mixin
- `lib/services/mixins/column_mixin.dart` — Column management mixin
- `lib/services/mixins/ritual_mixin.dart` — Ritual management mixin
- `lib/services/mixins/tag_mixin.dart` — Tag management mixin
- `lib/services/export_import_service.dart` — Export/import utility
- `lib/widgets/dialogs/board_dialogs.dart` — Board management dialogs
- `Dockerfile` — Multi-stage Flutter web + Caddy container
- `docker-compose.yml` — Container orchestration
- `docker/Caddyfile` — Caddy static file server config
- `docker/entrypoint.sh` — Container entrypoint (web/linux modes)
- `.dockerignore` — Docker build exclusions

---

## [2026.3.5]

### Added
- SecureYeoman integration:
  - `YeomanService` — connects to SecureYeoman REST API, syncs task/ritual data to brain/knowledge
  - API key generation for MCP server authentication
  - MCP tool registration from Flutter app
  - Periodic sync (every 10 minutes) with manual trigger
  - Connection testing and credential management
  - MCP stdio server (`tools/mcp-server/`) with 6 tools:
    - `photis_list_tasks` — query tasks with status/priority/project filters
    - `photis_create_task` — create tasks via Supabase
    - `photis_update_task` — update task fields
    - `photis_list_projects` — list active/archived projects
    - `photis_list_rituals` — list rituals with streak data
    - `photis_task_analytics` — productivity insights and status breakdowns
  - Ritual analytics: completion rates, streak tracking, frequency breakdowns
- New dependency: `http` ^1.2.0
- Theme Customization:
  - 8 accent color presets: Indigo, Teal, Rose, Amber, Emerald, Violet, Sky, Orange
  - Color picker dialog with visual selection
  - Compact/comfortable layout density toggle
  - Compact mode: smaller cards, tighter spacing, reduced text lines, hidden tags
  - Theme builder refactored to accept dynamic primary color
- Keyboard Navigation:
  - Vim-style task navigation: J (next task), K (prev task), H (prev column), L (next column)
  - Enter/Space to open focused task details
  - Focus indicators on task cards (primary color border)
  - Focus nodes managed per-task for efficient keyboard traversal
- Repository pattern for data access:
  - `HiveRepository<T>` generic base with Map-based index for O(1) lookups
  - `TaskRepository` with secondary project index for efficient project-scoped queries
  - `ProjectRepository`, `RitualRepository`, `TagRepository` specialized repositories
  - Constructor injection for dependency injection and testability
- Markdown support in task descriptions:
  - `flutter_markdown` rendering in task detail dialog
  - Description fields hint at markdown support, expanded to 5 lines
- Subtasks/checklists:
  - Add, toggle, remove subtasks on any task
  - Progress bar indicator on task cards (done/total)
  - Interactive checklist in task detail dialog with strikethrough
  - Encoded storage (`0:title` / `1:title`) for Hive compatibility
- Time tracking:
  - Estimate (minutes) and logged time per task
  - Time indicator on task cards with formatted display (e.g., "1h 30m / 2h")
  - Log time and set estimate in edit dialog
- Recurring tasks:
  - Daily, weekly, monthly recurrence options
  - Auto-creation of next occurrence when recurring task is completed
  - Subtasks reset to incomplete in new occurrence
  - Recurrence indicator on task cards
  - Processed on app init
- File attachments:
  - `file_picker` integration for adding files to tasks
  - Attachment list in edit and detail dialogs
  - System-default file opening (cross-platform)
  - Attachment count indicator on task cards
- Team sharing (multi-user):
  - `sharedWith` and `ownerId` fields on Project model
  - Share/unshare project methods in TaskService
  - Sync-ready: shared_with and owner_id in sync serialization
- Web platform support:
  - Flutter web target added (`web/` directory)
  - Platform guards for desktop-only features (window manager, system tray, notifications)
  - `platform_utils.dart` for cross-platform file opening
- New dependencies: `flutter_markdown`, `file_picker`
- 20 new unit tests (138 total)
- Tags system:
  - Tag model with color support
  - Create/edit/delete tags with tag management UI (`lib/widgets/dialogs/tag_dialogs.dart`)
  - Multi-tag filtering in search bar
  - Tag display on task cards
- Supabase Sync:
  - Full sync service with cloud backup & restore (`lib/services/sync_service.dart`)
  - Auth flow and cross-device sync
  - Conflict resolution UI (`lib/widgets/dialogs/sync_dialogs.dart`)
  - Supabase schema (`docs/supabase_schema.sql`)
- Due Date Notifications:
  - Date picker in add/edit task dialogs
  - Desktop notification service (`lib/services/notification_service.dart`)
  - Overdue, due today, and due tomorrow visual indicators on task cards
  - Periodic due date checking (every 15 minutes)
  - Scheduled task reminders
- New dependencies: `flutter_local_notifications`, `timezone`
- 46 new unit tests (97 total), 16 widget tests (113 total)

### Changed
- Task model now supports `dueDate` field and `tags` list
- Task creation accepts `dueDate` parameter
- Search/filter bar supports tag-based filtering
- SecureYeoman integration paths documented in roadmap
- TaskService refactored from direct Hive box access to repository pattern
- All O(n) list scans replaced with O(1) indexed lookups
- Task model extended with subtasks, estimatedMinutes, trackedMinutes, recurrence, attachments fields
- Project model extended with sharedWith and ownerId fields
- Task Hive adapter updated (fields 12-16), Project adapter updated (fields 11-12)
- Sync serialization updated for all new task and project fields
- `main.dart` refactored with `kIsWeb` guards for web compatibility
- Description fields expanded to 5 lines with markdown hint
- Project-scoped queries use secondary index instead of filtering all tasks

### New Files
- `lib/repositories/hive_repository.dart` — Generic base repository with indexed lookups
- `lib/repositories/task_repository.dart` — Task repository with project secondary index
- `lib/repositories/project_repository.dart` — Project repository
- `lib/repositories/ritual_repository.dart` — Ritual repository
- `lib/repositories/tag_repository.dart` — Tag repository with project index and name lookup
- `lib/services/yeoman_service.dart` — SecureYeoman integration service
- `tools/mcp-server/index.js` — MCP stdio server for task CRUD via Supabase
- `tools/mcp-server/package.json` — MCP server dependencies
- `lib/common/platform_utils.dart` — Cross-platform helpers (desktop detection, file open)
- `lib/models/tag.dart` / `tag.g.dart` — Tag model
- `lib/services/notification_service.dart` — Desktop notification service
- `lib/widgets/dialogs/tag_dialogs.dart` — Tag management dialogs
- `lib/widgets/dialogs/sync_dialogs.dart` — Sync/conflict resolution dialogs
- `docs/supabase_schema.sql` — Database schema for sync

---

## [2026.2.28]

### Added
- Task dependencies:
  - Blocked-by relationships between tasks
  - Visual dependency indicators on task cards
  - Dependency warnings on drag operations
- Keyboard shortcuts service (`lib/services/keyboard_shortcuts.dart`):
  - `Ctrl+N` for quick task creation
  - `Ctrl+K` for search
  - `Escape` to close dialogs
- Project header component (`lib/widgets/common/project_header.dart`)
- Integration tests for task dependencies
- 12 new unit tests (67 total)

### Changed
- Task model extended with dependency fields
- Refactored KanbanBoard — extracted project header to separate widget
- Home screen restructured for keyboard shortcut support

---

## [2026.2.22]

### Added
- Extracted reusable UI components:
  - `CollapsibleSidebar` - Container wrapper for collapsible sidebars
  - `CollapsedListItem` - Reusable collapsed sidebar item
  - `ActionMenuItem` - Reusable popup menu item
  - `EditDeleteMenu` - Reusable edit/delete popup menu
  - Enhanced `SidebarHeader` with custom leading support
  - `TaskCard` - Reusable task card component
  - `ColumnHeader` - Reusable Kanban column header
- New files:
  - `lib/widgets/common/task_card.dart` - Task card widget
  - `lib/widgets/common/column_widgets.dart` - Column header and dialogs

### Changed
- Improved code organization in `lib/widgets/common/common_widgets.dart`
- Refactored `kanban_board.dart`:
  - Reduced from 678 to 324 lines (52% reduction)
  - Extracted TaskCard to separate file
  - Extracted column dialogs to column_widgets.dart
- Updated `project_sidebar.dart` and `rituals_sidebar.dart` to use CollapsibleSidebar

### Fixed
- Fixed deprecated `value` parameter in DropdownButtonFormField

---

## [2026.2.16]

### Added
- Model validation for hex colors, UUIDs, project keys
- Error handling to TaskService with try-catch and logging
- Retry logic to SyncService with exponential backoff
- Timeout handling for Supabase operations
- Pagination support for Kanban board columns
- Loading indicators for async operations
- Comprehensive test coverage (55 tests)

### Changed
- Split oversized widget files into dialog components
- Added `final` keyword to immutable model fields
- Controller disposal for ScrollController and TextEditingControllers
- Replaced magic numbers with constants in `lib/common/constants.dart`
- UI performance optimized with Selector widgets

### Fixed
- Rituals sidebar completion counter bug
- Model mutability issues

### Removed
- Unused dependencies: riverpod, flutter_staggered_animations, glassmorphism
- Build artifacts from git

### Deprecated
- LuminaFlowApp renamed to PhotisNadiApp
