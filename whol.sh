#!/usr/bin/env ksh

#.---------------------------------------------
#              (W|H)all Of Lame
#
#,---------------------------------------------

IFACE='wlan0'
DIR='/tmp'
FIFO='whol_pipe'
DSNIFF_FIFO='whol_dsniff_pipe'
QUIET=0
CHANNEL=0


destruct() {
    if [[ "$STATUS" -gt 0 ]] ; then return; fi
    echo "exitting.."
    R=0
    STATUS=$((STATUS+1))
    if [[ "$1" != "" ]] ; then kill $1; fi
    airmon-ng stop mon0
    rm $DIR/$FIFO
    [[ $DSNIFF ]] && rm $DIR/$DSNIFF_FIFO
    # TODO more sophisticated destruction..
    [[ $DSNIFF ]] && killall dsniff
}

usage() {
    echo -e "(W|H)all of lame - (C) 2010 Adam Tauber

    Usage:

        whol -c [wireless channel] <options>

    Options:

        -c, --channel        <int> : Channel of open wifi networks
        -i, --interface      <str> : Wireless interface name
        -f, --filter         <str> : Pcap filter expression
        -w, --write-file     <str> : Write the original traffic to file (pcap format)
        -h, --help                 : Displays this usage screen
        -d, --dsniff               : Use dsniff
        -q, --quiet                : Quiet mode (no visual output)
"
}

ARGS=`getopt -n whol -u -l channel:,help,quiet,interface:,write-file:,filter:,dsniff c:f:i:w:hqd $*`
[[ $? != 0 ]] && {
         usage
         exit 1
     }
set -- $ARGS
for i
do
  case "$i" in
        -c|--channel          ) shift; CHANNEL=$1; shift;;
        -q|--quiet            ) shift; QUIET=1;;
        -i|--interface        ) shift; IFACE=$1; shift;;
        -f|--filter           ) shift; FILTER=$1; shift;;
        -w|--write-file       ) shift; W_FILE=$1; shift;;
        -d|--dsniff           ) shift; DSNIFF=1;;
        -h|--help             ) shift; usage; exit 1;;
  esac
done

[[ $CHANNEL == 0 ]] && {
    echo '[!] Wrong wireless channel'
    usage
    exit 1
}

mkfifo $DIR/$FIFO
airmon-ng start $IFACE 0 $( if [ $QUIET -eq 1 ] ; then echo ' >/dev/null'; fi)

airodump-ng_wholmod -o pcap -w $DIR/$FIFO -t OPN -c $CHANNEL mon0 -p -q&
APID=$!

trap "destruct $APID" INT

#ettercap -T -d -m ettertest.log -r $FIFO

[[ $DSNIFF ]] && mkfifo $DIR/$DSNIFF_FIFO
[[ $DSNIFF ]] && dsniff -m -p $DIR/$DSNIFF_FIFO &
R=1
(cat $DIR/$FIFO |\
    tee $([[ $DSNIFF ]] && echo -n $DIR/$DSNIFF_FIFO) $W_FILE | \
        while [ $R == 1 ] ; do tshark -i - -c 100000 -R \
            "$(./tshark_parser.py -f) $([[ $FILTER ]] && echo -n ' and ('$FILTER')')" \
              -T pdml ; echo $R; done 2>/dev/null | \
                  ./tshark_parser.py)

R=0
destruct $APID
