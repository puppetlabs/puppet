# Testing on EC2

## How To
This section will provide step-by-step instructions for deploying
an environment that will allow the `puppet` acceptance test suite
to be executed on an EC2 master and agent.

1. Make sure you have your AWS key and id defined in `$HOME/.fog`
See the [beaker AWS documentation](https://github.com/puppetlabs/beaker/blob/master/docs/how_to/hypervisors/aws.md)
for details.

1. Clone puppet repo
   ```
   git clone git@github.com:puppetlabs/puppet.git
   ```

1. Perform a `bundle install` to install the gems required to run the tests.
   ```
   pushd puppet/acceptance
   bundle install
   ```

1. Get the puppet [EC2 image templates](https://github.com/puppetlabs/pe_acceptance_tests/blob/2016.5.x/config/image_templates/ec2.yaml).
   Note: These are restricted to Puppet, Inc. employees.
   ```
   pushd ../../
   git clone git@github.com:puppetlabs/pe_acceptance_tests.git
   pushd pe_acceptance_tests
   git checkout 2017.2.x
   popd
   popd
   mkdir config/image_templates
   cp ../../pe_acceptance_tests/config/image_templates/ec2.yaml config/image_templates/
   ```

1. Set the value for the external `forge_host`

   This is important. The hostname for the Puppet, Inc. test forge is different
   depending on which side of Puppet, Inc. netork the test system is on. See [OPS-9499
   resolution](https://tickets.puppetlabs.com/browse/OPS-9499?focusedCommentId=320139&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-320139)
   for details.

   For EC2 instances, it should be defined as follows:
   ```
   export forge_host=forgenext-aio-petest-prod-1.puppetlabs.net
   ```

   NOTE: Since the Rakefile sets a default value for `forge_host` at the options
   level, this cannot be overridden by setting it at the host level via
   beaker-hostgenerator. Currently, it needs to be set as an ENV var.

1. Create the Beaker config file
   Amazon Linux example
   ```
   bundle exec beaker-hostgenerator "redhat6-64ma{hypervisor=ec2,user=ec2-user,amisize=m3.large,snapshot=pe,vmname=amazon-6-x86_64}-redhat6-64a{hypervisor=ec2,user=ec2-user,amisize=m3.large,snapshot=pe,vmname=amazon-6-x86_64}" > hosts.yaml
   sed -i 's/---/---\nhost_tags:\n  lifetime: 2h/' hosts.yaml
   ```

1. Execute the acceptance test Rake task

   The puppet test suite can be run using the `ci:test:aio` rake task.

   You will need to substitute your own values for the following:
       * puppet-agent SHA
       * puppet-agent SUITE_VERSION
       * puppetserver SERVER_VERSION (optional)

   If a value is not specified for `SERVER_VERSION` puppetserver will be
   installed from the latest available nightly.


   ```
   SHA=96b104a30eb1808abcf521e5b8d2f6a3a38752b6                                                                   \
   SUITE_VERSION=4.99.0.363.g96b104a                                                                              \
   SERVER_VERSION=2.7.2                                                                                           \
   HOSTS=hosts.yaml                                                                                               \
   TESTS=tests                                                                                                    \
   bundle exec rake ci:test:aio
   ```
