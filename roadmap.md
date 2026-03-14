# Photis Nadi Roadmap

> **NOTE: ONLY OPEN ITEMS** — See CHANGELOG.md for completed work.

## Overview
Cross-platform productivity app combining Kanban-style task management with daily ritual tracking. Built with Flutter.

---

## Engineering Backlog

### AGNOS Marketplace Onboarding

| Item | Effort | Status | Description |
|------|--------|--------|-------------|
| Verify sandbox in AGNOS (qemu/baremetal) | 1 hour | Not started | Retest on qemu and baremetal with Landlock/seccomp sandbox active. Verify Supabase sync works through `*.supabase.co` allowed hosts. Docker cannot exercise Landlock/seccomp — needs real AGNOS environment. |

### Test Coverage
- **Current**: 59.5% (2444/4107 lines, 550+ tests across 9 files)
- **Target**: 60%
- **Well-covered**: Models, validators, serializers, auth middleware, export/import, filter/sort, theme service, board/column management, task CRUD, rituals, tags, sync parsing, performance monitor, Hive persistence round-trips, API endpoints (tasks/projects/rituals CRUD + analytics), board sync, undo/restore
- **Gaps**: Widget tests, sync service integration (423 lines), dialog flows, desktop integration
- **Known issue**: `widget_test.dart` has ritual dialog tests (`Ritual Dialog Widget Tests` group) that hang due to Hive initialization conflicts in the widget test environment. Fix by either removing those tests or moving them to `ritual_test.dart` with proper Hive setup/teardown isolation. The non-Hive widget tests (EmptyState, ColorPicker, SidebarHeader, CollapsibleSidebar, CollapsedListItem, ActionMenuItem, ProjectHeader) all pass.

### Test File Organization
Tests were split from a single 8000+ line file into feature-focused files:
- `task_service_test.dart` — TaskService CRUD, dependencies, subtasks, time tracking, due dates, filters, recurring tasks
- `project_test.dart` — Projects, sharing, columns, boards
- `ritual_test.dart` — Ritual reset, model, undo/restore
- `model_test.dart` — Task/Project/Board/Tag models, validation, utils
- `api_test.dart` — API router integration, auth middleware
- `sync_test.dart` — Sync serialization, board sync, sync config
- `service_test.dart` — YeomanService, export/import, ThemeService, AGNOS
- `hive_test.dart` — Hive round-trips, adapters, pagination, tag service
- `widget_test.dart` — Widget tests (see known issue above)

---
