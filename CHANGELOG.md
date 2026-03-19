# Changelog

All notable changes to Photis Nadi will be documented in this file.

## [2026.3.18-1]

### Added
- **Rust native backend** (`v2/`): Full port of the Dart server to a native Rust binary
  - `photisnadi-core` — models, enums, validators (Task, Project, Ritual, Board, Tag)
  - `photisnadi-store` — SQLite CRUD with JSON blob pattern (rusqlite)
  - `photisnadi-mcp` — 6 MCP tools + JSON-RPC 2.0 stdio transport
  - `photisnadi-agnos` — agent registration, heartbeats, audit forwarding (reqwest)
  - `photisnadi-server` — axum REST API matching v1 Dart contract exactly
  - CLI binary with `--db`, `--headless`, `--mcp`, `--bind`, `--port`, `--api-key` flags
  - 56 Rust tests across all crates
- CI: `rust-test` job (build + test v2 workspace), `build-rust-server` artifact
- Release: `photisnadi-server-{version}-linux-x64.tar.gz` published to GitHub releases
- Roadmap: v3 egui native UI migration plan

### Removed
- Old Dart backend: `bin/server.dart`, `lib/server/` (api, auth, serializers, agnos)
- `shelf` and `shelf_router` dependencies from pubspec.yaml
- `test/api_test.dart` (replaced by v2 Rust server tests)
- AGNOS integration tests from `test/service_test.dart` (replaced by v2 Rust tests)

### Changed
- Serializers moved from `lib/server/serializers.dart` to `lib/common/serializers.dart`
- Dockerfile: two-stage build (Rust builder + Flutter builder), ships native binary
- Docker entrypoint: runs Rust binary instead of Dart server bundle
- Caddy proxy: API port 8081 → 8094
- Docker Compose: ports updated to 8094
- `tools/bump-version.sh`: updated for v2 Cargo workspace (replaces `lib/server/agnos.dart`)
- CI workflows: all platform builds gated on `rust-test`, security scans include `.rs` files

---

## [2026.3.18]

### Added
- `lib/server/serializers.dart` — JSON serializers extracted as standalone functions
- `tools/bump-version.sh` — version bump script for all version-bearing files
- Test suite expansion (575+ tests split into 9 focused files):
  - `test/api_test.dart` — API router integration, auth middleware (1139 lines)
  - `test/hive_test.dart` — Hive round-trips, adapters, pagination, tag service
  - `test/model_test.dart` — Task/Project/Board/Tag models, validation, utils
  - `test/project_test.dart` — Projects, sharing, columns, boards
  - `test/ritual_test.dart` — Ritual reset, model, undo/restore
  - `test/service_test.dart` — YeomanService, export/import, ThemeService, AGNOS
  - `test/sync_test.dart` — Sync serialization, board sync, config, merge, conflicts
  - `test/task_service_test.dart` — TaskService CRUD, dependencies, subtasks, time tracking
  - `test/widget_dialog_test.dart` — Dialog widget tests
  - `test/widget_test.dart` — Common widget tests

### Changed
- Widget refactoring: task dialogs, sync dialogs, and kanban board split into smaller modules
- Ritual model: improved reset logic
- Task CRUD: repository and service layer cleanup
- Search/filter bar and task card UI improvements
- Project sidebar and rituals sidebar refinements
- CI/release workflow fixes

### Fixed
- Auth middleware edge cases
- API endpoint validation and error handling improvements
- Ritual reset timing and streak tracking
- Code formatting and lint compliance

---

## [2026.3.10-1]

### Fixed
- API handshake authentication flow (`/api/v1/handshake` endpoint)
- Server auto-generates API key when `PHOTISNADI_API_KEY` not set, claimable via handshake
- Auth middleware allows unauthenticated access to handshake endpoint
- Caddy reverse proxy: `/api/*` requests now proxied to Dart API server on port 8081
- Docker entrypoint always starts API server (no longer gated on `PHOTISNADI_API_KEY`)

---

## [2026.3.10]

### Added
- AGNOS daimon integration (`lib/server/agnos.dart`):
  - Agent registration and heartbeats with daimon agent runtime
  - MCP tool registration (6 tools) with daimon's MCP server
  - Audit event forwarding for task CRUD operations
  - Graceful shutdown with agent deregistration
  - Configured via `AGNOS_AGENT_REGISTRY_URL` and `AGNOS_AUDIT_URL` env vars
