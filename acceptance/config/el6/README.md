Local Use
=========

If running this on your laptop, you will need this ssh private key in order for systest to be able to log into the vms created in the config.yaml:

https://raw.github.com/puppetlabs/puppetlabs-modules/qa/secure/jenkins/id_rsa-acceptance

And you will have to pass it as a systest --keyfile parameter in the OPTIONS environment to rake:

  be rake ci:test OPTIONS='--keyfile=~/.ssh/id_rsa-acceptance'
