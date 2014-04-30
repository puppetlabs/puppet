# Python helper script to query for the packages that have
# pending updates. Called by the yum package provider
#
# (C) 2007 Red Hat Inc.
# David Lutterkort <dlutter @redhat.com>

import sys
import string
import time

# Try to use the yum libraries by default, which may fail if they are not
# present (i.e. yum <= 2.0 on RHEL3 and earlier).
import yum

OVERRIDE_OPTS = {
    'debuglevel': 0,
    'errorlevel': 0,
    'logfile': '/dev/null'
}

def pkg_lists(my):
    my.doConfigSetup()

    for k in OVERRIDE_OPTS.keys():
        if hasattr(my.conf, k):
            setattr(my.conf, k, OVERRIDE_OPTS[k])
        else:
            my.conf.setConfigOption(k, OVERRIDE_OPTS[k])

    my.doTsSetup()
    my.doRpmDBSetup()

    # Yum 2.2/2.3 python libraries require a couple of extra function calls to setup package sacks.
    # They also don't have a __version__ attribute
    try:
        yumver = yum.__version__
    except AttributeError:
        my.doRepoSetup()
        my.doSackSetup()

    return my.doPackageLists('updates')

try:
    my = yum.YumBase()

    try:
        # Acquire yum lock to prevent simultaneous DB access
        lock_count = 300  # 10 mins
        while True:
            if lock_count == 0:
                print "_err timed out acquiring lock"
                sys.exit(1)

            try:
                my.doLock()
            except yum.Errors.LockError, e:
                if e.errno:
                    print "_err LockError %d %s" % (e.errno, e)
                    sys.exit(1)
                else:
                    time.sleep(2)
                    lock_count = lock_count - 1
            else:
                break

        ypl = pkg_lists(my)
        for pkg in ypl.updates:
            print "_pkg %s %s %s %s %s" % (pkg.name, pkg.epoch, pkg.version, pkg.release, pkg.arch)
    finally:
        my.closeRpmDB()
        my.doUnlock()
except IOError, e:
    print "_err IOError %d %s" % (e.errno, e)
    sys.exit(1)
except AttributeError, e:
    # catch yumlib errors in buggy 2.x versions of yum
    print "_err AttributeError %s" % e
    sys.exit(1)

# vim: tabstop=4:softtabstop=4:shiftwidth=4:expandtab
