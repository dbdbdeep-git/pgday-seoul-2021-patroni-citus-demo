SELECT citus_set_coordinator_host('demo.service.consul');

SELECT * FROM citus_add_node('worker-1.node.consul', 5432, 1, 'primary' );
SELECT * FROM citus_add_node('worker-2.node.consul', 5432, 1, 'secondary' );

SELECT create_distributed_table('pgbench_accounts', 'aid', 'hash');

SELECT COUNT(*) FROM pgbench_accounts;

EXPLAIN (ANALYZE)
SELECT *
FROM pgbench_accounts
WHERE aid = 1;

