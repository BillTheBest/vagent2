#!/bin/bash

. util.sh
SRCDIR=${SRCDIR:-"."}
VARNISH_PID=$TMPDIR/varnish.pid
varnishd -f "${SRCDIR}/data/boot.vcl" \
    -P "$VARNISH_PID" \
    -n "$TMPDIR" \
    -p auto_restart=off \
    -a 127.0.0.1:8090 \
    -s malloc,50m

varnishpid="$(cat "$VARNISH_PID")"


echo PORT: $VARNISH_PORT
echo pid: $varnishpid
echo DIR: $TMPDIR

VARNISH_PORT=8090
AGENT_PORT=$(( 1024 + ( $RANDOM % 48000 ) ))
../src/varnish-agent -n ${TMPDIR} -p ${TMPDIR} -P ${TMPDIR}/agent.pid -c "$AGENT_PORT"

NOSTATUS=1
export VARNISH_PORT AGENT_PORT NOSTATUS
echo "Bad varnish, echo:"
./echo.sh
ret=$(( ${ret} + $? ))
echo "Bad varnish log:"
./log.sh
ret=$(( ${ret} + $? ))
echo "Bad varnish stats/log: "
test_json stats
test_json log/100/RxURL

OUT=$(lwp-request -m GET http://localhost:$AGENT_PORT/stats | grep uptime)
kill $varnishpid

varnishd -f "${SRCDIR}/data/boot.vcl" \
    -P "$VARNISH_PID" \
    -n "$TMPDIR" \
    -p auto_restart=off \
    -a 127.0.0.1:8090 \
    -s malloc,50m

varnishpid="$(cat "$VARNISH_PID")"

sleep 5

echo "new pid: $varnishpid"

echo "Bad varnish 2, echo:"
./echo.sh
ret=$(( ${ret} + $? ))

echo "Bad varnish2, stats:"

test_json stats

OUT2=$(lwp-request -m GET http://localhost:$AGENT_PORT/stats | grep uptime)

if [ "x$?" != "x0" ]; then fail; else pass; fi
inc
if [ "x$OUT" != "x$OUT2" ]; then pass; else fail; fi
inc

rm $TMPDIR/_.vsm
kill $(cat ${TMPDIR}/agent.pid)
sleep 1
../src/varnish-agent -n ${TMPDIR} -p ${TMPDIR} -P ${TMPDIR}/agent.pid -c "$AGENT_PORT"
sleep 2
echo "Echo test 3:"
./echo.sh
ret=$(( ${ret} + $? ))
echo "Testing shmlogfailure:"
test_it_fail GET stats "" "Couldn't open shmlog"
echo "Testing survival (echo test 4):"
./echo.sh
ret=$(( ${ret} + $? ))
kill $varnishpid
kill $(cat ${TMPDIR}/agent.pid)
exit $ret
