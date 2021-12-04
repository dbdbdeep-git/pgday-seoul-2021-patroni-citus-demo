#!/bin/bash

psql -c "CREATE EXTENSION citus;"
psql -c "CREATE EXTENSION hll;"
psql -c "CREATE EXTENSION topn;"
