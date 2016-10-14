#!/bin/bash
set -e 
folder=${HOME}/backups/
mkdir -p $folder

server=$1
master=$2
#exclude="1,2,2097152251,2010,3070,3080,8888,3100,1510,3101"

pg_dump -U postgres -h $layer_server $master | gzip -c > $folder/${master}.dump.gz

tmpfile=$(mktemp /tmp/master.XXXXXX)


sql="select id,signature,serverurl,name,connecttype from aspc_dns, aspc_virtualdb where aspc_dns.databaseid=aspc_virtualdb.id order by id"
echo "$sql" |psql -U postgres -h $server $master > $tmpfile

while read line
do
    layer_id=`echo "$line"|cut -d'|' -f 1| tr -d ' '`
    layer_signature=`echo "$line"|cut -d'|' -f 2| tr -d ' '`
    layer_server=`echo "$line"|cut -d'|' -f 3| tr -d ' '`
    layer_name=`echo "$line"|cut -d'|' -f 4| tr -d ' '`
    layer_type=`echo "$line"|cut -d'|' -f 5| tr -d ' '`

    if [[ "$layer_type" = "POSTGRESQL" ]];
    then
       echo "dump $layer_signature {$layer_server/$layer_name}"
       dbtmp=$(mktemp /tmp/$layer_signature.XXXXXX)
       set +e
       pg_dump -U postgres -h $layer_server $layer_name | gzip -c > $dbtmp
       if [ $? -eq 0 ]; then
#          echo OK
          mv $dbtmp $folder/$layer_signature.dump.gz
          ms=`date +%s000`
          echo "UPDATE aspc_virtualdb SET backup_ms=${ms} WHERE id=${layer_id}" |psql -U postgres -h $server $master
       else
          echo "FAILED: $layer_signature" 
          rm $dbtmp
       fi
       set -e
    fi
done < $tmpfile

rm $tmpfile

