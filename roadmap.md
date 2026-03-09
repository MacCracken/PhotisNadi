# Photis Nadi Roadmap

## Overview
Cross-platform productivity app combining Kanban-style task management with daily ritual tracking. Built with Flutter.

---

## Completed ✓

### v2026.3.5
- Tags System: Create/edit/delete tags with colors, multi-tag filtering, tag management UI
- Supabase Sync: Auth flow, cloud backup, cross-device sync, conflict resolution UI, auto-sync
- Due Date Notifications: Date picker in dialogs, desktop notifications, overdue/due today indicators
- SecureYeoman Integration: Task sync to brain/knowledge, MCP server with 6 tools, ritual analytics, API key generation
- Theme Customization: 8 accent colors (indigo, teal, rose, amber, emerald, violet, sky, orange), compact/comfortable mode
- Keyboard Navigation: Vim-style J/K/H/L task navigation, Enter to open task, focus indicators
- Repository Pattern: HiveRepository base with Map-based O(1) lookups, secondary project indexes, constructor DI
- Markdown Support: flutter_markdown rendering in task detail dialog, markdown-aware description fields
- Subtasks/Checklists: Add/toggle/remove subtasks, progress bar on task cards, checklist in detail dialog
- Time Tracking: Estimate and log time per task, time indicators on cards, formatted display (h/m)
- Recurring Tasks: Daily/weekly/monthly recurrence, auto-creation of next occurrence on completion
- File Attachments: file_picker integration, attachment list in edit/detail dialogs, system open
- Team Sharing: Project-level sharing with user IDs, share/unshare methods, sync-ready
- Web Platform Support: Flutter web target added, platform guards for desktop-only features
- Comprehensive test suite (138 tests: 138 unit, 16 widget)

### v2026.2.28
- Task Dependencies: Blocked-by relationships, visual indicators, drag warnings
- Keyboard Shortcuts: Ctrl+N (quick add), Ctrl+K (search), Escape
- Integration tests for task dependencies (67 tests total)

### v2026.2.22
- Extracted reusable UI components

### v2026.2.16
- Model validation & error handling
- Pagination for Kanban columns
- Comprehensive test suite (55 tests)
- Code organization & cleanup

---

## Planned Features

### Medium Priority

1. **Multiple Boards per Project**
   - Board templates
   - Board switching

### Low Priority

2. **Export/Import**
   - JSON export
   - CSV export for tasks

---

## Technical Improvements

### Tech Debt
- [ ] Performance profiling for large datasets

### Architecture
- [ ] Consider BLoC pattern for complex state
- [x] Repository pattern for data access (HiveRepository base, TaskRepository with secondary indexes)
- [x] Dependency injection setup (constructor injection for repositories)

---

## SecureYeoman Integration

**Status:** Photisnadi side complete — YeomanService syncs task/ritual data to SecureYeoman brain, MCP server exposes 6 tools (list_tasks, create_task, update_task, get_rituals, analytics, sync).

### Pending (SecureYeoman side — tracked in SY roadmap Phase 145)

- [ ] **MCP tool registration in SecureYeoman** — Photisnadi's 6 MCP tools need to be registered in SecureYeoman's `packages/mcp/src/tools/manifest.ts` via `registerApiProxyTool()`. Feature-gated via `exposePhotisnadiTools`.
- [ ] **Dashboard widget** — `PhotosnadiWidget.tsx` showing task counts and ritual streaks in SecureYeoman dashboard.

### Not Applicable

- **AGNOS Docker base** — No Docker component (Flutter client-only). Not a candidate for agnosticos migration.
