# Python helper script to query for the packages that have
# pending updates. Called by the yum package provider
#
# (C) 2007 Red Hat Inc.
# David Lutterkort <dlutter @redhat.com>

import sys
import string
import re

# this maintains compatibility with really old platforms with python 1.x
from os import popen, WEXITSTATUS

# Try to use the yum libraries by default, but shell out to the yum executable
# if they are not present (i.e. yum <= 2.0). This is only required for RHEL3
# and earlier that do not support later versions of Yum. Once RHEL3 is EOL,
# shell_out() and related code can be removed.
try:
    import yum
except ImportError:
    useyumlib = 0
else:
    useyumlib = 1

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

def shell_out():
    try:
        p = popen("/usr/bin/env yum check-update 2>&1")
        output = p.readlines()
        rc = p.close()

        if rc is not None:
            # None represents exit code of 0, otherwise the exit code is in the
            # format returned by wait(). Exit code of 100 from yum represents
            # updates available.
            if WEXITSTATUS(rc) != 100:
                return WEXITSTATUS(rc)
        else:
            # Exit code is None (0), no updates waiting so don't both parsing output
            return 0

        # Yum prints a line of hyphens (old versions) or a blank line between
        # headers and package data, so skip everything before them
        skipheaders = 0
        for line in output:
            if not skipheaders:
                if re.compile("^((-){80}|)$").search(line):
                    skipheaders = 1
                continue

            # Skip any blank lines
            if re.compile("^[ \t]*$").search(line):
                continue

            # Format is:
            # Yum 1.x: name arch (epoch:)?version
            # Yum 2.0: name arch (epoch:)?version repo
            # epoch is optional if 0

            p = string.split(line)
            pname = p[0]
            parch = p[1]
            pevr = p[2]

            # Separate out epoch:version-release
            evr_re = re.compile("^(\d:)?(\S+)-(\S+)$")
            evr = evr_re.match(pevr)

            pepoch = ""
            if evr.group(1) is None:
                pepoch = "0"
            else:
                pepoch = evr.group(1).replace(":", "")
            pversion = evr.group(2)
            prelease = evr.group(3)

            print "_pkg", pname, pepoch, pversion, prelease, parch

        return 0
    except:
        print sys.exc_info()[0]
        return 1

if useyumlib:
    try:
        try:
            my = yum.YumBase()
            ypl = pkg_lists(my)
            for pkg in ypl.updates:
                print "_pkg %s %s %s %s %s" % (pkg.name, pkg.epoch, pkg.version, pkg.release, pkg.arch)
        finally:
            my.closeRpmDB()
    except IOError, e:
        print "_err IOError %d %s" % (e.errno, e)
        sys.exit(1)
    except AttributeError, e:
        # catch yumlib errors in buggy 2.x versions of yum
        print "_err AttributeError %s" % e
        sys.exit(1)
else:
    rc = shell_out()
    sys.exit(rc)
