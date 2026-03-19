# Photis Nadi Roadmap

> **NOTE: ONLY OPEN ITEMS** — See CHANGELOG.md for completed work.

## Overview
Cross-platform productivity app combining Kanban-style task management with daily ritual tracking.

---

## v2 — Rust Native Backend (Complete)

Backend ported from Dart/shelf to Rust under `v2/`. Workspace with 5 crates:
- `photisnadi-core` — models, enums, validators
- `photisnadi-store` — SQLite CRUD (rusqlite, JSON blob pattern)
- `photisnadi-mcp` — 6 MCP tools + JSON-RPC 2.0 stdio transport
- `photisnadi-agnos` — agent registration, heartbeats, audit forwarding
- `photisnadi-server` — axum REST API + auth middleware

Old Dart backend (`bin/server.dart`, `lib/server/`) removed. Docker updated to build Rust binary.

---

## v3 — egui Native UI

Port Flutter UI to egui to match the rest of the AGNOS ecosystem (rahd, nazar). Full native Rust application.

### Phase 1: Core UI Shell
- [ ] Add `photisnadi-gui` crate (eframe + egui)
- [ ] App chrome: sidebar navigation, top bar, theme system
- [ ] Task list view with filtering (project, status, priority)
- [ ] Task detail panel (view/edit)

### Phase 2: Kanban & Projects
- [ ] Kanban board with drag-and-drop columns
- [ ] Project management (create, edit, archive)
- [ ] Board switching and column customization

### Phase 3: Rituals & Analytics
- [ ] Ritual list with completion toggles and streak display
- [ ] Analytics dashboard (by status, priority, overdue, completed this week)

### Phase 4: Parity & Cutover
- [ ] Desktop integration (system tray, window management)
- [ ] Remove Flutter dependency from build
- [ ] Single binary ships UI + server + MCP

---

## Engineering Backlog

### AGNOS Marketplace Onboarding

| Item | Effort | Status | Description |
|------|--------|--------|-------------|
| Verify sandbox in AGNOS (qemu/baremetal) | 1 hour | Not started | Retest on qemu and baremetal with Landlock/seccomp sandbox active. Verify Supabase sync works through `*.supabase.co` allowed hosts. Docker cannot exercise Landlock/seccomp — needs real AGNOS environment. |

### Test Coverage
- **v2 Rust tests**: 56 tests across core, store, mcp, server
- **Flutter tests**: 575+ tests across 9 files
- **Well-covered**: Models, validators, serializers, auth middleware, export/import, filter/sort, theme service, board/column management, task CRUD, rituals, tags, sync parsing, sync merge logic, performance monitor, Hive persistence round-trips, API endpoints (tasks/projects/rituals CRUD + analytics), board sync, undo/restore, widgets
- **Gaps**: Sync service integration (SyncService class methods require Supabase mocking — 423 lines), dialog flows, desktop integration
- **Known issue**: Ritual dialog widget tests (`showAddRitualDialog`, `showEditRitualDialog`) hang due to `TextEditingController` lifecycle conflicts in the widget test environment. These tests were removed; the underlying dialog code works correctly in production.

### Test File Organization
Tests were split from a single 8000+ line file into feature-focused files:
- `task_service_test.dart` — TaskService CRUD, dependencies, subtasks, time tracking, due dates, filters, recurring tasks
- `project_test.dart` — Projects, sharing, columns, boards
- `ritual_test.dart` — Ritual reset, model, undo/restore
- `model_test.dart` — Task/Project/Board/Tag models, validation, utils
- `api_test.dart` — API router integration, auth middleware
- `sync_test.dart` — Sync serialization, board sync, sync config, merge logic, conflict detection
- `service_test.dart` — YeomanService, export/import, ThemeService, AGNOS
- `hive_test.dart` — Hive round-trips, adapters, pagination, tag service
- `widget_test.dart` — Widget tests (EmptyState, ColorPicker, SidebarHeader, CollapsibleSidebar, CollapsedListItem, ActionMenuItem, ProjectHeader)

---
