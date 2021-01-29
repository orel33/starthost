#!/bin/bash

HOSTFILE="./hosts.json"

trap ctrl_c INT
function ctrl_c() { echo "Abort!" && kill -9 $$ ; }

# Pour lister l'état de toutes les machines avec Nagios3
# https://services.emi.u-bordeaux.fr/nagios3/cgi-bin/status.cgi?hostgroup=all

#################### HOST ROOM ####################

WATCH=0
MODE="PING"
HOSTS=""

function usage() {
    echo "Usage: $0 [options] host [...]" 
    echo "-p : ping mode (default)"
    echo "-b : boot mode"
    echo "-r <room> : room number (007, 101, 102, ...)"
    echo "-w : watch"
    return 0
}

#################### HOST ROOM ####################

# parse JSON file to get all hosts in a room
function getRoom()
{
    local ROOM="$1"
    local HOSTS=$(jq -r ".SALLES[\"$ROOM\"] | .[]" < $HOSTFILE)
    local RET=$?
    ( IFS=$' ' ; echo "$HOSTS" )
    return $RET
}

#################### PARSE ARGS ####################

function parseArgs() {
    while getopts "wbpr:h" OPT; do
        case $OPT in
            p ) MODE="PING" ;;
            b ) MODE="BOOT" ;;
	    w ) WATCH=1 ;;
	    r ) HOSTS+=$(getRoom "$OPTARG") ;;
            h ) usage && exit 0 ;;
            * ) usage && exit 1 ;;
        esac
    done

    shift $((OPTIND-1))
    # echo "$# other args: $*"

    # [ ! $# -ge 1 ] && usage && exit 1 
    HOSTS=$(echo "$HOSTS $*" | xargs)
    echo "Target Hosts: \"$HOSTS\""
    [ -z "$HOSTS" ] && echo "Error: no target hosts!" && usage && exit 1
    # [ ! $# -ge 1 ] && usage && exit 1 

    
    return 0
}

# The difference between $* and $@ comes in how they are expanded.
# 1) $* expands to a single argument with all the elements delimited
# by spaces (actually the first character of $IFS).
# 2) $@ expands to multiple arguments.

#################### PING MODE ####################

function mping() {
    echo "===== Ping Hosts ====="
    local HOSTS="$*"
    # echo "Target Hosts: $HOSTS"
    echo "Ping..."
    fping $HOSTS
    return 0
}

#################### BOOT MODE ####################

function mboot() {
    echo "===== Boot Hosts ====="
    local HOSTS="$*"

    for HOST in $HOSTS ; do

	# check
	# grep -w "\"$HOSTNAME\"" hosts.json &> /dev/null
	# [ ! $? -eq 0 ] && echo "Error: hostname not found!" && exit 1
    
	# ping -c 1 $HOSTNAME &> /dev/null
	# [ $? -eq 0 ] && echo "Success: host $HOSTNAME already alive!"

	echo "Waking up $HOST, be patient. It can take few minutes..."
	wget -q --no-check-certificate  -O - "https://startup.emi.u-bordeaux.fr/wol?h[]=$HOSTNAME" &> /dev/null &
	# [ ! $? -eq 0 ] && echo "Error: wake on lan..." && exit 1

	# while : ; do
        #     echo -n "*"
        #     ping -c 1 $HOSTNAME &> /dev/null
        #     [ $? -eq 0 ] && echo && echo "Success: host $HOSTNAME started in $SECONDS seconds!" && break
	# done

    done

    return 0
}

#################### MISC ####################

# load / users...
# ssh -o "StrictHostKeyChecking=no" $HOSTNAME loginctl

# test windows !!!
#  nmap -PN -n -6 cezanne
# => les ports 139 et 445 sont ouverts, le poste est sous windows


#################### MAIN ####################

parseArgs $* # || exit 1
echo "Mode: $MODE"

[ "$MODE" = "PING" ] && mping $HOSTS
[ "$MODE" = "BOOT" ] && mboot $HOSTS

echo "done!"

# EOF
