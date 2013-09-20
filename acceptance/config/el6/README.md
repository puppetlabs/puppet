Local Use
=========

Both Modes
----------

### Options

There are two ways to set options.

./local_options.rb may be created with a Ruby hash of systest options which will override any of the options set in ./config/{local,jenkins}/options.rb.

To quickly add options to a run include an OPTIONS='--opt foo' env variable in your rake call.

### Tests

By default all tests are run.  You may set the TEST env variable to specify a subset.

Jenkins
-------

ci:test is principally for running in Jenkins, but can also be used locally if a SHA from a finished build pipeline (http://builds.puppetlabs.lan/puppet/) and a Beaker config file is provided (config/jenkins/\*.yaml).

    bundle exec rake ci:test OPTIONS='--config config/jenkins/lucid.yaml' SHA=12345

If you have local changes to puppet code (outside of acceptance/) that you don't want to repackage for time reasons, or you just want to ssh into the hosts after a test run, you can use the following sequence:

    bundle exec rake ci:test_and_preserve_hosts OPTIONS='--config config/jenkins/lucid.yaml' SHA=12345

to get the initial templates provisioned, and a local preserve_config.yaml created for them.

Then you can rerun tests against these host by:

    bundle exec rake ci:test_against_preserved_hosts

which will use the existing hosts, and rsync in any changes from your local source lib dir.

TODO: (Currently only set up for Debian; should be trivial to extend for Redhat.)

### Authentication

Normally this mode is only called from a prepared Jenkins job.

If running this on your laptop, you will need this ssh private key in order for systest to be able to log into the vms created in the config.yaml:

https://github.com/puppetlabs/puppetlabs-modules/blob/qa/secure/jenkins/id_rsa-acceptance
https://github.com/puppetlabs/puppetlabs-modules/blob/qa/secure/jenkins/id_rsa-acceptance.pub

TODO fetch these files directly from github, but am running into rate limits and then would also have to cross the issue of authentication.

Standalone
----------

The standalone tests use vagrant, but have decayed some and probably need to be cleaned up.  There biggest utility would be running the acceptance suite without access to our internal VSphere, and running it against hosts available in vagrant but not as vcloud templates.  It relies on git clone and install.rb installation.

The standalone tests currently run against this configuration config/local/config.yaml.  They use your local repository as the source for puppet installation, so changes you make are reflected in the next run.  This allows you to debug and write acceptance tests quickly, and even write a failing acceptance test and then explore code changes to fulfill it.

    be rake standalone:test

TODO use Adrien's vagrant-hosts and vagrant-auto_network to handle the host/ip configuration which is currently hard set.
