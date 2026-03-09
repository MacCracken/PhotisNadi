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

**Status:** REST API + MCP tools complete. MCP server uses REST API as primary backend with Supabase fallback.

### Pending (SecureYeoman side)

- [ ] **Dashboard widget** — `PhotosnadiWidget.tsx` showing task counts and ritual streaks in SecureYeoman dashboard.
