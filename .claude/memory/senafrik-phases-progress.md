---
name: senafrik-phases-progress
description: "Sen'Afrik1 Conciergerie — which build phases are done vs remaining"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1d889a3e-be45-4f79-a275-17dd87c05994
---

Sen'Afrik1 Conciergerie = internal ops tool (3 repos: `api` FastAPI, `ui` Next.js 14,
`infrastructure` Docker/Traefik). Plan: `Plan_Conception_A-Z_SenAfrik1.md` + `CLAUDE.md`.

**Phases 0–4 all DEVELOPED (code) as of 2026-06-24.** Phase 0 fondations, 1 Auth, 2 cœur métier,
**3 caisse/finances/agenda (back + front)**, **4 frontend Dockerfile + CI/CD (api/ui/infra) +
durcissement + Sentry config**. All work committed on branch `develop` in each repo (Conventional
Commits); remotes `Sen-Afrik1/api`, `Sen-Afrik1/ui`, `Kamal-Fils/infrastructure` — **branches not yet
pushed, CI never run**.

Phase 3 backend modules use the runtime-safe direct-ORM `db.add()` create pattern (NOT
`crud.create(dict)`); a Phase-4 durcissement commit fixed the pre-existing `crud.create(dict)`
500-crash in clients/prestataires/référentiels, the `exchange_rate_set` NoResultFound, and the
invitation-email `render_template(name=)` TypeError, plus the test harness (conftest header-based
user resolution). **Backend suite now fully green: 419 passed / 0 fail on real Postgres; 210 passed
sans-Docker gate; ruff check clean; mypy 7 no-any-return relâché.** Caveat: [[senafrik-backend-test-env]].

**Remaining = OPS actions only (no code):** DNS A records `api-senafrik1`/`senafrik1` →
164.92.238.231 (before first `up`); GitHub secrets (`DOCKERHUB_USERNAME/TOKEN`, `INFRA_DISPATCH_TOKEN`,
`SSH_*`) + infra `.env`; `uv add 'sentry-sdk[fastapi]'` to activate Sentry capture; prod backups;
branch protections; push `develop` to trigger CI.
