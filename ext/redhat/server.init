#!/bin/bash
# puppetmaster  This shell script enables the puppetmaster server.
#
# Authors:       Duane Griffin <d.griffin@psenterprise.com>
#                Peter Meier <peter.meier@immerda.ch> (Mongrel enhancements)
#
# chkconfig: - 65 45
#
# description: Server for the puppet system management tool.
# processname: puppetmaster

PATH=/usr/bin:/sbin:/bin:/usr/sbin
export PATH

lockfile=/var/lock/subsys/puppetmaster
pidfile=/var/run/puppetlabs/master.pid

# Source function library.
. /etc/rc.d/init.d/functions

if [ -f /etc/sysconfig/puppetmaster ]; then
    . /etc/sysconfig/puppetmaster
fi

PUPPETMASTER_OPTS="master "
[ -n "$PUPPETMASTER_MANIFEST" ] && PUPPETMASTER_OPTS="${PUPPETMASTER_OPTS} --manifest=${PUPPETMASTER_MANIFEST}"
[ -n "$PUPPETMASTER_PORTS" ] && PUPPETMASTER_OPTS="${PUPPETMASTER_OPTS} --masterport=${PUPPETMASTER_PORTS[0]}"
[ -n "$PUPPETMASTER_LOG" ] && PUPPETMASTER_OPTS="${PUPPETMASTER_OPTS} --logdest ${PUPPETMASTER_LOG}"
PUPPETMASTER_OPTS="${PUPPETMASTER_OPTS} \
    ${PUPPETMASTER_EXTRA_OPTS}"

# Determine if we can use the -p option to daemon, killproc, and status.
# RHEL < 5 can't.
if status | grep -q -- '-p' 2>/dev/null; then
    daemonopts="--pidfile $pidfile"
    pidopts="-p $pidfile"
fi

mongrel_warning="The mongrel servertype is no longer built-in to Puppet. It appears
as though mongrel is being used, as the number of ports is greater than
one. Starting the puppetmaster service will not behave as expected until this
is resolved. Only the first port has been used in the service. These settings
are defined at /etc/sysconfig/puppetmaster"

# Warn about removed and unsupported mongrel servertype
if [ -n "$PUPPETMASTER_PORTS" ] && [ ${#PUPPETMASTER_PORTS[@]} -gt 1 ]; then
    echo $mongrel_warning
    echo
fi

RETVAL=0

PUPPETMASTER=/usr/bin/puppet

start() {
    echo -n $"Starting puppetmaster: "

    # Confirm the manifest exists
    if [ -r $PUPPETMASTER_MANIFEST ]; then
        daemon $daemonopts $PUPPETMASTER $PUPPETMASTER_OPTS
        RETVAL=$?
    else
        failure $"Manifest does not exist: $PUPPETMASTER_MANIFEST"
        echo
        return 1
    fi
    [ $RETVAL -eq 0 ] && touch "$lockfile"
    echo
    return $RETVAL
}

stop() {
    echo -n  $"Stopping puppetmaster: "
    killproc $pidopts $PUPPETMASTER
    RETVAL=$?
    echo
    [ $RETVAL -eq 0 ] && rm -f "$lockfile"
    return $RETVAL
}

restart() {
    stop
    start
}

genconfig() {
    echo -n $"Generate configuration puppetmaster: "
    $PUPPETMASTER $PUPPETMASTER_OPTS --genconfig
}

rh_status() {
    status $pidopts -l $lockfile $PUPPETMASTER
    RETVAL=$?
    return $RETVAL
}

rh_status_q() {
    rh_status >/dev/null 2>&1
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart|reload|force-reload)
        restart
        ;;
    condrestart)
        rh_status_q || exit 0
        restart
        ;;
    status)
        rh_status
        ;;
    genconfig)
        genconfig
        ;;
    *)
        echo $"Usage: $0 {start|stop|status|restart|reload|force-reload|condrestart|genconfig}"
        exit 1
esac

exit $RETVAL

# vim: tabstop=4:softtabstop=4:shiftwidth=4:expandtab
