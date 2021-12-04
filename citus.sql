
SELECT *
FROM pg_available_extensions
WHERE name
LIKE '%citus%';

SHOW citus.version;

SELECT citus_version();


-- ===================================================================
-- test utility statement functionality
-- ===================================================================
SET citus.next_shard_id = 990000;
-- default 32
SET citus.shard_count = 2;
-- default 1 = can't replica
SET citus.shard_replication_factor = 1;

SELECT citus_drop_all_shards('sharded_table','','');
SET citus.shard_count TO 4;
SET citus.next_shard_id TO 999001;
ALTER SEQUENCE pg_catalog.pg_dist_colocationid_seq RESTART 1400000;
CREATE TABLE lockable_table ( name text, id bigint );
SELECT create_distributed_table('lockable_table', 'id', 'hash', colocate_with := 'none');
SET citus.shard_count TO 2;
SET citus.next_shard_id TO 990002;


SET citus.next_shard_id TO 1220000;
ALTER SEQUENCE pg_catalog.pg_dist_colocationid_seq RESTART 1390000;
ALTER SEQUENCE pg_catalog.pg_dist_groupid_seq RESTART 1;
SET citus.enable_object_propagation TO off; -- prevent object propagation on add node during setup

SET citus.replication_model to 'statement';

-- pgbench, 

SELECT create_distributed_table('pgbench_accounts', 'aid', 'hash');
SELECT undistribute_table('pgbench_accounts');

SELECT create_reference_table('pgbench_accounts') ;

SELECT truncate_local_data_after_distributing_table($$public.pgbench_accounts$$);

select * from citus_tables;

explain (analyze) select * from pgbench_accounts where aid=1;

-- 

SELECT citus_set_coordinator_host('demo.service.consul');
SELECT * FROM citus_add_node('worker-1.node.consul', 5432, 1, 'primary' );
SELECT * FROM citus_add_node('worker-2.node.consul', 5432, 1, 'secondary' );

alter system set citus.use_secondary_nodes=always;
select pg_reload_conf();

select * from master_update_node(3, 'worker-2.node.consul', 5432);

-- get the active nodes
--SELECT master_get_active_worker_nodes();
--SELECT master_remove_node('localhost', :worker_2_port);
--SELECT master_disable_node('localhost', :worker_2_port);

SELECT * FROM pg_dist_node;

-- primary;
SELECT * FROM get_rebalance_table_shards_plan();
SELECT rebalance_table_shards();

TRUNCATE pg_dist_colocation;
ALTER SEQUENCE pg_catalog.pg_dist_colocationid_seq RESTART 1390000;
SELECT * FROM citus_activate_node('localhost', :worker_2_port);

-- create users like this so results of community and enterprise are same
SET citus.enable_object_propagation TO ON;
SET client_min_messages TO ERROR;
CREATE USER non_super_user;
CREATE USER node_metadata_user;
SELECT 1 FROM run_command_on_workers('CREATE USER node_metadata_user');
RESET client_min_messages;
SET citus.enable_object_propagation TO OFF;
GRANT EXECUTE ON FUNCTION master_activate_node(text,int) TO node_metadata_user;
GRANT EXECUTE ON FUNCTION master_add_inactive_node(text,int,int,noderole,name) TO node_metadata_user;
GRANT EXECUTE ON FUNCTION master_add_node(text,int,int,noderole,name) TO node_metadata_user;
GRANT EXECUTE ON FUNCTION master_add_secondary_node(text,int,text,int,name) TO node_metadata_user;
GRANT EXECUTE ON FUNCTION master_disable_node(text,int) TO node_metadata_user;
GRANT EXECUTE ON FUNCTION master_remove_node(text,int) TO node_metadata_user;
GRANT EXECUTE ON FUNCTION master_update_node(int,text,int,bool,int) TO node_metadata_user;

-- worker
\d+

SELECT citus_drain_node('citus_worker_3',5432);

SELECT * FROM citus_set_node_property('citus_worker_3', 5432, 'shouldhaveshards', true);
