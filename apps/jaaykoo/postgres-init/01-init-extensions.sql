-- ==============================================================================
-- JAAYKOO — Extensions base principale Django
--
-- Ce script est exécuté automatiquement au premier démarrage du conteneur `db`
-- (volume vide), connecté à la base POSTGRES_DB par l'entrypoint postgres.
-- L'entrypoint de l'image backend re-vérifie pg_trgm + vector à chaque boot
-- (CREATE EXTENSION IF NOT EXISTS) — ce script est la ceinture, lui les bretelles.
--
-- L'image pgvector/pgvector:pg17 embarque l'extension `vector` (recherche
-- sémantique 1536-dim de apps/search).
-- ==============================================================================

-- Extensions requises par Django (uuid, recherche floue, accents, embeddings)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "unaccent";
CREATE EXTENSION IF NOT EXISTS "vector";

\echo '============================================='
\echo 'jaaykoo db : extensions configurées (uuid-ossp, pg_trgm, unaccent, vector)'
\echo '============================================='
