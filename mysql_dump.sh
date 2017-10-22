#!/bin/bash
set -e 
folder=${HOME}/backups/
mkdir -p $folder

server=$1
database=$2

mysqldump --defaults-group-suffix=$server $database | gzip -9 > $folder/$database.mysql.dump.sql.gz

if [ ! -s "$folder/$database.mysql.dump.sql.gz" ]
then
    echo "Dump failed"
    exit 1
fi

