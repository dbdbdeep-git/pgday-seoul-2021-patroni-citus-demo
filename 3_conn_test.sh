#!/bin/bash

PGPASSWORD=postgres psql -h 127.0.0.1 -p 5000 -d postgres -U postgres \
	-c "select inet_server_addr(), inet_server_port();"
