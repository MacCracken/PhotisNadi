# Changelog

All notable changes to Photis Nadi will be documented in this file.

## [2026.3.5] - 2026-03-05

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
- 18 new YeomanService unit tests (115 total)
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

### New Files
- `lib/services/yeoman_service.dart` — SecureYeoman integration service
- `tools/mcp-server/index.js` — MCP stdio server for task CRUD via Supabase
- `tools/mcp-server/package.json` — MCP server dependencies
- `lib/models/tag.dart` / `tag.g.dart` — Tag model
- `lib/services/notification_service.dart` — Desktop notification service
- `lib/widgets/dialogs/tag_dialogs.dart` — Tag management dialogs
- `lib/widgets/dialogs/sync_dialogs.dart` — Sync/conflict resolution dialogs
- `docs/supabase_schema.sql` — Database schema for sync

---

## [2026.2.28] - 2026-02-28

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

## [2026.2.22] - 2026-02-22

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

## [2026.2.16] - 2026-02-16

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
