# Puppet

![RSpec tests](https://github.com/puppetlabs/puppet/workflows/RSpec%20tests/badge.svg)
[![Gem Version](https://badge.fury.io/rb/puppet.svg)](https://badge.fury.io/rb/puppet)
[![Inline docs](https://inch-ci.org/github/puppetlabs/puppet.svg)](https://inch-ci.org/github/puppetlabs/puppet)

Puppet, an automated administrative engine for your Linux, Unix, and Windows systems, performs
administrative tasks (such as adding users, installing packages, and updating server
configurations) based on a centralized specification.


## Documentation

Documentation for Puppet and related projects can be found online at the
[Puppet Docs site](https://puppet.com/docs).

### HTTP API

[HTTP API Index](https://puppet.com/docs/puppet/latest/http_api/http_api_index.html)

## Installation

The best way to run Puppet is with [Puppet Enterprise (PE)](https://puppet.com/products/puppet-enterprise/),
which also includes orchestration features, a web console, and professional support.
The PE documentation is [available here.](https://puppet.com/docs/pe/latest)

To install an open source release of Puppet,
[see the installation guide on the docs site.](https://puppet.com/docs/puppet/latest/installing_and_upgrading.html)

If you need to run Puppet from source as a tester or developer,
see the [Quick Start to Developing on Puppet](docs/quickstart.md) guide.

## Developing and Contributing

We'd love to get contributions from you! For a quick guide to getting your
system setup for developing, take a look at our [Quickstart
Guide](https://github.com/puppetlabs/puppet/blob/main/docs/quickstart.md). Once you are up and running, take a look at the
[Contribution Documents](https://github.com/puppetlabs/puppet/blob/main/CONTRIBUTING.md) to see how to get your changes merged
in.

For more complete docs on developing with Puppet, take a look at the
rest of the [developer documents](https://github.com/puppetlabs/puppet/blob/main/docs/index.md).

## Licensing

See [LICENSE](https://github.com/puppetlabs/puppet/blob/main/LICENSE) file. Puppet is licensed by Puppet, Inc. under the Apache license. Puppet, Inc. can be contacted at: info@puppet.com

## Support

Please log tickets and issues at our [JIRA tracker](https://tickets.puppetlabs.com). A [mailing
list](https://groups.google.com/forum/?fromgroups#!forum/puppet-users) is
available for asking questions and getting help from others, or if you prefer chat, we also have a [Puppet Community slack.](https://puppetcommunity.slack.com/)

We use semantic version numbers for our releases and recommend that users stay
as up-to-date as possible by upgrading to patch releases and minor releases as
they become available.

Bug fixes and ongoing development will occur in minor releases for the current
major version. Security fixes will be backported to a previous major version on
a best-effort basis, until the previous major version is no longer maintained.

For example: If a security vulnerability is discovered in Puppet 6.1.1, we
would fix it in the 6 series, most likely as 6.1.2. Maintainers would then make
a best effort to backport that fix onto the latest Puppet 5 release.

Long-term support, including security patches and bug fixes, is available for
commercial customers. Please see the following page for more details:

[Puppet Enterprise Support Lifecycle](https://puppet.com/docs/puppet-enterprise/product-support-lifecycle/)
