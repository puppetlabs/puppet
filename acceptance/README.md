Local Use
=========

CI
---

There are two ways to run the ci tests locally: against packages, or against git clones.

`rake -T` will give short descriptions, and a `rake -D` will give full descriptions with information on ENV options required and optional for the various tasks.

### Authentication

Normally the ci tasks are called from a prepared Jenkins job.

If you are running this on your laptop, you will need this ssh private key in order for beaker to be able to log into the vms created from the hosts file:

https://github.com/puppetlabs/puppetlabs-modules/blob/qa/secure/jenkins/id_rsa-acceptance
https://github.com/puppetlabs/puppetlabs-modules/blob/qa/secure/jenkins/id_rsa-acceptance.pub

TODO fetch these files directly from github, but am running into rate limits and then would also have to cross the issue of authentication.

You will also need QA credentials to vsphere in a ~/.fog file.  These credentials can be found on any of the Jenkins coordinator hosts.

### Packages

In order to run the tests on hosts provisioned from packages produced by Delivery, you will need to reference a Puppet commit sha that has been packaged using Delivery's pl:jenkins:uber_build task.  This is the snippet used by 'Puppet Packaging' Jenkins jobs:

    rake --trace package:implode
    rake --trace package:bootstrap
    rake --trace pl:jenkins:uber_build

The above Rake tasks were run from the root of a Puppet checkout.  They are quoted just for reference.  Typically if you are investigating a failure, you will have a SHA from a failed jenkins run which should correspond to a successful pipeline run, and you should not need to run the pipeline manually.

A finished pipeline will have repository information available at http://builds.puppetlabs.lan/puppet/  So you can also browse this list and select a recent sha which has repo_configs/ available.

When executing the ci:test:packages task, you must set the SHA, and also set CONFIG to point to a valid Beaker hosts_file.  Configurations used in the Jenkins jobs are available under config/nodes

    bundle exec rake ci:test:packages SHA=abcdef CONFIG=config/nodes/rhel.yaml

Optionally you may set the TEST (TEST=a/test.rb,and/another/test.rb), and may pass additional OPTIONS to beaker (OPTIONS='--opt foo').

You may also edit a ./local_options.rb hash which will override config/ options, and in turn be oferriden by commandline options set in the environment variables CONFIG, TEST and OPTIONS.  This file is a ruby file containing a Ruby hash with configuration expected by Beaker.  See Beaker source, and examples in config/.

### Git

Alternatively you may provision via git clone by calling the ci:test:git task.  Currently we don't have packages for Windows or Solaris from the Delivery pipeline, and must use ci:test:git to privision and test these platforms.

### Preserving Hosts

If you have local changes to puppet code (outside of acceptance/) that you don't want to repackage for time reasons, or you just want to ssh into the hosts after a test run, you can use the following sequence:

    bundle exec rake ci:test_and_preserve_hosts CONFIG=some/config.yaml SHA=12345 TEST=a/foo_test.rb

to get the initial templates provisioned, and a local log/latest/preserve_config.yaml created for them.

Then you can log into the hosts, or rerun tests against them by:

    bundle exec rake ci:test_against_preserved_hosts TEST=a/foo_test.rb

This will use the existing hosts, uninstall and reinstall the puppet packages and rsync in any changes from your local source lib dir.  To skip reinstalling the packages set SKIP_PACKAGE_REINSTALL=1.  To skip rsyncing, set SKIP_RSYNC=1.  To use rsync filters, create a file with your rsync filter settings and set RSYNC_FILTER_FILE to the name of that file.  For example:

    include puppet
    include puppet/defaults.rb
    exclude *

will ensure that only puppet/defaults.rb is copied.

NOTE: By default these tasks provision with packages.  Set TYPE=git to use source checkouts.

### Cleaning Up Preserved Hosts

If you run a number of jobs with --preserve_hosts or vi ci:test_and_preserve_hosts, you may eventually generate a large number of stale vms.  They should be reaped automatically by qa infrastructure within a day or so, but you may also run:

    bundle exec ci:destroy_preserved_hosts

to clean them up sooner and free resources.
