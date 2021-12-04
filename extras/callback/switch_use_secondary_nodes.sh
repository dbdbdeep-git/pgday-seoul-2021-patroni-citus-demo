#!/bin/bash

DBNAME=postgres
KILL_ALL_SQL="select pg_terminate_backend(pid) from pg_stat_activity  where backend_type='client backend' and application_name <> 'Patroni' and pid <> pg_backend_pid()"

action=$1
role=$2
cluster=$3


log()
{
  echo "switch_use_secondary_nodes: $*"
}

alter_use_secondary_nodes()
{
  value="$1"
  oldvalue=`psql -d postgres -Atc "show citus.use_secondary_nodes"`
  if [ "$value" = "$oldvalue" ] ; then
    log "old value of use_secondary_nodes already be '${value}', skip change"
    return
  fi

  psql -d ${DBNAME} -c "alter system set citus.use_secondary_nodes=${value}" >/dev/null
  rc=$?
  if [ $rc -ne 0 ] ;then
    log "fail to alter use_secondary_nodes to '${value}' rc=$rc"
    exit 1
  fi

  psql -d ${DBNAME} -c 'select pg_reload_conf()' >/dev/null
  rc=$?
  if [ $rc -ne 0 ] ;then
    log "fail to call pg_reload_conf() rc=$rc"
    exit 1
  fi

  log "changed use_secondary_nodes to '${value}'"

  ## kill all existing connections
  killed_conns=`psql -d ${DBNAME} -Atc "${KILL_ALL_SQL}" | wc -l`
  rc=$?
  if [ $rc -ne 0 ] ;then
    log "failed to kill connections rc=$rc"
    exit 1
  fi
  
  log "killed ${killed_conns} connections"

}

log "switch_use_secondary_nodes start args:'$*'"

case $action in
  on_start|on_restart|on_role_change)
    case $role in
      master)
        alter_use_secondary_nodes never
        ;;
      replica)
        alter_use_secondary_nodes always
        ;;
      *)
        log "wrong role '$role'"
        exit 1
        ;;
    esac
    ;;
  *)
    log "wrong action '$action'"
    exit 1
    ;;
esac
