Autotest is a simple tool that automatically links tests with the files being
tested, and runs tests automatically when either the test or code has changed.

If you are running on a Mac and have growlnotify_ installed, install the
ZenTest_ gem, then copy the ``config`` file to ``~/.autotest`` (or just
run ``rake`` in this directory).

Once you have ``autotest`` installed, change to the root of your Puppet
git repository and run ``autotest`` with no arguments.  To refresh the list
of files to scan, hit ``^c`` (that is, control-c).

It's recommended you leave this running in another terminal during all
development, preferably on another monitor.

.. _zentest: http://www.zenspider.com/ZSS/Products/ZenTest/
.. _growlnotify: http://growl.info/extras.php
