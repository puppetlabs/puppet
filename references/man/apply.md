---
layout: default
built_from_commit: 6893bdd69ab1291e6e6fcd6b152dda2b48e3cdb2
title: 'Man Page: puppet apply'
canonical: "/puppet/latest/man/apply.html"
---

# Man Page: puppet apply

> **NOTE:** This page was generated from the Puppet source code on 2024-10-17 02:36:47 +0000

NAME
====

**puppet-apply** - Apply Puppet manifests locally

SYNOPSIS
========

Applies a standalone Puppet manifest to the local system.

USAGE
=====

puppet apply \[-h\|\--help\] \[-V\|\--version\] \[-d\|\--debug\]
\[-v\|\--verbose\] \[-e\|\--execute\] \[\--detailed-exitcodes\]
\[-L\|\--loadclasses\] \[-l\|\--logdest syslog\|eventlog\|*ABS
FILEPATH*\|console\] \[\--noop\] \[\--catalog *catalog*\]
\[\--write-catalog-summary\] *file*

DESCRIPTION
===========

This is the standalone puppet execution tool; use it to apply individual
manifests.

When provided with a modulepath, via command line or config file, puppet
apply can effectively mimic the catalog that would be served by puppet
master with access to the same modules, although there are some subtle
differences. When combined with scheduling and an automated system for
pushing manifests, this can be used to implement a serverless Puppet
site.

Most users should use \'puppet agent\' and \'puppet master\' for
site-wide manifests.

OPTIONS
=======

Any setting that\'s valid in the configuration file is a valid long
argument for puppet apply. For example, \'tags\' is a valid setting, so
you can specify \'\--tags *class*,*tag*\' as an argument.

See the configuration file documentation at
https://puppet.com/docs/puppet/latest/configuration.html for the full
list of acceptable parameters. You can generate a commented list of all
configuration options by running puppet with \'\--genconfig\'.

-   \--debug: Enable full debugging.

-   \--detailed-exitcodes: Provide extra information about the run via
    exit codes. If enabled, \'puppet apply\' will use the following exit
    codes:

    0: The run succeeded with no changes or failures; the system was
    already in the desired state.

    1: The run failed.

    2: The run succeeded, and some resources were changed.

    4: The run succeeded, and some resources failed.

    6: The run succeeded, and included both changes and failures.

-   \--help: Print this help message

-   \--loadclasses: Load any stored classes. \'puppet agent\' caches
    configured classes (usually at /etc/puppetlabs/puppet/classes.txt),
    and setting this option causes all of those classes to be set in
    your puppet manifest.

-   \--logdest: Where to send log messages. Choose between \'syslog\'
    (the POSIX syslog service), \'eventlog\' (the Windows Event Log),
    \'console\', or the path to a log file. Defaults to \'console\'.
    Multiple destinations can be set using a comma separated list (eg:
    **/path/file1,console,/path/file2**)\"

    A path ending with \'.json\' will receive structured output in JSON
    format. The log file will not have an ending \'\]\' automatically
    written to it due to the appending nature of logging. It must be
    appended manually to make the content valid JSON.

    A path ending with \'.jsonl\' will receive structured output in JSON
    Lines format.

-   \--noop: Use \'noop\' mode where Puppet runs in a no-op or dry-run
    mode. This is useful for seeing what changes Puppet will make
    without actually executing the changes.

-   \--execute: Execute a specific piece of Puppet code

-   \--test: Enable the most common options used for testing. These are
    \'verbose\', \'detailed-exitcodes\' and \'show\_diff\'.

-   \--verbose: Print extra information.

-   \--catalog: Apply a JSON catalog (such as one generated with
    \'puppet master \--compile\'). You can either specify a JSON file or
    pipe in JSON from standard input.

-   \--write-catalog-summary After compiling the catalog saves the
    resource list and classes list to the node in the state directory
    named classes.txt and resources.txt

-   

EXAMPLE
=======


    $ puppet apply -e 'notify { "hello world": }'
    $ puppet apply -l /tmp/manifest.log manifest.pp
    $ puppet apply --modulepath=/root/dev/modules -e "include ntpd::server"
    $ puppet apply --catalog catalog.json

AUTHOR
======

Luke Kanies

COPYRIGHT
=========

Copyright (c) 2011 Puppet Inc., LLC Licensed under the Apache 2.0
License
