# Photis Nadi Roadmap

> **NOTE: ONLY OPEN ITEMS** — See CHANGELOG.md for completed work.

## Overview
Cross-platform productivity app combining Kanban-style task management with daily ritual tracking. Built with Flutter.

---

## Planned Features

### Supabase Runtime Configuration
- [x] **Settings UI for Supabase credentials** — Configuration form in sync dialog; URL + anon key fields with connect button
- [x] **Runtime credential loading** — `SupabaseConfigService` loads from `flutter_secure_storage`, falls back to compile-time env vars
- [x] **Connection test** — Validates URL format and Supabase initialization before saving
- [x] **Disconnect option** — Clears credentials from secure storage, signs out, reverts to offline-only

---

