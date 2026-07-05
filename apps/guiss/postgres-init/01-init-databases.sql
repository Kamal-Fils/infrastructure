-- ==============================================================================
-- GUISS TALLI — Extensions base principale Django
--
-- Ce script est exécuté automatiquement au premier démarrage du conteneur `db`
-- (volume vide). La base `depistage_db` est déjà créée par le point d'entrée
-- postgres via l'env var POSTGRES_DB. Ce script ajoute uniquement les
-- extensions requises par Django.
--
-- Bases legacy (keycloak_db, usermanagement_db) supprimées — Keycloak et
-- FastAPI UserManagement ont été retirés de l'architecture.
-- ==============================================================================

\c depistage_db

-- Extensions requises par Django (uuid, recherche floue, accents)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "unaccent";

\echo '============================================='
\echo 'depistage_db : extensions configurées (uuid-ossp, pg_trgm, unaccent)'
\echo '============================================='
