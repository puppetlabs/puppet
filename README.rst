Puppet
======

Puppet, an automated administrative engine for your Linux and Unix systems, performs
administrative tasks (such as adding users, installing packages, and updating server
configurations) based on a centralized specification.

Documentation (and detailed install instructions) can be found online at the 
`Puppet Documentation`_ site.

Additional documentation can also be found at the `Puppet Wiki`_.

Installation
------------

Generally, you need the following things installed:

* Ruby >= 1.8.1 (earlier releases might work but probably not)

* The Ruby OpenSSL library.  For some reason, this often isn't included
  in the main ruby distributions.  You can test for it by running
  'ruby -ropenssl -e "puts :yep"'.  If that errors out, you're missing the
  library.

  If your distribution doesn't come with the necessary library (e.g., on Debian
  and Ubuntu you need to install libopenssl-ruby), then you'll probably have to
  compile Ruby yourself, since it's part of the standard library and not
  available separately.  You could probably just compile and install that one
  library, though.

* The Ruby XMLRPC client and server libraries.  For some reason, this often
  isn't included in the main ruby distributions.  You can test for it by
  running 'ruby -rxmlrpc/client -e "puts :yep"'.  If that errors out, you're missing
  the library.

* Facter => 1.5.1
  You can get this from your package management system or the `Facter site`_

.. _Puppet Documentation: http://docs.puppetlabs.com
.. _Puppet Wiki: http://projects.puppetlabs.com/projects/puppet/wiki/
.. _Facter site: http://puppetlabs.com/projects/facter
