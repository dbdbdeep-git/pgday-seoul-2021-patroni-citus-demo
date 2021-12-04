#!/bin/bash

pgbench -h 127.0.0.1 -U postgres -p 5000 -i -s 10 postgres
