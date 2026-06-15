# Infrastructure — Kamal&Fils

Configuration Docker Compose du serveur **`164.92.238.231`** (domaine **`kamalfils.app`**).

Ce dépôt orchestre deux niveaux :

| Niveau | Dossier | Rôle |
|---|---|---|
| **Core** | [`core/`](core/docker-compose.yml) | Services partagés par toutes les apps : Traefik, Portainer, MinIO, Uptime Kuma, Grafana |
| **Apps** | [`apps/jangubi/`](apps/jangubi/docker-compose.yml) | Stack applicative JanguBi (Django, Next.js, Celery, PostgreSQL, Redis, RabbitMQ) |

Le réseau Docker **`traefik-public`** est créé par le stack *core* et utilisé en `external` par chaque application. Traefik est le **seul** service à exposer les ports `80`/`443`.

---

## Domaines

| Sous-domaine | Service |
|---|---|
| `traefik.kamalfils.app` | Dashboard Traefik (basic-auth) |
| `portainer.kamalfils.app` | Portainer |
| `s3.kamalfils.app` | MinIO — API S3 |
| `bucket.kamalfils.app` | MinIO — console |
| `uptime.kamalfils.app` | Uptime Kuma |
| `grafana.kamalfils.app` | Grafana |
| `api-jangubi.kamalfils.app` | JanguBi — API Django (ASGI) |
| `jangubi.kamalfils.app` | JanguBi — frontend Next.js |

> **DNS** : faire pointer chacun de ces sous-domaines (enregistrement `A`) vers `164.92.238.231` **avant** le premier démarrage, sinon le challenge HTTP Let's Encrypt échoue.

---

## Mise en route

```bash
# 1. Configurer les secrets
cp .env.example .env
nano .env                      # remplir TOUTES les valeurs « change-me »

# 2. Générer le hash du dashboard Traefik, DOUBLER chaque '$' en '$$',
#    puis le coller dans TRAEFIK_DASHBOARD_AUTH (sinon Compose tronque le hash).
docker run --rm httpd:alpine htpasswd -nb admin 'monMotDePasse'

# 3. Démarrer l'infra partagée (crée le réseau traefik-public)
make core-up

# 4. Démarrer JanguBi
make jangubi-up

# 5. Vérifier
make ps
```

Au premier `up`, Traefik négocie les certificats TLS via Let's Encrypt (quelques secondes par domaine).

---

## Commandes (`make help`)

| Commande | Effet |
|---|---|
| `make core-up` / `core-down` / `core-logs` | Gère le stack partagé |
| `make jangubi-up` / `jangubi-down` / `jangubi-logs` | Gère la stack JanguBi |
| `make jangubi-deploy TAG=sha-xxxxxxx` | `pull` du tag puis `up -d` (déploiement CI) |
| `make all-up` / `all-down` | Tout démarrer / tout arrêter (ordre respecté) |
| `make ps` | Liste des conteneurs (format compact) |

### Exploitation JanguBi (commandes Django dans le conteneur)

Reprises du Makefile backend, adaptées au stack de prod (`make help` pour la liste complète) :

| Commande | Effet |
|---|---|
| `make jangubi-migrate` / `jangubi-shell` / `jangubi-dbshell` | Migrations, shell Django, shell psql |
| `make jangubi-createsuperuser` | Crée un super-utilisateur |
| `make jangubi-init-data` | Bootstrap : migrate + Bible + pgvector + buckets MinIO + rosaire + AELF |
| `make jangubi-seed-senegal` / `jangubi-seed` | Structure territoriale (+ démo) |
| `make jangubi-import-aelf` | Importe les lectures AELF de la semaine |
| `make jangubi-seed-embeddings` / `jangubi-check-embeddings` | RAG / pgvector |
| `make jangubi-setup-periodic-tasks` | Enregistre les tâches Celery Beat en base |
| `make jangubi-celery-logs` / `jangubi-celery-restart` / `jangubi-rabbitmq-stats` | Maintenance workers |

---

## Déploiement continu

La CI des dépôts applicatifs construit et pousse les images sur DockerHub :

```text
${DOCKERHUB_USERNAME}/jangubi-backend:<tag>
${DOCKERHUB_USERNAME}/jangubi-frontend:<tag>
```

Le tag est généralement le SHA court du commit. Sur le serveur :

```bash
make jangubi-deploy TAG=sha-1a2b3c4
```

`TAG` est aussi lisible depuis `.env` (`TAG=latest` par défaut) ; le passer en argument prime sur la valeur du fichier.

---

## Architecture réseau

```text
                         Internet (:80 / :443)
                                │
                          ┌─────▼─────┐
                          │  Traefik  │   TLS Let's Encrypt
                          └─────┬─────┘
              ┌─────────────────┼──────────────────────────────┐
              │      réseau « traefik-public » (external)       │
              │   django · nextjs · portainer · minio · grafana │
              └─────────────────┬──────────────────────────────┘
                                │  (django uniquement, 2e patte)
                    ┌───────────▼───────────────┐
                    │  réseau « jangubi-internal »│  privé, non exposé
                    │  db · redis · rabbitmq      │
                    │  celery · beats             │
                    └─────────────────────────────┘
```

- `db`, `redis`, `rabbitmq` ne sont **jamais** exposés (ni à Traefik, ni à l'hôte).
- `celery` / `beats` restent privés mais gardent un accès **sortant** (Gemini, AELF, SMTP, S3).
- `django` migre la base au démarrage (entrypoint) ; `celery`/`beats` attendent qu'il soit *healthy*.

---

## Notes de sécurité

- Le `.env` réel est **git-ignoré** — ne jamais le committer. Voir [`.gitignore`](.gitignore).
- Le dashboard Traefik est protégé par basic-auth (`TRAEFIK_DASHBOARD_AUTH`) — penser à doubler les `$` du hash en `$$` dans `.env`.
- Les noms de variables JanguBi (`AWS_S3_*`, `DATABASE_URL`, `CELERY_BROKER_URL`, …) correspondent à ceux lus par les settings `config.django.production` du backend.
