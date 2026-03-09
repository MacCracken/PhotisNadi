# Photis Nadi Roadmap

> **NOTE: ONLY OPEN ITEMS** — See CHANGELOG.md for completed work.

## Overview
Cross-platform productivity app combining Kanban-style task management with daily ritual tracking. Built with Flutter.

---

## Planned Features

### Supabase Runtime Configuration
- [ ] **Settings UI for Supabase credentials** — Add a settings screen where users can enter their Supabase URL and anon key at runtime, stored securely via `flutter_secure_storage` (or Hive encrypted box)
- [ ] **Remove compile-time env vars** — Remove `String.fromEnvironment('SUPABASE_URL')` / `SUPABASE_ANON_KEY` from `main.dart`; load credentials from secure storage instead
- [ ] **Connection test** — Validate credentials with a test request before saving, show success/error feedback
- [ ] **Disconnect option** — Allow users to clear credentials and revert to offline-only mode

---

## SecureYeoman Integration

**Status:** Photisnadi side complete — YeomanService syncs task/ritual data to SecureYeoman brain, MCP server exposes 6 tools (list_tasks, create_task, update_task, get_rituals, analytics, sync).

### Pending (SecureYeoman side — tracked in SY roadmap Phase 145)

- [ ] **MCP tool registration in SecureYeoman** — Photisnadi's 6 MCP tools need to be registered in SecureYeoman's `packages/mcp/src/tools/manifest.ts` via `registerApiProxyTool()`. Feature-gated via `exposePhotisnadiTools`.
- [ ] **Dashboard widget** — `PhotosnadiWidget.tsx` showing task counts and ritual streaks in SecureYeoman dashboard.
