#!/bin/bash

folder=${HOME}/backups/
mkdir -p $folder

server=$1
master=$2
exclude="1,2,2097152251,2010,3070,3080,8888,3100,1510,3101"
sql="select id,signature,serverurl,name from aspc_dns, aspc_virtualdb where aspc_dns.databaseid=aspc_virtualdb.id AND id not in ( $exclude) order by id"
echo "$sql" |psql -U postgres -h $server $master > /tmp/$master.txt

while read line
do
    layer_signature=`echo "$line"|cut -d'|' -f 2| tr -d ' '`
    layer_server=`echo "$line"|cut -d'|' -f 3| tr -d ' '`
    layer_name=`echo "$line"|cut -d'|' -f 4| tr -d ' '`

    if [[ "$layer_server" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]];
    then
       echo "dump $layer_signature {$layer_server/$layer_name}"
       pg_dump -U postgres -h $layer_server $layer_name | gzip -c > $folder/$layer_signature.dump.gz
    fi
done < /tmp/$master.txt

