#!/usr/bin/env puppet
# Jeff McCune <mccune@math.ohio-state.edu>
#
# Apple's Automounter spawns a child that sends the parent
# a SIGTERM.  This makes it *very* difficult to figure out
# if the process started correctly or not.
#

service {"automount-test":
    provider => base,
    hasrestart => false,
    pattern => '/tmp/hometest',
    start => "/usr/sbin/automount -m /tmp/home /dev/null -mnt /tmp/hometest",
    stop => "ps auxww | grep '/tmp/hometest' | grep -v grep | awk '{print \$2}' | xargs kill",
    ensure => running
}
