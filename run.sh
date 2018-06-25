#!/bin/bash

#   $1  Path to CSV file
#   $2  name of database

set -e

# Setup db
psql -f psql_script.sql qore_test

# Run qore script
qore homework.q --input "${1}" --connection "pgsql:$(whoami)@${2}" -v
