Puppet
======

[![Build Status](https://travis-ci.org/puppetlabs/puppet.png?branch=master)](https://travis-ci.org/puppetlabs/puppet)

Puppet, an automated administrative engine for your Linux, Unix, and Windows systems, performs
administrative tasks (such as adding users, installing packages, and updating server
configurations) based on a centralized specification.

Documentation (and detailed installation instructions) can be found online at the
[Puppet Docs site](http://docs.puppetlabs.com).


Installation
------------

Generally, you need the following things installed:

* A supported Ruby version. Ruby 1.8.7, and 1.9.3 are fully supported.

* The Ruby OpenSSL library.  For some reason, this often isn't included
  in the main ruby distributions.  You can test for it by running
  `ruby -ropenssl -e "puts :yep"`.  If that errors out, you're missing the
  library.

  If your distribution doesn't come with the necessary library (e.g., on Debian
  and Ubuntu you need to install libopenssl-ruby), then you'll probably have to
  compile Ruby yourself, since it's part of the standard library and not
  available separately.  You could probably just compile and install that one
  library, though.

* Facter => 1.6.11 (available via your package manager or from the [Facter site](http://puppetlabs.com/projects/facter)).

Contributions
------
Please see our [Contibution
Documents](https://github.com/puppetlabs/puppet/blob/master/CONTRIBUTING.md)
and our [Developer
Documentation](https://github.com/puppetlabs/puppet/blob/master/README_DEVELOPER.md).

License
-------

See LICENSE file.

Support
-------

Please log tickets and issues at our [Projects
site](http://projects.puppetlabs.com). A [mailing
list](https://groups.google.com/forum/?fromgroups#!forum/puppet-users) is
available for asking questions and getting help from others. In addition there
is an active #puppet channel on Freenode.
