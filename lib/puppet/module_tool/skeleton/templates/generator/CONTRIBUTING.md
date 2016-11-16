This module has grown over time based on a range of contributions from
people using it. If you follow these contributing guidelines your patch
will likely make it into a release a little quicker.


## Contributing

1. Fork the repo.

2. Run the tests. We only take pull requests with passing tests, and
   it's great to know that you have a clean slate.

3. Add a test for your change. Only refactoring and documentation
   changes require no new tests. If you are adding functionality
   or fixing a bug, please add a test.

4. Make the test pass.

5. Push to your fork and submit a pull request.


## Dependencies

The testing and development tools have a bunch of dependencies,
all managed by [Bundler](http://bundler.io/) according to the
[Puppet support matrix](http://docs.puppetlabs.com/guides/platforms.html#ruby-versions).

By default the tests use a baseline version of Puppet.

If you have Ruby 2.x or want a specific version of Puppet,
you must set an environment variable such as:

    export PUPPET_VERSION="~> 3.2.0"

Install the dependencies like so...

    bundle install

## Syntax and style

The test suite will run [Puppet Lint](http://puppet-lint.com/) and
[Puppet Syntax](https://github.com/gds-operations/puppet-syntax) to
check various syntax and style things. You can run these locally with:

    bundle exec rake lint
    bundle exec rake syntax

## Running the unit tests

The unit test suite covers most of the code, as mentioned above please
add tests if you're adding new functionality. If you've not used
[rspec-puppet](http://rspec-puppet.com/) before then feel free to ask
about how best to test your new feature. Running the test suite is done
with:

    bundle exec rake spec

Note also you can run the syntax, style and unit tests in one go with:

    bundle exec rake test

### Automatically run the tests

During development of your puppet module you might want to run your unit
tests a couple of times. You can use the following command to automate
running the unit tests on every change made in the manifests folder.

    bundle exec guard

## Integration tests

The unit tests just check the code runs, not that it does exactly what
we want on a real machine. For that we're using
[Beaker](https://github.com/puppetlabs/beaker).

Beaker fires up a new virtual machine (using Vagrant) and runs a series of
simple tests against it after applying the module. You can run our
Beaker tests with:

    bundle exec rake acceptance

This will use the host described in `spec/acceptance/nodeset/default.yml`
by default. To run against another host, set the `BEAKER_set` environment
variable to the name of a host described by a `.yml` file in the
`nodeset` directory. For example, to run against CentOS 6.4:

    BEAKER_set=centos-64-x64 bundle exec rake acceptance

If you don't want to have to recreate the virtual machine every time you
can use `BEAKER_destroy=no` and `BEAKER_provision=no`. On the first run you will
at least need `BEAKER_provision` set to yes (the default). The Vagrantfile
for the created virtual machines will be in `.vagrant/beaker_vagrant_files`.
