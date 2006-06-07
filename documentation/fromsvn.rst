Puppet is currently implemented in Ruby and uses standard Ruby libraries. You should be able to run Puppet on any Unix-style host with Ruby.  Windows support is planned but not currently available.

Before you Begin
----------------

Make sure your host has Ruby version 1.8.2::

  $ ruby -v

Make sure you have Subverion::

    $ svn --version -q

Get the Source
--------------

Puppet currently relies on another ReductiveLabs tool, Facter. Create a working
directory and download them both::

    $ SETUP_DIR=~/svn
    $ mkdir -p $SETUP_DIR
    $ cd $SETUP_DIR
    $ svn checkout https://reductivelabs.com/svn/facter
    $ svn checkout https://reductivelabs.com/svn/puppet


Make it Available
-----------------

Last, we need to put the puppet binaries into our path and make the Puppet and
Facter libraries available to Ruby::

    $ PATH=$PATH:$SETUP_DIR/facter/bin:$SETUP_DIR/puppet/trunk/bin
    $ RUBYLIB=$SETUP_DIR/facter/lib:$SETUP_DIR/puppet/trunk/lib
    $ export PATH RUBYLIB

Facter changes far less often than Puppet and it is very minimal (a single
library file and a single executable), so it is probably worth just installing
it::

    $ cd facter/trunk
    $ sudo ruby ./install.rb

Test it Works
-------------
Now you can test that it is working.  The best way to do that is described in
the testing_ guide, and involves writing a short site manifest.  Another
option is to run through all of the unit tests that ship with Puppet::

    $ cd $SETUP_DIR/puppet/trunk/test
    $ ./test

This tends to take a long time, however, and is probably only useful if you
already know there's a problem and want to report a bug or if you are planning
on doing development.  It is worth noting that some of these tests necessarily
modify your system, so unless you know what you are doing, **it is unadvisable
to run them as root**, and certainly not on a production system.

Help with Installing
--------------------
You can build your first Puppet script by using this Simple Example_.

You can see more documentation about installation of Puppet and its
prerequisites by looking at Bootstrap-Install_ guide.


More documentation
------------------

You can learn more about Puppet by reading the Documentation_.

.. _Documentation: /projects/puppet/documentation/

.. _Example: https://reductivelabs.com/svn/manifests/project-www/README-www.rst

.. _Bootstrap-Install: https://reductivelabs.com/svn/manifests/project-test/bootstrap-install.rst

.. _testing: testing
