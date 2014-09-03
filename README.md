Puppet
======

[![Build Status](https://travis-ci.org/puppetlabs/puppet.png?branch=master)](https://travis-ci.org/puppetlabs/puppet)
[![Inline docs](http://inch-ci.org/github/puppetlabs/puppet.png)](http://inch-ci.org/github/puppetlabs/puppet)

Puppet, an automated administrative engine for your Linux, Unix, and Windows systems, performs
administrative tasks (such as adding users, installing packages, and updating server
configurations) based on a centralized specification.

Documentation
-------------

Documentation for Puppet and related projects can be found online at the
[Puppet Docs site](http://docs.puppetlabs.com).

HTTP API
--------
[HTTP API Index](api/docs/http_api_index.md)

Installation
------------

The best way to run Puppet is with [Puppet Enterprise](http://puppetlabs.com/puppet/puppet-enterprise),
which also includes orchestration features, a web console, and professional support.
[The PE documentation is available here.](http://docs.puppetlabs.com/pe/latest)

To install an open source release of Puppet,
[see the installation guide on the docs site.](http://docs.puppetlabs.com/guides/installation.html)

If you need to run Puppet from source as a tester or developer,
[see the running from source guide on the docs site.](http://docs.puppetlabs.com/guides/from_source.html)

Developing and Contributing
------

We'd love to get contributions from you! For a quick guide to getting your
system setup for developing take a look at our [Quickstart
Guide](docs/quickstart.md). Once you are up and running, take a look at the
[Contribution Documents](CONTRIBUTING.md) to see how to get your changes merged
in.

For more complete docs on developing with puppet you can take a look at the
rest of the [developer documents](docs/index.md).

License
-------

See [LICENSE](LICENSE) file.

Support
-------

Please log tickets and issues at our [JIRA tracker](http://tickets.puppetlabs.com).  A [mailing
list](https://groups.google.com/forum/?fromgroups#!forum/puppet-users) is
available for asking questions and getting help from others. In addition there
is an active #puppet channel on Freenode.

We use semantic version numbers for our releases, and recommend that users stay
as up-to-date as possible by upgrading to patch releases and minor releases as
they become available.

Bugfixes and ongoing development will occur in minor releases for the current
major version. Security fixes will be backported to a previous major version on
a best-effort basis, until the previous major version is no longer maintained.


For example: If a security vulnerability is discovered in Puppet 4.1.1, we
would fix it in the 4 series, most likely as 4.1.2. Maintainers would then make
a best effort to backport that fix onto the latest Puppet 3 release.

Long-term support, including security patches and bug fixes, is available for
commercial customers. Please see the following page for more details:

[Puppet Enterprise Support Lifecycle](http://puppetlabs.com/misc/puppet-enterprise-lifecycle)

