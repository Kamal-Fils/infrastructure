# ==============================================================================
# Kamal&Fils — Infrastructure
# Toutes les commandes se lancent depuis ce dossier (infrastructure/).
# Le .env partagé à la racine alimente l'interpolation des deux stacks.
# ==============================================================================

ENV_FILE   := .env
CORE       := -f core/docker-compose.yml
JANGUBI    := -f apps/jangubi/docker-compose.yml
SENAFRIK1  := -f apps/senafrik1/docker-compose.yml
COMPOSE    := docker compose --env-file $(ENV_FILE)

# Projets nommés pour ne pas mélanger les stacks dans `docker compose ls`.
CORE_P      := -p core
JANGUBI_P   := -p jangubi
SENAFRIK1_P := -p senafrik1

# Charge POSTGRES_USER, MINIO_*, AWS_* … comme variables Make (le '-' ignore
# l'absence de .env). PAS de `export` : docker lit déjà --env-file, et le hash
# $$ de TRAEFIK_DASHBOARD_AUTH reste intact (jamais expansé ici).
-include $(ENV_FILE)

# Préfixes complets prêts à l'emploi.
COMPOSE_CORE      := $(COMPOSE) $(CORE_P) $(CORE)
COMPOSE_JANGUBI   := $(COMPOSE) $(JANGUBI_P) $(JANGUBI)
COMPOSE_SENAFRIK1 := $(COMPOSE) $(SENAFRIK1_P) $(SENAFRIK1)

# Calcule la fin de semaine liturgique (dimanche prochain) pour import_aelf.
TODAY     := $$(date +%Y-%m-%d)
NEXT_SUN  := $$(python3 -c 'from datetime import datetime, timedelta; print((datetime.now() + timedelta(days=(6 - datetime.now().weekday()))).date())')

.DEFAULT_GOAL := help
.PHONY: help \
        core-up core-down core-logs \
        jangubi-up jangubi-down jangubi-logs jangubi-deploy jangubi-rabbitmq-definitions \
        senafrik1-up senafrik1-down senafrik1-logs senafrik1-deploy \
        all-up all-down ps \
        jangubi-shell jangubi-dbshell jangubi-migrate jangubi-makemigrations \
        jangubi-check jangubi-collectstatic jangubi-createsuperuser \
        jangubi-import-aelf jangubi-clear-cache jangubi-flush-redis \
        jangubi-init-tv-categories \
        jangubi-check-embeddings jangubi-seed-embeddings jangubi-seed-embeddings-force \
        jangubi-seed-embeddings-async jangubi-import-bible-aelf \
        jangubi-reinit-bible jangubi-reinit-bible-aelf \
        jangubi-celery-logs jangubi-celery-restart jangubi-rabbitmq-stats jangubi-clean-audio \
        jangubi-minio-buckets jangubi-init-data jangubi-init-all \
        jangubi-seed-senegal jangubi-seed-demo jangubi-seed-reset jangubi-seed \
        jangubi-setup-periodic-tasks

help: ## Affiche cette aide
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2}'

# ============================================================================
# STACKS — démarrage / arrêt / déploiement
# ============================================================================

# ---- CORE (traefik, portainer, minio, uptime-kuma, grafana) ----------------
core-up: ## Démarre les services partagés (crée le réseau traefik-public)
	$(COMPOSE_CORE) up -d

core-down: ## Arrête les services partagés (conserve les volumes)
	$(COMPOSE_CORE) down

core-logs: ## Logs des services partagés
	$(COMPOSE_CORE) logs -f

