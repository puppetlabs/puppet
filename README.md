Puppet
======

[![Travis Status](https://travis-ci.org/puppetlabs/puppet.svg?branch=master)](https://travis-ci.org/puppetlabs/puppet)
[![Appveyor Status](https://ci.appveyor.com/api/projects/status/cvhpypd4504sevqq/branch/master?svg=true)](https://ci.appveyor.com/project/puppetlabs/puppet/branch/master)
[![Gem Version](https://badge.fury.io/rb/puppet.svg)](https://badge.fury.io/rb/puppet)
[![Inline docs](https://inch-ci.org/github/puppetlabs/puppet.svg)](https://inch-ci.org/github/puppetlabs/puppet)

Puppet, an automated administrative engine for your Linux, Unix, and Windows systems, performs
administrative tasks (such as adding users, installing packages, and updating server
configurations) based on a centralized specification.

Documentation
-------------

Documentation for Puppet and related projects can be found online at the
[Puppet Docs site](https://puppet.com/docs).

HTTP API
--------
[HTTP API Index](https://puppet.com/docs/puppet/5.4/http_api/http_api_index.html)

Installation
------------

The best way to run Puppet is with [Puppet Enterprise (PE)](https://puppet.com/puppet/puppet-enterprise),
which also includes orchestration features, a web console, and professional support.
The PE documentation is [available here.](https://puppet.com/docs/pe/latest)

To install an open source release of Puppet,
[see the installation guide on the docs site.](http://puppet.com/docs/puppet/5.4/install_pre.html)

If you need to run Puppet from source as a tester or developer,
see the [Running Puppet from Source](https://docs.puppet.com/puppet/3.8/from_source.html) guide on the docs site.

Developing and Contributing
------

We'd love to get contributions from you! For a quick guide to getting your
system setup for developing, take a look at our [Quickstart
Guide](https://github.com/puppetlabs/puppet/blob/master/docs/quickstart.md). Once you are up and running, take a look at the
[Contribution Documents](https://github.com/puppetlabs/puppet/blob/master/CONTRIBUTING.md) to see how to get your changes merged
in.

For more complete docs on developing with Puppet, take a look at the
rest of the [developer documents](https://github.com/puppetlabs/puppet/blob/master/docs/index.md).

License
-------

See [LICENSE](https://github.com/puppetlabs/puppet/blob/master/LICENSE) file.

Support
-------

Please log tickets and issues at our [JIRA tracker](https://tickets.puppetlabs.com).  A [mailing
list](https://groups.google.com/forum/?fromgroups#!forum/puppet-users) is
available for asking questions and getting help from others. In addition, there
is an active #puppet channel on Freenode.

We use semantic version numbers for our releases and recommend that users stay
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

[Puppet Enterprise Support Lifecycle](https://puppet.com/misc/puppet-enterprise-lifecycle)
