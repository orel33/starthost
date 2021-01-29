#!/bin/bash

HOSTFILE="./hosts.json"

trap ctrl_c INT
function ctrl_c() { echo "Abort!" && kill -9 $$ ; }

# Pour lister l'état de toutes les machines avec Nagios3
# https://services.emi.u-bordeaux.fr/nagios3/cgi-bin/status.cgi?hostgroup=all

# ROOM105="alia bellonda corba dama feydrautha ghanima halleck idaho lucila murbella noree odrade scytale sheeana stilgar talamane taraza tegs tuek usul"
# ROOM204="botero buffet cassatt escher goya kandinsky lautrec legreco marquet morissot opalka redon rembrandt seurat signac tissot velasquez vlaminck watteau whistler"
# ROOM008="beetlejuice braque cezanne chagall corot dali degas ernst gauguin leger leonardo magritte matisse millet miro modigliani monet pissarro renoir vangogh"

# parse JSON file to get all hosts in a room
function getRoom()
{
    local ROOM="$1"
    local HOSTS=$(jq -r ".SALLES[\"$ROOM\"] | .[]" < $HOSTFILE)
    local RET=$?
    ( IFS=$' ' ; echo "$HOSTS" )
    return $RET
}

# ROOM101=$(getRoom "101")
# ROOM104=$(getRoom "104")
# CREMI="$ROOM104"
# HOSTS="$HOST"

MODE="PING"
HOSTS=""

function usage() {
    echo "Usage: ..."
}

function getargs() {
    while getopts "pt:r:h" OPT; do
        case $OPT in
            p)
                MODE="PING"
            ;;
            b)
                MODE="BOOT"
            ;;
            t)
                HOSTS+=" $OPTARG"
            ;;
            r)
                local ROOM="$OPTARG"
                HOSTS+=$(getRoom "$ROOM")
            ;;
            h)
                usage
            ;;
            \?)
                echo "Invalid option!"
                usage
            ;;
        esac
    done

    echo "Hosts: $HOSTS"

    # check args
    if [ $# -eq 0 ] ; then usage ; fi
    if [ -z "$MODE" ] ; then usage ; fi

}

#################### PING MODE ####################

function mping() {
    echo "===== Host Monitoring ====="
    local HOSTS="$1"
    echo "ping..."
    fping "$HOSTS"
    return 0
}

#################### BOOT MODE ####################

function mboot() {
    echo "===== Host Starting ====="
    local HOSTNAME="$1"
    grep -w "\"$HOSTNAME\"" hosts.json &> /dev/null
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

}

#################### LOAD ####################

# load / users...
# ssh -o "StrictHostKeyChecking=no" $HOSTNAME loginctl

#################### MAIN ####################

getargs

[ "$MODE" = "ping" ] && mping "$HOSTS"
[ "$MODE" = "boot" ] && mboot "$HOSTS"

echo "done!"

# EOF
