#!/bin/bash

# echo "IFS=$IFS"

trap ctrl_c INT
function ctrl_c() { echo "Abort!" && kill -9 $$ ; }

# Pour lister l'état de toutes les machines avec Nagios3
# https://services.emi.u-bordeaux.fr/nagios3/cgi-bin/status.cgi?hostgroup=all

ROOM105="alia bellonda corba dama feydrautha ghanima halleck idaho lucila murbella noree odrade scytale sheeana stilgar talamane taraza tegs tuek usul"
ROOM204="botero buffet cassatt escher goya kandinsky lautrec legreco marquet morissot opalka redon rembrandt seurat signac tissot velasquez vlaminck watteau whistler"
ROOM008="beetlejuice braque cezanne chagall corot dali degas ernst gauguin leger leonardo magritte matisse millet miro modigliani monet pissarro renoir vangogh"

function getRoom()
{
    local ROOM="$1"
    local HOSTS=$(jq -r ".SALLES[\"$ROOM\"] | .[]" < /net/ens/cremi_salle.json)
    local RET=$?
    ( IFS=$' ' ; echo "$HOSTS" )
    return $RET
}

# TODO: use /net/ens/cremi_salle.json
# ROOM001=$(cat /net/ens/cremi_salle.json | jq -r '.SALLES["001"] | .[]')
ROOM101=$(getRoom "101")
ROOM104=$(getRoom "104")

# echo "ROOM 001: $ROOM001"
# ( IFS=$' ' ; echo "ROOM 101: $ROOM101" )

CREMI="$ROOM104"

if [ $# -eq  0 ] ; then
   echo "===== Host Monitoring ====="
   echo "ping..."
   fping $CREMI
   exit 0
elif [ $# -eq 1 ] ; then
   echo "===== Host Starting ====="
   HOSTNAME="$1"
else
    echo "Usage: $0 hostname" && exit 1
fi

# both linux & windows OS answers ping/ssh/...
#  nc -v -z -w 1 <hostname> 3389
# echo $? => 0=windows 
# port 3389 = ms-wbt-server

grep -w "\"$HOSTNAME\"" /net/ens/cremi_salle.json &> /dev/null
[ ! $? -eq 0 ] && echo "Error: hostname not found!" && exit 1

ping -c 1 $HOSTNAME &> /dev/null
[ $? -eq 0 ] && echo "Success: host $HOSTNAME already alive!" && exit 0

echo "Waking up $HOSTNAME, be patient. It can take few minutes..."
wget -q --no-check-certificate  -O - "https://startup.emi.u-bordeaux.fr/wol?h[]=$HOSTNAME" &> /dev/null
[ ! $? -eq 0 ] && echo "Error: wake on lan..." && exit 1

while : ; do
    echo -n "*"
    ping -c 1 $HOSTNAME &> /dev/null
    [ $? -eq 0 ] && echo && echo "Success: host $HOSTNAME started in $SECONDS seconds!" && break
done

# load / users...
# ssh -o "StrictHostKeyChecking=no" $HOSTNAME loginctl

echo "done!"
# EOF
