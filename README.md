Puppet
======

Puppet, an automated administrative engine for your Linux and Unix systems, performs
administrative tasks (such as adding users, installing packages, and updating server
configurations) based on a centralized specification.

Documentation (and detailed installation instructions) can be found online at the
[Puppet Docs site](http://docs.puppetlabs.com).

Installation
------------

Generally, you need the following things installed:

* A supported Ruby version. Ruby 1.8.5, 1.8.7, and 1.9.2 are fully supported
  (with a handful of known issues under 1.9.2); Ruby 1.8.1 is supported on a
  best-effort basis for agent use only. Other versions of Ruby are used at your
  own risk, and Ruby 1.8.6, 1.9.0, and 1.9.1 are not recommended for
  compatibility reasons.

* The Ruby OpenSSL library.  For some reason, this often isn't included
  in the main ruby distributions.  You can test for it by running
  'ruby -ropenssl -e "puts :yep"'.  If that errors out, you're missing the
  library.

  If your distribution doesn't come with the necessary library (e.g., on Debian
  and Ubuntu you need to install libopenssl-ruby), then you'll probably have to
  compile Ruby yourself, since it's part of the standard library and not
  available separately.  You could probably just compile and install that one
  library, though.

* Facter => 1.5.1 (available via your package manager or from the [Facter site](http://puppetlabs.com/projects/facter).

License
-------

See LICENSE file.

Support
-------

Please log tickets and issues at our [Projects site](http://projects.puppetlabs.com)
