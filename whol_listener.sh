#!/usr/bin/env ksh

#.---------------------------------------------
#              (W|H)all Of Lame
#                  Listener 
#
#,---------------------------------------------

DIR='/tmp'
FIFO='whol_pipe'
DSNIFF_FIFO='whol_dsniff_pipe'
QUIET=0
IFACE=0

# !! TODO !!
PREF=_l

DPREFIX=/tmp/whol_tdump$PREF

destruct() {
    if [[ "$STATUS" -gt 0 ]] ; then return; fi
    echo "exitting.."
    R=0
    STATUS=$((STATUS+1))
    rm $DIR/$FIFO$PREF
    [[ $DSNIFF ]] && rm $DIR/$DSNIFF_FIFO$PREF
    # TODO more sophisticated destruction..
    [[ $DSNIFF ]] && killall dsniff
}

usage() {
    echo -e "(W|H)all of lame - (C) 2010 Adam Tauber

    Usage:

        whol_listener -i interface <options>

    Options:

        -i, --interface      <str> : Wireless interface name
        -f, --filter         <str> : Pcap filter expression
        -r, --relevance    <float> : Filter output (default is 10)
        -w, --write-file     <str> : Write the original sniffed traffic to file (pcap format)
        -s, --session-str    <str> : A session string to the API of http://editgrid.com
        -t, --tmp-dest       <str> : Destination of the temporary files generated by tcpdump - it is useful
                                        when more than one whols running - default is /tmp/whol_tdump
        -d, --dsniff               : Use dsniff
        -q, --quiet                : Quiet mode (no visual output)
        -h, --help                 : Displays this
"
}

ARGS=`getopt -n whol_listener -u -l help,quiet,interface:,tmp-dest:,filter:,relevance:,session-str:,dsniff s:r:t:f:i:hqd $*`

[[ $? != 0 ]] && {
         usage
         exit 1
     }
set -- $ARGS
for i
do
  case "$i" in
        -q|--quiet            ) shift; QUIET=1;;
        -i|--interface        ) shift; IFACE=$1; shift;;
        -f|--filter           ) shift; FILTER=$1; shift;;
        -t|--tmp-dest         ) shift; DPREFIX=$1$PREF; shift;;
        -d|--dsniff           ) shift; DSNIFF=1;;
        -r|--relevance        ) shift; RELEVANCE='-r '$1; shift;;
        -s|--session-str      ) shift; SESSION='-s '$1; shift;;
        -h|--help             ) shift; usage; exit 1;;
  esac
done

[[ $IFACE == 0 ]] && {
    echo '[!] Wrong wireless channel'
    usage
    exit 1
}

trap "destruct" INT

#ettercap -T -d -m ettertest.log -r $FIFO

[[ $DSNIFF ]] && mkfifo $DIR/$DSNIFF_FIFO$PREF && dsniff -m -p $DIR/$DSNIFF_FIFO$PREF &

tcpdump -i $IFACE -C 1 -w $DPREFIX&

TC=1
R=1
rm $DPREFIX*
FILTERPREF=$(./tshark_parser.py -f)
while [ $R == 1 ] ; do 
    [[ ! -f "$DPREFIX$TC" ]] && { sleep 1; continue; }
    if [[ $TC -eq 1 ]]; then
        F=$DPREFIX
    else
        F=$DPREFIX$(( TC-1 ))
    fi
    [[ -f $F ]] && {
    tshark -r $F -R \
        "$FILTERPREF $([[ $FILTER ]] && echo -n ' and ('$FILTER')')" \
            -T pdml 2>/dev/null && rm $F
    }
    TC=$(( $TC+1 ))
done | ./tshark_parser.py $RELEVANCE $SESSION

R=0
destruct $APID


