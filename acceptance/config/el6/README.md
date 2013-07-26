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

Standalone
----------

Runs against local vagrant instances according to config/local/config.yaml.

    be rake standalone:test

Jenkins
-------

Runs against Jenkins using the info in config/jenkins/config.yaml.

    be rake ci:test

Normally this mode is only called from a prepared Jenkins job.

If running this on your laptop, you will need this ssh private key in order for systest to be able to log into the vms created in the config.yaml:

https://github.com/puppetlabs/puppetlabs-modules/blob/qa/secure/jenkins/id_rsa-acceptance
https://github.com/puppetlabs/puppetlabs-modules/blob/qa/secure/jenkins/id_rsa-acceptance.pub

And you will have to pass it as a systest --keyfile parameter in the OPTIONS environment to rake:

    be rake ci:test OPTIONS='--keyfile=~/.ssh/id_rsa-acceptance'

TODO fetch these files directly from github, but am running into rate limits and then would also have to cross the issue of authentication.
