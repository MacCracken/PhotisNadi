# Photis Nadi Roadmap

## Overview
Cross-platform productivity app combining Kanban-style task management with daily ritual tracking. Built with Flutter.

---

## Completed ✓

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

## In Progress

---

### v2026.3.5
- Tags System: Create/edit/delete tags with colors, multi-tag filtering, tag management UI
- Supabase Sync: Auth flow, cloud backup, cross-device sync, conflict resolution UI, auto-sync

## Planned Features

### High Priority

1. ~~Search & Filter~~
   - ~~Global task search across projects~~
   - ~~Filter by tags, priority, due date~~
   - ~~Sort options (date, priority, alphabetical)~~

2. ~~Task Dependencies~~
   - ~~Blocked-by relationships~~
   - ~~Visual dependency indicators~~
   - ~~Dependency warnings on drag~~

3. ~~Keyboard Shortcuts~~
   - ~~Desktop: vim-like navigation~~
   - ~~Quick task creation (Ctrl+N)~~
   - ~~Quick search (Ctrl+K)~~

### Medium Priority

4. ~~Supabase Sync~~
   - ~~Cloud backup & restore~~
   - ~~Cross-device sync~~
   - ~~Conflict resolution UI~~

5. ~~Tags System~~
   - ~~Create/edit/delete tags~~
   - ~~Tag colors~~
   - ~~Filter by multiple tags~~

6. **Due Date Notifications**
   - Desktop notifications
   - Overdue reminders
   - Due today indicators

7. **Multiple Boards per Project**
   - Board templates
   - Board switching

### Low Priority

8. **Theme Customization**
   - Custom accent colors
   - Compact/comfortable mode

9. **Keyboard Navigation**
   - Tab through tasks
   - Enter to open, Escape to close

10. **Export/Import**
    - JSON export
    - CSV export for tasks

---

## Technical Improvements

### Tech Debt
- [x] Refactor KanbanBoard to use smaller components
- [x] Add integration tests (67 tests total)
- [x] Add widget tests for UI components (17 widget tests)
- [ ] Performance profiling for large datasets

### Architecture
- [ ] Consider BLoC pattern for complex state
- [ ] Repository pattern for data access
- [ ] Dependency injection setup

---

## SecureYeoman Integration

**Priority:** Low — Photis Nadi is a client-only Flutter app with no backend API, limiting integration surface.

### Potential Integration Paths

- [ ] **Task sync via SecureYeoman API** — If Supabase Sync (Medium Priority #4) is implemented, an alternative path is syncing tasks through SecureYeoman's storage layer instead. SecureYeoman personalities could then access task data for AI-powered suggestions (priority recommendations, dependency analysis, ritual scheduling). Requires adding a lightweight REST endpoint or using SecureYeoman's existing brain/memory API to store task state.
- [ ] **AI task assistant via MCP** — Once a backend exists (Supabase or SecureYeoman-backed), expose task CRUD as MCP tools so SecureYeoman personalities can create/update/query tasks conversationally. Not viable until a backend is added.
- [ ] **Ritual analytics** — Feed ritual completion data to SecureYeoman's observability pipeline for trend analysis and pattern recognition across productivity habits.

### Not Applicable

- **AGNOS Docker base** — No Docker component (Flutter client-only). Not a candidate for agnosticos migration.
- **MCP tool registration** — No REST API to proxy. Blocked until a backend is added.

---

## Backlog (Future)

- Markdown support in task descriptions
- File attachments
- Subtasks/checklists
- Time tracking
- Recurring tasks
- Team sharing (multi-user)
- Web platform support
