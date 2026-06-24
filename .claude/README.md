# `.claude/` — conventions Claude Code (repo `infrastructure`, Docker/Traefik)

Bundle **versionné** de conventions Claude Code pour le repo d'infrastructure
(Docker Compose + Traefik sur le VPS kamalfils.app), committé pour être **portable
entre machines** (`git pull` suffit). Claude Code charge automatiquement les
`rules/`, `skills/`, `agents/`, `commands/` d'un `.claude/` de projet.

## Contenu

- **`rules/`** — `common/` (style, sécurité, git-workflow, review génériques).
- **`skills/`** — devops : `docker-patterns`, `deployment-patterns`, `github-ops`,
  `database-migrations`, `postgres-patterns`, `security-review`, `security-scan`,
  `verification-loop`, `code-tour`.
- **`agents/`** — `cicd-infra-builder`, `cicd-backend-django`, `cicd-frontend-nextjs`,
  `build-error-resolver`, `security-reviewer`, `doc-updater`.
- **`commands/`** — `/code-review`, `/verify`, `/review-pr`.
- **`memory/`** — mémoire projet portable (statut des phases, déploiement
  apps/senafrik1, actions ops restantes).

## Usage sur l'autre machine

`git pull` → Claude Code charge `.claude/`. Rien à installer.

> NB : `core/` (Traefik/Portainer/MinIO/…) est partagé et ne doit pas être modifié
> sans raison explicite. La stack de l'app vit dans `apps/senafrik1/`.
