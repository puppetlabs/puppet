Running Acceptance Tests Yourself
=================================

Table of Contents
-----------------

* [General Notes](#general-notes)
* [Running Tests on the vcloud](#running-tests-on-the-vcloud)
* [Running Tests on Vagrant Boxen](#running-tests-on-vagrant-boxen)

General Notes
-------------

The rake tasks for running the tests are defined by the Rakefile in the acceptance test directory.
These tasks come with some documentation: `rake -T` will give short descriptions, and a `rake -D` will give full descriptions with information on ENV options required and optional for the various tasks.

If you are setting up a new repository for acceptance, you will need to bundle install first.  This step assumes you have ruby and the bundler gem installed.

```sh
cd /path/to/repo/acceptance
bundle install --path=.bundle/gems
```

### Using Git Mirrors

By default if you are installing from source, packages will be installed from Github, from their puppetlabs forks.  This can be selectively overridden for all installed projects, or per project, by setting environment variables.

GIT_SERVER => this will be the address the git server used for all installed projects.  Defaults to 'github.com'.
FORK => this will be the fork of the project for all installed projects.  Defaults to 'puppetlabs'.

To customize the server or fork for a specific project use PROJECT_NAME_GIT_SERVER and PROJECT_NAME_FORK.

For example, run with these options:

```sh
bundle exec rake ci:test:git CONFIG=config/nodes/win2008r2.yaml SHA=abcd PUPPET_GIT_SERVER=percival.corp.puppetlabs.net GIT_SERVER=github.delivery.puppetlabs.net
```

Beaker will install the following:

```
:install=>
  ["git://github.delivery.puppetlabs.net/puppetlabs-facter.git#stable",
   "git://github.delivery.puppetlabs.net/puppetlabs-hiera.git#stable",
   "git://percival.corp.puppetlabs.net/puppetlabs-puppet.git#abcd"],
```

This corresponds to installing facter and hiera stable from our internal mirror, while installing puppet SHA abcd from a git daemon on my local machine percival.  See below for details on setting up a local git daemon.

Running Tests on the vcloud
---------------------------

In order to use the Puppet Labs vcloud, you'll need to be a Puppet Labs employee.
Community members should see the [guide to running the tests on vagrant boxen](#running-tests-on-local-vagrant-boxen).

### Authentication

Normally the ci tasks are called from a prepared Jenkins job.

If you are running this on your laptop, you will need this ssh private key in order for beaker to be able to log into the vms created from the hosts file:

https://github.com/puppetlabs/puppetlabs-modules/blob/qa/secure/jenkins/id_rsa-acceptance
https://github.com/puppetlabs/puppetlabs-modules/blob/qa/secure/jenkins/id_rsa-acceptance.pub

TODO fetch these files directly from github, but am running into rate limits and then would also have to cross the issue of authentication.

You will also need QA credentials to vsphere in a ~/.fog file.  These credentials can be found on any of the Jenkins coordinator hosts.

### Packages

In order to run the tests on hosts provisioned from packages produced by Delivery, you will need to reference a Puppet commit sha that has been packaged using Delivery's pl:jenkins:uber_build task.  This is the snippet used by 'Puppet Packaging' Jenkins jobs:

```sh
rake --trace package:implode
rake --trace package:bootstrap
rake --trace pl:jenkins:uber_build
```

The above Rake tasks were run from the root of a Puppet checkout.  They are quoted just for reference.  Typically if you are investigating a failure, you will have a SHA from a failed jenkins run which should correspond to a successful pipeline run, and you should not need to run the pipeline manually.

A finished pipeline will have repository information available at http://builds.puppetlabs.lan/puppet/  So you can also browse this list and select a recent sha which has repo_configs/ available.

When executing the ci:test:packages task, you must set the SHA, and also set CONFIG to point to a valid Beaker hosts_file.  Configurations used in the Jenkins jobs are available under config/nodes

```sh
bundle exec rake ci:test:packages SHA=abcdef CONFIG=config/nodes/rhel.yaml
```

Optionally you may set the TEST (TEST=a/test.rb,and/another/test.rb), and may pass additional OPTIONS to beaker (OPTIONS='--opt foo').

You may also edit a ./local_options.rb hash which will override config/ options, and in turn be overriden by commandline options set in the environment variables CONFIG, TEST and OPTIONS.  This file is a ruby file containing a Ruby hash with configuration expected by Beaker.  See Beaker source, and examples in config/.

### Git

Alternatively you may provision via git clone by calling the ci:test:git task.  Currently we don't have packages for Windows or Solaris from the Delivery pipeline, and must use ci:test:git to provision and test these platforms.

#### Source Checkout for Different Fork

If you have a branch pushed to your fork which you wish to test prior to merging into puppetlabs/puppet, you can do so be setting the FORK environment variable.  So, if I have a branch 'issue/master/wonder-if-this-explodes' pushed to my jpartlow puppet fork that I want to test on Windows, I could invoke the following:

```sh
bundle exec rake ci:test:git CONFIG=config/nodes/win2008r2.yaml SHA=issue/master/wonder-if-this-explodes FORK=jpartlow
```

#### Source Checkout for Local Branch

See notes on running acceptance with Vagrant for more details on using a local git daemon.

TODO Fix up the Rakefile's handling of git urls so that there is a simple way to specify both a branch on a github fork, and a branch on some other git server daemon, so that you have fewer steps when serving from a local git daemon.

### Preserving Hosts

If you need to ssh into the hosts after a test run, you can use the following sequence:

    bundle exec rake ci:test_and_preserve_hosts CONFIG=some/config.yaml SHA=12345 TEST=a/foo_test.rb

to get the initial templates provisioned, and a local log/latest/preserve_config.yaml created for them.

Then you can log into the hosts, or rerun tests against them by:

    bundle exec rake ci:test_against_preserved_hosts TEST=a/foo_test.rb

This will use the existing hosts.

### Cleaning Up Preserved Hosts

If you run a number of jobs with --preserve_hosts or vi ci:test_and_preserve_hosts, you may eventually generate a large number of stale vms.  They should be reaped automatically by qa infrastructure within a day or so, but you may also run:

    bundle exec rake ci:release_hosts

to clean them up sooner and free resources.

There also may be scenarios where you want to specify the host(s) to relase. E.g. you may want to relase a subset of the hosts you've created. Or, if a test run terminates early, ci:release_hosts may not be able to derive the name of the vm to delete. In such cases you can specify host(s) to be deleted using the HOST_NAMES environment variable. E.g.

    HOST_NAMES=lvwwr9tdplg351u bundle exec rake ci:release_hosts
    HOST_NAMES=lvwwr9tdplg351u,ylrqjh5l6xvym4t bundle exec rake ci:release_hosts


Running Tests on Vagrant Boxen
------------------------------

This guide assumes that you have an acceptable Ruby (i.e. 1.9+) installed along with the bundler gem, that you have the puppet repo checked out locally somewhere, and that the name of the checkout folder is `puppet`.
I used Ruby 1.9.3-p484

Change to the `acceptance` directory in the root of the puppet repo:
```sh
cd /path/to/repo/puppet/acceptance
```
Install the necessary gems with bundler:
```sh
bundle install
```

Now you can get a list of test-related tasks you can run via rake:
```sh
bundle exec rake -T
```
and view detailed information on the tasks with
```sh
bundle exec rake -D
```

As an example, let's try running the acceptance tests using git as the code deployment mechanism.
First, we'll have to create a beaker configuration file for a local vagrant box on which to run the tests.
Here's what such a file could look like:
```yaml
HOSTS:
  all-in-one:
    roles:
      - master
      - agent
    platform: centos-64-x64
    hypervisor: vagrant
    ip: 192.168.80.100
    box: centos-64-x64-vbox4210-nocm
    box_url: http://puppet-vagrant-boxes.puppetlabs.com/centos-64-x64-vbox4210-nocm.box

CONFIG:
```
This defines a 64-bit CentOS 6.4 vagrant box that serves as both a puppet master and a puppet agent for the test roles.
(For more information on beaker config files, see [beaker's README](https://github.com/puppetlabs/beaker/blob/master/README.md).)
Save this file as `config/nodes/centos6-local.yaml`; we'll be needing it later.

Since we have only provided a CentOS box, we don't have anywhere to run windows tests, therefore we'll have to skip those tests.
That means we want to pass beaker a --tests argument that contains every directory and file in the `tests` directory besides the one called `windows`.
We could pass this option on the command line, but it will be gigantic, so instead let's create a `local_options.rb` file that beaker will automatically read in.
This file should contain a ruby hash of beaker's command-line flags to the corresponding flag arguments.
Our hash will only contain the `tests` key, and its value will be a comma-seperated list of the other files and directories in `tests`.
Here's an easy way to generate this file:
```sh
echo "{tests: \"$(echo tests/* | sed -e 's| *tests/windows *||' -e 's/ /,/g')\"}" > local_options.rb"
```

The last thing that needs to be done before we can run the tests is to set up a way for the test box to check out our local changes for testing.
We'll do this by starting a git daemon on our host.
In another session, navigate to the folder that contains your checkout of the puppet repo, and then create the following symlink:
```sh
ln -s . puppetlabs-puppet.git
```
This works around the inflexible checkout path used by the test prep code.

Now start the git daemon with
```sh
git daemon --verbose --informative-errors --reuseaddr --export-all --base-path=.
```
after which you should see a message like `[32963] Ready to rumble` echoed to the console.

Now we can finally run the tests!
The rake task that we'll use is `ci:test:git`.
Run
```
bundle exec rake -D ci:test:git
```
to read the full description of this task.
From the description, we can see that we'll need to set a few environment variables:
  + CONFIG should be set to point to the CentOS beaker config file we created above.
  + SHA should be the SHA of the commit we want to test.
  + GIT_SERVER should be the IP address of the host (i.e. your machine) in the vagrant private network created for the test box.
    This is derived from the test box's ip by replacing the last octet with 1.
    For our example above, the host IP is 192.168.80.1
  + FORK should be the path to a 'puppetlabs-puppet.git' directory that points to the repo.
    In our case, this is the path to the symlink we created before, which is inside your puppet repo checkout, so FORK should just be the name of your checkout.
    We'll assume that the name is `puppet`.

Putting it all together, we construct the following command-line invocation to run the tests:
```sh
CONFIG=config/nodes/centos6-local.yaml SHA=#{test-commit-sha} GIT_SERVER='192.168.80.1' FORK='puppet' bundle exec rake --trace ci:test:git
```
Go ahead and run that sucker!

Testing will take some time.
After the testing finishes, you'll either see this line
```
systest completed successfully, thanks.
```
near the end of the output, indicating that all tests completed succesfully, or you'll see the end of a stack trace, indicating failed tests further up.