# ---- JANGUBI (django, nextjs, celery, beats, db, redis, rabbitmq) ----------
# Rend rabbitmq/definitions.json depuis le template + .env. Garantit le broker
# user même sur un volume RabbitMQ existant (load_definitions). On n'extrait QUE
# les 2 variables (pas de `. .env` qui casse sur les valeurs à caractères shell
# spéciaux : le `(` de SECRET_KEY, le `$$` du hash Traefik…).
jangubi-rabbitmq-definitions: ## Génère rabbitmq/definitions.json (broker user) depuis le template
	@command -v envsubst >/dev/null 2>&1 || { echo "ERREUR : envsubst manquant → apt-get install -y gettext-base"; exit 1; }
	@test -f $(ENV_FILE) || { echo "ERREUR : $(ENV_FILE) introuvable (cp .env.example .env)"; exit 1; }
	@u=$$(grep -E '^RABBITMQ_DEFAULT_USER=' $(ENV_FILE) | head -1 | cut -d= -f2-); \
	 p=$$(grep -E '^RABBITMQ_DEFAULT_PASS=' $(ENV_FILE) | head -1 | cut -d= -f2-); \
	 [ -n "$$u" ] && [ -n "$$p" ] || { echo "ERREUR : RABBITMQ_DEFAULT_USER/PASS absents de $(ENV_FILE)"; exit 1; }; \
	 RABBITMQ_DEFAULT_USER="$$u" RABBITMQ_DEFAULT_PASS="$$p" \
	   envsubst '$$RABBITMQ_DEFAULT_USER $$RABBITMQ_DEFAULT_PASS' \
	     < apps/jangubi/rabbitmq/definitions.tpl.json \
	     > apps/jangubi/rabbitmq/definitions.json
	@echo "✓ apps/jangubi/rabbitmq/definitions.json généré (broker user)"

# Prérequis jangubi-rabbitmq-definitions : sans le fichier, Docker monte un
# dossier vide à sa place → load_definitions échoue.
jangubi-up: jangubi-rabbitmq-definitions ## Démarre la stack JanguBi
	$(COMPOSE_JANGUBI) up -d

jangubi-down: ## Arrête la stack JanguBi (conserve les volumes)
	$(COMPOSE_JANGUBI) down

jangubi-logs: ## Logs de la stack JanguBi (django)
	$(COMPOSE_JANGUBI) logs -f django

jangubi-deploy: jangubi-rabbitmq-definitions ## Déploie un tag précis : make jangubi-deploy TAG=sha-xxxxxxx
	@test -n "$(TAG)" || { echo "ERREUR : précisez TAG=... (ex: make jangubi-deploy TAG=sha-1a2b3c4)"; exit 1; }
	TAG=$(TAG) $(COMPOSE_JANGUBI) pull
	TAG=$(TAG) $(COMPOSE_JANGUBI) up -d

# ---- SENAFRIK1 (backend, frontend, worker, db, redis, backup) --------------
# Pas de prérequis type rabbitmq-definitions : broker Taskiq sur Redis.
senafrik1-up: ## Démarre la stack Sen'Afrik1 (staging)
	$(COMPOSE_SENAFRIK1) up -d

senafrik1-down: ## Arrête la stack Sen'Afrik1 (conserve les volumes)
	$(COMPOSE_SENAFRIK1) down

senafrik1-logs: ## Logs de la stack Sen'Afrik1 (backend)
	$(COMPOSE_SENAFRIK1) logs -f backend

senafrik1-deploy: ## Déploie un tag précis : make senafrik1-deploy TAG=sha-xxxxxxx
	@test -n "$(TAG)" || { echo "ERREUR : précisez TAG=... (ex: make senafrik1-deploy TAG=sha-1a2b3c4)"; exit 1; }
	TAG=$(TAG) $(COMPOSE_SENAFRIK1) pull
	TAG=$(TAG) $(COMPOSE_SENAFRIK1) up -d

# ---- Global ----------------------------------------------------------------
all-up: core-up jangubi-up ## Démarre core puis JanguBi (dans l'ordre)

all-down: jangubi-down core-down ## Arrête JanguBi puis core

ps: ## Conteneurs en cours (format compact)
	docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

# ============================================================================
# JANGUBI — exploitation Django (exécuté DANS le conteneur de prod)
# Équivalents des cibles du Makefile backend, adaptés au stack `jangubi`.
# ============================================================================
jangubi-shell: ## Shell Django (python manage.py shell)
	$(COMPOSE_JANGUBI) exec django python manage.py shell

