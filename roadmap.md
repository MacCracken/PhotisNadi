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

## REST API Server

**Status:** Implemented

Lightweight REST API embedded in the Docker container, letting SecureYeoman (and other integrations) query Photisnadi directly without Supabase credentials.

### Implementation Plan

- [x] **Add Dart Shelf HTTP server** — `shelf` + `shelf_router` packages. `lib/server/` directory with standalone Dart entry point (`bin/server.dart`). Models decoupled from Flutter via `lib/common/validators.dart` extraction.
- [x] **Data access layer** — Server uses Hive directly in its own process (separate from Flutter web client's browser-side Hive). Data stored at `PHOTISNADI_DATA_DIR` (default `/opt/photisnadi/data`).
- [x] **REST endpoints:**
  - `GET /api/v1/tasks` — List tasks (query params: `project_id`, `status`, `priority`, `limit`)
  - `POST /api/v1/tasks` — Create task (auto-generates task key from project)
  - `PATCH /api/v1/tasks/:id` — Update task
  - `DELETE /api/v1/tasks/:id` — Delete task (cleans up dependency refs)
  - `GET /api/v1/projects` — List projects (query param: `include_archived`)
  - `GET /api/v1/rituals` — List rituals (query param: `frequency`, auto-resets)
  - `GET /api/v1/analytics` — Task analytics (status/priority breakdown, overdue, due today, blocked, completed this week)
  - `GET /api/v1/health` — Health check (public, no auth required)
- [x] **Authentication** — API key auth via `Authorization: Bearer <key>` header. Key configured via `PHOTISNADI_API_KEY` env var. Health endpoint exempt.
- [x] **Dockerfile update** — Server compiled to native AOT binary (`dart compile exe`). Entrypoint starts API server in background alongside Caddy. New `api` mode for API-only operation.
- [x] **Docker Compose update** — Exposes port 8081 for API access. `PHOTISNADI_API_KEY` env var. Named volume for persistent Hive data.
- [ ] **SecureYeoman MCP tool update** — Update `packages/mcp/src/tools/photisnadi-tools.ts` to call Photisnadi's REST API (`http://photisnadi:8081/api/v1/...`) instead of Supabase. Fall back to Supabase if REST API is unavailable.

### Design Notes

- The REST API is a **separate Dart process** from the Flutter web app (which runs entirely in-browser). They share no state at runtime — the API server has its own Hive boxes.
- If Supabase sync is enabled, the API server can optionally sync its local Hive state with Supabase on a schedule, making it the source of truth for MCP tools regardless of whether the browser app is open.
- Port 8081 is internal to the Docker network — not exposed to the host by default.

---

## SecureYeoman Integration

**Status:** Photisnadi side complete — YeomanService syncs task/ritual data to SecureYeoman brain, MCP server exposes 6 tools (list_tasks, create_task, update_task, get_rituals, analytics, sync).

### Completed (SecureYeoman side)

- [x] **MCP tool registration** — 6 tools registered in `packages/mcp/src/tools/photisnadi-tools.ts`, feature-gated via `MCP_EXPOSE_PHOTISNADI_TOOLS=true`. Currently calls Supabase API; will switch to Photisnadi REST API once implemented.
- [x] **Docker Compose integration** — Photisnadi container in SY's `docker-compose.yml` (GHCR pull for `dev` profile, local build for `full-dev` profile).

### Pending (SecureYeoman side)

- [ ] **Dashboard widget** — `PhotosnadiWidget.tsx` showing task counts and ritual streaks in SecureYeoman dashboard.
- [ ] **Switch MCP tools to REST API** — Once Photisnadi REST API is implemented, update `photisnadi-tools.ts` to call `http://photisnadi:8081/api/v1/...` instead of Supabase.
