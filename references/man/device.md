---
layout: default
built_from_commit: 70303b65ae864066c583e1436011ff135847f6ad
title: 'Man Page: puppet device'
canonical: "/puppet/latest/man/device.html"
---

# Man Page: puppet device

> **NOTE:** This page was generated from the Puppet source code on 2024-08-29 17:41:46 -0700

## NAME
**puppet-device** - Manage remote network devices

## SYNOPSIS
Retrieves catalogs from the Puppet master and applies them to remote
devices.

This subcommand can be run manually; or periodically using cron, a
scheduled task, or a similar tool.

## USAGE
puppet device \[-h\|\--help\] \[-v\|\--verbose\] \[-d\|\--debug\]
\[-l\|\--logdest syslog\|*file*\|console\] \[\--detailed-exitcodes\]
\[\--deviceconfig *file*\] \[-w\|\--waitforcert *seconds*\] \[\--libdir
*directory*\] \[-a\|\--apply *file*\] \[-f\|\--facts\] \[-r\|\--resource
*type* \[name\]\] \[-t\|\--target *device*\] \[\--user=*user*\]
\[-V\|\--version\]

## DESCRIPTION
Devices require a proxy Puppet agent to request certificates, collect
facts, retrieve and apply catalogs, and store reports.

## USAGE NOTES
Devices managed by the puppet-device subcommand on a Puppet agent are
configured in device.conf, which is located at \$confdir/device.conf by
default, and is configurable with the \$deviceconfig setting.

The device.conf file is an INI-like file, with one section per device:

\[*DEVICE_CERTNAME*\] type *TYPE* url *URL* debug

The section name specifies the certname of the device.

The values for the type and url properties are specific to each type of
device.

The optional debug property specifies transport-level debugging, and is
limited to telnet and ssh transports.

See https://puppet.com/docs/puppet/latest/config_file_device.html for
details.

## OPTIONS
Note that any setting that\'s valid in the configuration file is also a
valid long argument. For example, \'server\' is a valid configuration
parameter, so you can specify \'\--server *servername*\' as an argument.

\--help, -h

:   Print this help message

\--verbose, -v

:   Turn on verbose reporting.

\--debug, -d

:   Enable full debugging.

\--logdest, -l

:   Where to send log messages. Choose between \'syslog\' (the POSIX
    syslog service), \'console\', or the path to a log file. If
    debugging or verbosity is enabled, this defaults to \'console\'.
    Otherwise, it defaults to \'syslog\'. Multiple destinations can be
    set using a comma separated list (eg:
    **/path/file1,console,/path/file2**)\"

    A path ending with \'.json\' will receive structured output in JSON
    format. The log file will not have an ending \'\]\' automatically
    written to it due to the appending nature of logging. It must be
    appended manually to make the content valid JSON.

\--detailed-exitcodes

:   Provide transaction information via exit codes. If this is enabled,
    an exit code of \'1\' means at least one device had a compile
    failure, an exit code of \'2\' means at least one device had
    resource changes, and an exit code of \'4\' means at least one
    device had resource failures. Exit codes of \'3\', \'5\', \'6\', or
    \'7\' means that a bitwise combination of the preceding exit codes
    happened.

\--deviceconfig

:   Path to the device config file for puppet device. Default:
    \$confdir/device.conf

\--waitforcert, -w

:   This option only matters for targets that do not yet have
    certificates and it is enabled by default, with a value of 120
    (seconds). This causes +puppet device+ to poll the server every 2
    minutes and ask it to sign a certificate request. This is useful for
    the initial setup of a target. You can turn off waiting for
    certificates by specifying a time of 0.

\--libdir

:   Override the per-device libdir with a local directory. Specifying a
    libdir also disables pluginsync. This is useful for testing.

    A path ending with \'.jsonl\' will receive structured output in JSON
    Lines format.

\--apply

:   Apply a manifest against a remote target. Target must be specified.

\--facts

:   Displays the facts of a remote target. Target must be specified.

\--resource

:   Displays a resource state as Puppet code, roughly equivalent to
    **puppet resource**. Can be filtered by title. Requires \--target be
    specified.

\--target

:   Target a specific device/certificate in the device.conf. Doing so
    will perform a device run against only that device/certificate.

\--to_yaml

:   Output found resources in yaml format, suitable to use with Hiera
    and create_resources.

\--user

:   The user to run as.

## EXAMPLE

      $ puppet device --target remotehost --verbose

## AUTHOR
Brice Figureau

## COPYRIGHT
Copyright (c) 2011-2018 Puppet Inc., LLC Licensed under the Apache 2.0
License