jangubi-dbshell: ## Shell PostgreSQL (psql)
	$(COMPOSE_JANGUBI) exec db psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

jangubi-migrate: ## Applique les migrations
	$(COMPOSE_JANGUBI) exec django python manage.py migrate

jangubi-makemigrations: ## Génère les migrations (vérification)
	$(COMPOSE_JANGUBI) exec django python manage.py makemigrations

jangubi-check: ## django system check
	$(COMPOSE_JANGUBI) exec django python manage.py check

jangubi-collectstatic: ## Collecte les fichiers statiques
	$(COMPOSE_JANGUBI) exec django python manage.py collectstatic --noinput

jangubi-createsuperuser: ## Crée un super-utilisateur (interactif)
	$(COMPOSE_JANGUBI) exec django python manage.py createsuperuser

jangubi-import-aelf: ## Importe les lectures AELF de la semaine en cours
	$(COMPOSE_JANGUBI) exec django python manage.py import_aelf --start "$(TODAY)" --end "$(NEXT_SUN)"

jangubi-clear-cache: ## Vide le cache Django
	$(COMPOSE_JANGUBI) exec django python manage.py shell -c "from django.core.cache import cache; cache.clear(); print('Cache cleared.')"

jangubi-flush-redis: ## FLUSHALL Redis (cache uniquement — non destructif pour la DB)
	$(COMPOSE_JANGUBI) exec redis redis-cli FLUSHALL

jangubi-init-tv-categories: ## Initialise les catégories TV
	$(COMPOSE_JANGUBI) exec django python manage.py init_tv_categories

jangubi-setup-periodic-tasks: ## Enregistre les tâches Celery Beat en base (DatabaseScheduler)
	$(COMPOSE_JANGUBI) exec django python manage.py setup_periodic_tasks

# ---- Bible & RAG -----------------------------------------------------------
jangubi-check-embeddings: ## État des embeddings
	$(COMPOSE_JANGUBI) exec django python manage.py check_embeddings

jangubi-seed-embeddings: ## Génère les embeddings MANQUANTS (synchrone)
	$(COMPOSE_JANGUBI) exec django python manage.py seed_embeddings

jangubi-seed-embeddings-force: ## Recalcule TOUS les embeddings (écrase)
	$(COMPOSE_JANGUBI) exec django python manage.py seed_embeddings --force

jangubi-seed-embeddings-async: ## Dispatche le calcul des embeddings via Celery
	$(COMPOSE_JANGUBI) exec django python manage.py seed_embeddings --async

jangubi-import-bible-aelf: ## Importe la Bible (source AELF)
	$(COMPOSE_JANGUBI) exec django python manage.py import_bible init/bibles/format/json/bible-fr-aelf.json --source AELF

jangubi-reinit-bible: ## Réinitialise la Bible (source bible_fr) + AELF + cache
	$(COMPOSE_JANGUBI) exec django python manage.py shell -c "from apps.bible.models import Verse, Chapter, Book, DailyText; Verse.objects.all().delete(); Chapter.objects.all().delete(); Book.objects.all().delete(); DailyText.objects.all().delete(); print('Bible data cleared.')"
	$(COMPOSE_JANGUBI) exec django python manage.py import_bible init/bibles/format/json/bible-fr-aelf.json --source bible_fr
	$(COMPOSE_JANGUBI) exec django python manage.py import_aelf --start "$(TODAY)" --end "$(NEXT_SUN)"
	$(COMPOSE_JANGUBI) exec django python manage.py shell -c "from django.core.cache import cache; cache.clear(); print('Cache cleared.')"

