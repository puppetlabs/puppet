# Continuous Testing

This directory contains configurations for continuous testing, using
either autotest (part of the ZenTest gem) or watchr (in the watchr
gem).  The purpose of these tools is to automatically run the
appropriate test when a file is changed or, if appropriate, all
tests.  In general, they do a straightforward mapping from a given
code file to its unit and/or integration test.

It is highly recommended that you have one of these running at all
times during development, as they provide immediate and continuous
feedback as to your development process.  There are some general
usability downsides as you have to track the running process, but
those downsides are easily worth it.

# How to use

To use autotest, install ZenTest and run it with no arguments
from the root of the puppet repository:

    $ autotest

It is currently only configured to run specs.

To use watchr, run it with the watchr file specified as its argument:

    $ watchr autotest/watcher.rb

Both will use growl if installed on a Mac, but watchr assumes the
presence of growl and will likely fail without it.  Autotest is a bit
more mature and should be resilient to either.

The primary reason to use to use watchr over autotest is that it uses
filesystem events to detect changes (theoretically portably although
only tested on OS X), thus eliminating the need for polling for
changes across all files being monitored.

# Gotchas

Autotest will start out by running all tests; if you don't want that,
stick a syntax error in one of the tests to force a failure, then fix
it and go on your merry way.

Watchr, on the other hand, will default to only running the files you
change.
