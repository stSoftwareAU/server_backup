#!/bin/bash
set -e 
folder=${HOME}/backups/
mkdir -p $folder

server=$1
master=$2
host=`hostname`

if [ -z $host ]; then
    host=ded1858
fi

if [ $host = 'ded1858' ]; then
    host=www3
fi
if [ $host = 'ded1934' ]; then
    host=www4
fi

user=`whoami`
#exclude="1,2,2097152251,2010,3070,3080,8888,3100,1510,3101"

pg_dump -U postgres -h $server $master > $folder/${master}.dump

if [ ! -s "$folder/${master}.dump" ]
then
    echo "Dump failed"
    exit 1
fi

gzip -f $folder/${master}.dump

tmpfile=$(mktemp /tmp/master.XXXXXX)


sql="select id,signature,serverurl,name,connecttype from aspc_dns, aspc_virtualdb where aspc_dns.databaseid=aspc_virtualdb.id order by id"
echo "$sql" |psql -U postgres -h $server $master > $tmpfile

today=`date +%a`

function sendToS3() {
    file=$1
    to=$2
    if [ "${s3}" != false ]; then

        S3TOOLS="./s3-tools"
        S3PutScript="${S3TOOLS}/putS3.sh"

        if [ ! -d "${S3TOOLS}" ]; then
            git clone https://github.com/stSoftwareAU/s3-tools.git
        fi

        set +e
        $S3PutScript $file $to
        RESULT=$?
        set -e
        if [ ! $RESULT -eq 0 ]; then
            echo "failed to send $file"
        fi
    fi
}

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
       set +e
       pg_dump -U postgres -h $layer_server $layer_name > $folder/$layer_signature.dump
       set -e
       if [ -s $folder/$layer_signature.dump ]; then
          gzip -f $folder/$layer_signature.dump
          ms=`date +%s000`
          echo "UPDATE aspc_virtualdb SET backup_ms=${ms} WHERE id=${layer_id}" |psql -U postgres -h $server $master
          
          toname="$user/$host/$today/$layer_signature.dump.gz"
          echo "sending $folder/$layer_signature.dump.gz to s3 $toname"
          sendToS3 $folder/$layer_signature.dump.gz $toname
       else
          echo "FAILED: $layer_signature" 
          rm $folder/$layer_signature.dump
       fi
    fi
done < $tmpfile

rm $tmpfile
