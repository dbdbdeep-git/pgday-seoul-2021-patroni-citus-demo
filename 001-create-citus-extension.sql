-- wrap in transaction to ensure Docker flag always visible
BEGIN;
CREATE EXTENSION citus;
CREATE EXTENSION pg_stat_statements;

-- add Docker flag to node metadata
UPDATE pg_dist_node_metadata SET metadata=jsonb_insert(metadata, '{docker}', 'true');
COMMIT;
