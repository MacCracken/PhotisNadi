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
- Refactored KanbanBoard to smaller components, integration tests (67), widget tests (16)
- Comprehensive test suite (131 tests: 115 unit, 16 widget)

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

2. **Theme Customization**
   - Custom accent colors
   - Compact/comfortable mode

3. **Keyboard Navigation**
   - Tab through tasks
   - Enter to open, Escape to close

4. **Export/Import**
   - JSON export
   - CSV export for tasks

---

## Technical Improvements

### Tech Debt
- [ ] Performance profiling for large datasets

### Architecture
- [ ] Consider BLoC pattern for complex state
- [ ] Repository pattern for data access
- [ ] Dependency injection setup

---

## SecureYeoman Integration

**Status:** Implemented — YeomanService syncs task/ritual data to SecureYeoman brain, MCP server exposes task CRUD.

### Not Applicable

- **AGNOS Docker base** — No Docker component (Flutter client-only). Not a candidate for agnosticos migration.

---

## Backlog (Future)

- Markdown support in task descriptions
- File attachments
- Subtasks/checklists
- Time tracking
- Recurring tasks
- Team sharing (multi-user)
- Web platform support