- Application icon assets (`photisnadi.png`, `photisnadi.svg`)

### Fixed
- Application icon rendering
- Lint and format compliance repairs

---

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
- Supabase runtime configuration:
  - `SupabaseConfigService` — manages Supabase credentials via `flutter_secure_storage`
  - Configuration form in sync dialog (URL + anon key with connection test)
  - Runtime credentials take priority, compile-time env vars as fallback
  - Disconnect option clears credentials and reverts to offline-only mode
  - New dependency: `flutter_secure_storage` ^9.2.4
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
- Code audit: 56 new tests (210 total), coverage 37.3% → 43.4%
  - Validator tests (hex color, UUID, project key validation)
  - Ritual model tests (markCompleted, resetIfNeeded lifecycle)
  - Board model tests (constructors, templates, column management)
  - Filter/sort tests (search, status/priority filters, sort modes)
  - Export/import tests (JSON round-trip, CSV export, escaping)
  - ThemeService tests (defaults, accent color enum)
  - SyncService model tests (SyncConflict, SyncException, configs)
- Code audit round 2: 179 new tests (389 total), coverage 43.4% → 52.1%
  - REST API serializer tests (taskToJson, projectToJson, ritualToJson round-trips)
  - Auth middleware tests (health bypass, 401/403, valid bearer token)
  - PerformanceMonitor tests (measure, measureAsync, reset)
  - Task model extended tests (formattedTrackedTime, subtask helpers, copyWith, validation)
  - Project model extended tests (generateNextTaskKey, migration, color normalization)
  - Column mixin tests (add, update, delete, reorder, getColumnStatus)
  - Filter/sort extended tests (setters, hasActiveFilters, date range, priority sort)
  - Project sharing tests (share, unshare, idempotent)
  - TaskCrud extended tests (subtasks, time tracking, attachments, recurrence, moveTaskToProject)
  - Board management tests (addBoard, updateBoard, deleteBoard, selectBoard)
  - Task service query tests (pagination, filtered columns, column counts)
  - Recurring tasks tests (daily/weekly/monthly recurrence processing)
  - Tag mixin CRUD tests (add, delete, update, getByProject, getByName)
  - ThemeService persistence tests (SharedPreferences mock, load/save all prefs)
  - Sync parsing tests (fromMap/toSyncMap round-trips for all model types)
  - Hive disk persistence tests (close/reopen boxes for .g.dart binary read coverage)
  - Repository tests (where, firstWhere, count, index unmodifiable)

### Fixed
- `Ritual.markCompleted()` and `resetIfNeeded()` now async with `await save()` (data was not persisting)
- `TaskCrudMixin.addTaskDependency/removeTaskDependency` now async with `await task.save()`
- `SyncService` auth state subscription stored and cancelled in `dispose()` (memory leak)
- `SyncService._mergeRituals()` conflict detection using `lastCompleted`/`createdAt` timestamps
- Task dialog callbacks use `context.mounted` guard after async operations
- API rituals endpoint properly awaits `resetIfNeeded()`
- Docker build: switched from `dart compile exe` to `dart build cli` (build hooks support)
- Linux CI: added `libsecret-1-dev` dependency for `flutter_secure_storage`
- `TaskRepository.removeDependencyReferences()` now async with `await put()` (dependency cleanup was not persisting)
- API tags validation: `whereType<String>()` instead of unsafe `cast<String>()` to prevent type errors
- CI/CD security hardening:
  - `actions/checkout@v6` → `actions/checkout@v4` (v6 doesn't exist, corrected to latest stable)
  - Added explicit `permissions:` blocks with minimum required scopes
  - Command injection fix: version input now validated and passed via env vars, not direct interpolation
  - Added `timeout-minutes:` to all jobs to prevent runaway builds
  - Added `retention-days: 30` to artifact uploads
  - Job-level permissions for container build (scoped `packages: write`)
  - Removed unnecessary `id-token: write` and `attestations: write` permissions
  - Added `libsecret-1-dev` to release Linux build dependencies (was missing)

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
- `lib/services/supabase_config_service.dart` — Runtime Supabase credential management
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