jangubi-reinit-bible-aelf: ## Réinitialise la Bible (source AELF) + AELF + cache
	$(COMPOSE_JANGUBI) exec django python manage.py shell -c "from apps.bible.models import Verse, Chapter, Book, DailyText; Verse.objects.all().delete(); Chapter.objects.all().delete(); Book.objects.all().delete(); DailyText.objects.all().delete(); print('Bible data cleared.')"
	$(COMPOSE_JANGUBI) exec django python manage.py import_bible init/bibles/format/json/bible-fr-aelf.json --source AELF
	$(COMPOSE_JANGUBI) exec django python manage.py import_aelf --start "$(TODAY)" --end "$(NEXT_SUN)"
	$(COMPOSE_JANGUBI) exec django python manage.py shell -c "from django.core.cache import cache; cache.clear(); print('Cache cleared.')"

# ---- Maintenance -----------------------------------------------------------
jangubi-celery-logs: ## Logs du worker Celery
	$(COMPOSE_JANGUBI) logs -f celery

jangubi-celery-restart: ## Redémarre le worker Celery (recharge le code des tâches)
	$(COMPOSE_JANGUBI) restart celery

jangubi-rabbitmq-stats: ## Liste les files RabbitMQ
	$(COMPOSE_JANGUBI) exec rabbitmq rabbitmqctl list_queues

jangubi-clean-audio: ## Purge le cache audio local du chapelet (.mp3)
	$(COMPOSE_JANGUBI) exec django python manage.py shell -c "import os; from django.conf import settings; path = os.path.join(settings.MEDIA_ROOT, 'rosary'); [os.remove(os.path.join(path, f)) for f in os.listdir(path) if f.endswith('.mp3')]; print('Local audio cache cleaned.')"

# ============================================================================
# JANGUBI — initialisation & seed (bootstrap d'un nouveau serveur)
# ============================================================================
# MinIO vit dans le stack CORE : la création des buckets cible donc `-p core`,
# avec l'endpoint LOCAL au conteneur (127.0.0.1:9000), pas l'URL publique.
jangubi-minio-buckets: ## Crée les buckets MinIO (media privé + rosary-audio public)
	$(COMPOSE_CORE) exec minio sh -c "\
		mc alias set local http://127.0.0.1:9000 $(MINIO_ROOT_USER) $(MINIO_ROOT_PASSWORD) && \
		mc mb --ignore-existing local/$(AWS_STORAGE_BUCKET_NAME) && \
		mc mb --ignore-existing local/rosary-audio && \
		mc anonymous set public local/rosary-audio"

jangubi-init-data: jangubi-minio-buckets ## Bootstrap données : migrate + Bible + pgvector + rosaire + AELF
	@echo "==========================================================="
	@echo "   Initialisation des données JanguBi"
	@echo "==========================================================="
	$(COMPOSE_JANGUBI) exec django python manage.py migrate
	$(COMPOSE_JANGUBI) exec django python manage.py import_bible init/bibles/format/json/bible-fr-aelf.json --source bible_fr
	@echo "-- Extension pgvector (SQL conditionnel, lu depuis l'image django) --"
	$(COMPOSE_JANGUBI) exec -T django cat init/postgresql/pgvector_conditional.sql \
		| $(COMPOSE_JANGUBI) exec -T db psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)
	$(COMPOSE_JANGUBI) exec django python manage.py seed_rosary
	$(COMPOSE_JANGUBI) exec django python manage.py import_aelf --start "$(TODAY)" --end "$(NEXT_SUN)"
	@echo "==========================================================="
	@echo "   Initialisation terminée"
	@echo "==========================================================="

jangubi-seed-senegal: ## Seed structure territoriale (Province/Diocèse/Paroisse)
	$(COMPOSE_JANGUBI) exec django python manage.py seed_senegal

jangubi-seed-demo: ## Seed données de démonstration
	$(COMPOSE_JANGUBI) exec django python manage.py seed_demo

jangubi-seed-reset: ## Réinitialise puis re-seed les données de démo
	$(COMPOSE_JANGUBI) exec django python manage.py seed_demo --reset

jangubi-seed: jangubi-seed-senegal jangubi-seed-demo ## Seed complet (territoire + démo)
	@echo "Seed terminé (seed_senegal + seed_demo)."

jangubi-init-all: jangubi-init-data ## Alias bootstrap complet (= jangubi-init-data)
