# Photis Nadi Roadmap

> **NOTE: ONLY OPEN ITEMS** — See CHANGELOG.md for completed work.

## Overview
Cross-platform productivity app combining Kanban-style task management with daily ritual tracking. Built with Flutter.

---

## Engineering Backlog

### AGNOS Marketplace Onboarding

Items identified during cross-project review (2026-03-09). AGNOS-side work (recipe update, version bump, agpkg command, API server install) is done.

| Item | Effort | Status | Description |
|------|--------|--------|-------------|
| Build Flutter Linux bundle | 30 min | Done | CI builds this; local verification pending next `flutter build linux --release` run |
| Add app icon for marketplace | 30 min | Done | Added `assets/images/photisnadi.svg` and `photisnadi.png` (256x256). Install step: `cp` to `$PKG/usr/share/icons/` |
| Agent registration with daimon | 1 hour | Done | `lib/server/agnos.dart` — registers via `POST /v1/agents/register` when `AGNOS_AGENT_REGISTRY_URL` is set, heartbeats every 30s, deregisters on SIGINT/SIGTERM |
| MCP tool registration with daimon | 1 hour | Done | Registers all 6 MCP tools via `POST /v1/mcp/tools` after agent registration succeeds |
| Audit event forwarding | 1 hour | Done | Task create/update/delete in `api.dart` forward events to `POST /v1/audit/forward` when `AGNOS_AUDIT_URL` is set |
| Verify sandbox in AGNOS (Docker) | 2 hours | Done | Docker container verified 2026-03-14: API server + Caddy start cleanly, health endpoints respond, auth rejects bad/missing tokens (401/403), Hive CRUD works, data persists across restart, runs as non-root (uid 1005), web UI served. |
| Verify sandbox in AGNOS (qemu/baremetal) | 1 hour | Not started | Retest on qemu and baremetal with Landlock/seccomp sandbox active. Verify Supabase sync works through `*.supabase.co` allowed hosts. Docker cannot exercise Landlock/seccomp — needs real AGNOS environment. |

**AGNOS-side work (done):**
- Recipe bumped to `2026.3.9`, license corrected to MIT
- `agpkg pack-flutter` command uncommented and ready
- Dart API server install step added (`dart compile exe bin/server.dart`)
- Supabase hosts already restricted (`*.supabase.co`, `*.supabase.in`)
- Wayland requirements declared (core, xdg-shell)

### ~~Caddy API Reverse Proxy~~ ✅ Done

Fixed. Caddyfile now uses `handle /api/*` block to proxy to the Dart API server on localhost:8081, with a separate `handle` block for the Flutter SPA. API endpoints (health, handshake, tasks, etc.) are accessible on port 8080 alongside the web UI.

### Test Coverage
- **Current**: 52.1% (1818/3492 lines, 396 tests)
- **Target**: 60%
- **Well-covered**: Models, validators, serializers, auth middleware, export/import, filter/sort, theme service, board/column management, task CRUD, rituals, tags, sync parsing, performance monitor, Hive persistence round-trips
- **Gaps**: Widget tests, sync service integration (376 lines), dialog flows, desktop integration

---
