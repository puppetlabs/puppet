# Quick Start to Developing on Puppet

Before diving into the code, you should first take the time to make sure you
have an environment where you can run puppet as a developer. In a nutshell you
need: the puppet codebase, ruby versions, and dependencies. Once you've got all
of that in place you can make sure that you have a working development system
by running the puppet spec tests.

## The Puppet Codebase

In order to contribute to puppet you'll need to have a github account. Once you
have your account, fork the puppetlabs/puppet repo, and clone it onto your
local machine. The [github docs have a good
explanation](https://help.github.com/articles/fork-a-repo) of how to do all of
this.

## Ruby versions

Puppet needs to work across a variety of ruby versions. At a minimum you need
to try any changes you make on both ruby 1.8.7 and ruby 1.9.3. Ruby 2.0.0 and
2.1.0 are also supported, but they have small enough differences from 1.9.3
that they are not as important to always check while developing.

Popular ways of making sure you have access to the various versions of ruby are
to use either [rbenv](https://github.com/sstephenson/rbenv) or
[rvm](http://rvm.io/). You can read up on the linked sites for how to get them
installed on your system.

## Dependencies

Make sure you have [bundler](http://bundler.io/) installed. This should be as
simple as:

    $ gem install bundler

Now you can get all of the dependencies using:

    $ bundle install --path .bundle/gems/

Once this is done, you can interact with puppet through bundler using `bundle
exec <command>` which will ensure that `<command>` is executed in the context
of puppet's dependencies.

For example to run the specs:

    $ bundle exec rake spec

To run puppet itself (for a resource lookup say):

    $ bundle exec puppet resource host localhost

## Running Spec Tests

Puppet Labs projects use a common convention of using Rake to run unit tests.
The tests can be run with the following rake task:

    bundle exec rake spec

To run a single file's worth of tests (much faster!), give the filename:

    bundle exec rake spec TEST=spec/unit/ssl/host_spec.rb
