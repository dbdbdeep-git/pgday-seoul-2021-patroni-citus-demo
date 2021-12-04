#!/usr/bin/env python2
# -*- coding: utf-8 -*-

import os
import time
import argparse
import logging
import yaml
import psycopg2


def get_pg_role(url):
    result = 'unknow'
    try:
        with psycopg2.connect(url, connect_timeout=2) as conn:
            conn.autocommit = True
            cur = conn.cursor()
            cur.execute("select pg_is_in_recovery()")
            row = cur.fetchone()
            if row[0] == True:
                result = 'secondary'
            elif row[0] == False:
                result = 'primary'
    except Exception as e:
        logging.debug('get_pg_role() failed. url:{0} error:{1}'.format(
                    url, str(e)))

    return result

def update_worker(url, role, groupid, nodename, nodeport):
    logging.debug('call update worker. role:{0} groupid:{1} nodename:{2} nodeport:{3}'.format(
                    role, groupid, nodename, nodeport))
    try:
        sql = "select nodeid,nodename,nodeport from pg_dist_node where groupid={0} and noderole = '{1}' order by nodeid limit 1".format(
                                                                        groupid, role)
        conn = psycopg2.connect(url, connect_timeout=2)
        conn.autocommit = True
        cur = conn.cursor()
        cur.execute(sql)
        row = cur.fetchone()
        if row is None:
            logging.error("can not found nodeid whose groupid={0} noderole = '{1}'".format(groupid, role))
            return False
        
        nodeid = row[0]
        oldnodename = row[1]
        oldnodeport = str(row[2])

        if oldnodename == nodename and oldnodeport == nodeport:
            logging.debug('skip for current nodename:nodeport is same')
            return False

        sql= "select master_update_node({0}, '{1}', {2})".format(nodeid, nodename, nodeport)
        ret = cur.execute(sql)
        logging.info("Changed worker node {0} from '{1}:{2}' to '{3}:{4}'".format(nodeid, oldnodename, oldnodeport, nodename, nodeport))
        return True
    except Exception as e:
        logging.error('update_worker() failed. role:{0} groupid:{1} nodename:{2} nodeport:{3} error:{4}'.format(
                    role, groupid, nodename, nodeport, str(e)))
        return False


def main():
    parser = argparse.ArgumentParser(description='Script to auto setup Citus worker')
    parser.add_argument('-c', '--config', default='citus_controller.yml')
    parser.add_argument('-d', '--debug', action='store_true', default=False)
    args = parser.parse_args()

    if args.debug:
        logging.basicConfig(format='%(asctime)s %(levelname)s: %(message)s', level=logging.DEBUG)
    else:
        logging.basicConfig(format='%(asctime)s %(levelname)s: %(message)s', level=logging.INFO)

    # read config file
    f = open(args.config,'r')
    contents = f.read()
    config = yaml.load(contents, Loader=yaml.FullLoader)

    cn_connect_address = config['postgresql']['connect_address']
    username = config['postgresql']['authentication']['superuser']['username']
    password = config['postgresql']['authentication']['superuser']['password']
    databases = config['citus']['databases']
    workers = config['citus']['workers']

    loop_wait = config['citus'].get('loop_wait',10)
 
    logging.info('start main loop')
    loop_count = 0
    while True:
        loop_count += 1
        logging.debug("##### main loop start [{}] #####".format(loop_count))

        dbname = databases[0]
        cn_url = "postgres://{0}/{1}?user={2}&password={3}".format(
                                    cn_connect_address,dbname,username,password)
        if(get_pg_role(cn_url) == 'primary'):
            for worker in workers:
                groupid = worker['groupid']
                nodes = worker['nodes']
    
                ## get role of worker nodes
                primarys = []
                secondarys = []
                for node in nodes:
                    wk_url = "postgres://{0}/{1}?user={2}&password={3}".format(
                                    node,dbname,username,password)
                    role = get_pg_role(wk_url)
                    if role == 'primary':
                        primarys.append(node) 
                    elif role == 'secondary':
                        secondarys.append(node) 
    
                logging.debug('Role info groupid:{0} primarys:{1} secondarys:{2}'.format(
                                        groupid,primarys,secondarys))

                ## update worker node
                for dbname in databases:
                    cn_url = "postgres://{0}/{1}?user={2}&password={3}".format(
                                        cn_connect_address,dbname,username,password)
                    if len(primarys) == 1:
                        nodename = primarys[0].split(':')[0]
                        nodeport = primarys[0].split(':')[1]
                        update_worker(cn_url, 'primary', groupid, nodename, nodeport)

                    """
                    Citus的pg_dist_node元数据中要求nodename:nodeport必须唯一，所以无法同时支持secondary节点的动态更新。
                    一个可能的回避方法是为每个worker配置2个IP地址，一个作为parimary角色时使用，另一个作为secondary角色时使用。

                    if len(secondarys) >= 1:
                        nodename = secondarys[0].split(':')[0]
                        nodeport = secondarys[0].split(':')[1]
                        update_worker(cn_url, 'secondary', groupid, nodename, nodeport)
                    elif len(secondarys) == 0 and len(primarys) == 1:
                        nodename = primarys[0].split(':')[0]
                        nodeport = primarys[0].split(':')[1]
                        update_worker(cn_url, 'secondary', groupid, nodename, nodeport)
                    """

        time.sleep(loop_wait)

if __name__ == '__main__':
    main()
