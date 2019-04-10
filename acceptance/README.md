# Running Puppet Acceptance Tests


## Table of Contents
* [Setup](#setup)
* [Quick Start](#quick-start)
* [Configuration](#configuration)
* [Running Tests](#running-tests)
* [Writing Tests](#writing-tests)
* [Getting Help](#getting-help)

-------------
An important aside: currently running acceptance tests that contain a specific
change is challenging unless you have access to internal infrastructure. This
is a known issue, and we are working to make this a better experience for our
community.

-------------

## Setup
### Prerequisites
This assumes you have git, ruby, and the [bundler][] gem installed. You'll need
a local clone of the puppet repo. All command examples in this readme assume you
are working in the acceptance directory, where this README is located.

### Installation
All of the dependencies you need to run and develop tests are defined in
`Gemfile`. To install them, run `bundle install --path .bundle/gems`. This
command, as will all the command examples in this README, assume you are working
in the acceptance directory. If you ever have issues with your runtime
dependencies, you can update them with `bundle update`, or start over fresh with
`rm -rf .bundle/gems; bundle install`.

To ensure installation was successful, you can run `bundle exec rake -T`. This
should return something along these lines:
```
$ bundle exec rake -T
rake ci:help               # Print usage information
rake ci:test:aio           # Run the acceptance tests using puppet-agent (AI...
rake ci:test:gem           # Run the acceptance tests against puppet gem on ...
rake ci:test:git           # Run the acceptance tests against a git checkout
rake ci:test:quick         # Run a limited but representative subset of acce...
rake clean                 # Remove any temporary products
rake clobber               # Remove any generated files
```
To get a detailed description of all of these tasks, run `bundle exec rake -D`.

-------------
## Quick Start
### For community members
Currently, there isn't a good way for community members to run acceptance tests.
This is a known problem. We currently have multiple avenues we are exploring to
make running puppet acceptance tests easier for our community. In the meantime,
we apologize for the inconvenience.

### For Puppet, Inc. employees
If you have access to infrastructure internal to the Puppet, Inc. network, then the
quickest way to get acceptance tests running is going to be with vmpooler.

To test changes that are available on a branch on github.com:
```
bundle exec rake ci:test:git OPTIONS='--preserve-hosts=always' SHA=ticket/6.0.x/ticketed-work-description RUNTIME_BRANCH=6.0.x FORK=melissa TESTS='tests/path/to/test.rb,tests/other/test.rb'
```
Where `SHA` is the branch name, `RUNTIME_BRANCH` is the agent version stream,
and `FORK` is the github fork where the branch lives.

To test changes that are available in a puppet-agent package on builds.delivery.puppetlabs.net:
```
bundle exec rake ci:test:aio OPTIONS='--preserve-hosts=always' SHA=9124b4e81ec0ac6394d3edc67d4ab71866869fd7 TESTS='tests/path/to/test.rb,tests/other/test.rb'
```
`SHA` is a sha or tag that exists on builds.delivery.puppetlabs.net/puppet-agent

To rerun a test on the hosts that have already been provisioned, use beaker subcommands:
```
bundle exec beaker exec tests/path/to/test.rb,tests/other/test.rb
```

Always clean up after yourself
```
bundle exec beaker destroy
```

-------------

## Configuration
### Environment Variables
A detailed description of the available environment variables can be found by
running `bundle exec rake ci:help`. This will print a list of both required and
optional environment variable with short descriptions on how they are used.
Please review all of these options as they will impact how your test servers
are provisioned. This rake task is the most up to date source for this
information.

### Customizing Test Targets
If you are using the vmpooler hypervisor and the internal pooling api, you can
customize the platforms to test on using the HOSTS environment variable. The
internal pooling api is only available to Puppet, Inc. employees. You'll set the
`HOSTS` environment variable to the host string you want to test, such as
`HOSTS=redhat7-64ma-windows2012r2-64a`.

If you are unsure of the syntax you need, you can verify the host string against
the options in
[beaker hostgenerator](https://github.com/puppetlabs/beaker-hostgenerator/blob/master/lib/beaker-hostgenerator/data.rb). Be sure to use the key from the hash structure.
You can safely ignore the data associated with the key.
Generally, this string will be in the format
`{platform}{version}-{architecture}{role/s}`. You will most often use either the
agent (a) or master (m) role, but you can find a list of available roles in
[beaker hostgenerator](https://github.com/puppetlabs/beaker-hostgenerator/blob/master/lib/beaker-hostgenerator/roles.rb).
Multiple hosts in the string are separated with a dash(`-`). You must have at
least one agent and at least one master.

Be careful not to confuse the different host string formats. We have different
tools that expect the host string to be in different forms. For example,
`packaging_platform` is specific to how [Vanagon](https://github.com/puppetlabs/vanagon)
parses that string.

### hosts.yaml
The rake tasks that run acceptance will by default create a hosts file and
populate it using [beaker-hostgenerator][] using either the `HOSTS` environment
variable or the default host string (currently `redhat7-64ma-windows2012r2-64a`).
The automation assumes you are using the vmpooler hypervisor and an internal
pooling api, which is only available to Puppet, Inc. employees. If you want to
customize the hypervisor or the pooling api, you'll need to generate your own
hosts file. You must pass in a valid host string to the `beaker-hostgenerator`
command. See the previous section for more information on how to construct a
valid host string.

To customize the hypervisor, pass in `--hypervisor {hypervisor name}`. To set
the pooling api, use `--global-config pooling_api={custom api}`. Only the
vmpooler hypervisor uses the pooling api.

The host string that is passed in is the same that you would use with the
`HOSTS` environment variable. See the [previous section](##customizing-test-targets) on how to format this string.

For example, if you were to run this command:
```
bundle exec beaker-hostgenerator redhat7-64ma-windows2012r2-64a --disable-default-role --osinfo-version 1 --hypervisor vmpooler --global-config pooling_api=http://customvmpooler/ > hosts.yaml
```
You would generate a file called `hosts.yaml` that contains something like this:
```
---
HOSTS:
  redhat7-64-1:
    platform: el-7-x86_64
    packaging_platform: el-7-x86_64
    template: redhat-7-x86_64
    hypervisor: vmpooler
    roles:
    - master
    - agent
  windows2012r2-64-1:
    platform: windows-2012r2-64
    packaging_platform: windows-2012-x64
    ruby_arch: x64
    template: win-2012r2-x86_64
    hypervisor: vmpooler
    roles:
    - agent
CONFIG:
  nfs_server: none
  consoleport: 443
  pooling_api: http://customvmpooler/
```
To have the automation recognize and use your custom hosts file, you'll need to
set the `HOSTS` environment variable to the hosts file. In the above example, we
called this file `hosts.yaml`, so we will use `HOSTS=hosts.yaml` when running
all future beaker commands or rake tasks to run acceptance tests.

### Hypervisor Options
The hypervisor dictates where you will be running the acceptance tests. The beaker
hypervisors take care of basic host setup so that you will have a consistent
host environment across every test run. You can find more details on the different
hypervisor options in [the beaker repo](https://github.com/puppetlabs/beaker/blob/master/docs/how_to/hypervisors/README.md).

Here, we will focus on vmpooler and docker, as those are the two we use most
often internally. If you use a hypervisor other than abs, vagrant, vmpooler, or
docker, you'll have to add the gem to that hypervisor to `Gemfile.local` and run
`bundle update` to install the new gems. You also have the ability to run tests
on a static host, which I will cover briefly.

#### VMPooler
[VMPooler](https://github.com/puppetlabs/vmpooler) is the default hypervisor we
use. This is only available to Puppet, Inc. employees as it uses internal
infrastructure. If you have access to a similar setup, then you are welcome to
use this option with a few values changed. If you are using the Puppet internal
vmpooler, then you can simply run the acceptance rake tasks. See
[the previous section]( #customizing-test-targets) about how to use the
`HOSTS` environment variable to customize the platforms you are running tests on.

To use a different pooling api, use
`--global-config pooling_api=http://customvmpooler/` when you use
`beaker-hostgenerator` to generate `hosts.yaml`. Make sure you set `HOSTS` to
the host file you just generated so the automation can find that file. See
[the previous section](#hosts.yaml) for more detail on the hosts file.

#### Docker
To test with [the docker hypervisor](https://github.com/puppetlabs/beaker-docker),
you will want to generate a custom hosts file. You will also mostly likely need
to manually edit the file. See [the previous section](#hosts.yaml) for more
detail on the hosts file.

The following hosts file uses a vmpooler master and a docker agent. When
using rake tasks or beaker to run acceptance, ensure `HOSTS` always points to
your hosts file. There is no easy way to generate a hosts file with multiple
hypervisors. This file was put together by hand.

You need access to both vmpooler.delivery.puppetlabs.net to access the vmpooler
test machine and builds.delivery.puppetlabs.net to access the built version of
puppet-agent that you are testing against.

```
---
HOSTS:
  redhat7-64-1:
    docker_cmd:
      - "/sbin/init"
    image: centos:7
    platform: el-7-x86_64
    packaging_platform: el-7-x86_64
    hypervisor: docker
    roles:
      - master
  debian9-64-1:
    docker_cmd:
      - "/sbin/init"
    image: debian:9
    platform: debian-9-amd64
    packaging_platform: debian-9-amd64
    docker_image_commands:
      - cp /bin/true /sbin/agetty
      - rm -f /usr/sbin/policy-rc.d
      - apt-get update && apt-get install -y cron locales-all net-tools wget systemd-sysv
        gnupg
    hypervisor: docker

    mount_folders:
      puppet:
        host_path: ~/puppet
        container_path: /build/puppet
    roles:
      - agent
CONFIG:
  nfs_server: none
  consoleport: 443
  pooling_api: http://vmpooler.delivery.puppetlabs.net/
```
Run acceptance tests against pre-built puppet-agent packages with
`bundle exec rake ci:test:aio SHA=<sha or tag> TESTS=path/to/test.rb HOSTS=hosts.yaml`

When you generate your [hosts file](#hosts.yaml), [beaker-hostgenerator][] does
its best to populate the values as logically as possible. You will likely want
to update or modify them to suite your needs.

With `image`, [beaker-hostgenerator][] does its best to guess the most logical
image string based on the platform you are building. For the most part, this
should work without interference, but if you are using a custom docker image or
do not want the default, then you will have to manually update this string. The
example above has modified `image` to pull from the pcr-internal docker repo.

`docker_image_commands` is automatically populated when generating the hosts
file with [beaker-hostgenerator][]. This has already been set for a handful of
host types, but may not be set for all.

* TODO I believe I had a few issues with the initial docker image setup. I'd
    like to go through these steps with someone else so that I can remember what
    that initial pain was exactly.
* TODO I only tried it once with a docker master, but the image I used was SO
    SLOW, so I gave up. I also ran out of time. So this will be something that
    would be good to investigate more fully.
* TODO check with Casey and Molly about these. I can't quite remember the
    details, but I do remember that we found `docker_image_entrypoint`
    preferable to `docker_cmd`.
* TODO These docker containers have to run in priviledged mode (or systemd,
    among possibly other things, won't function as we need them to). This is
    not ideal if you're testing code that affects your OS (ie running docker on
    linux without a docker machine in between the container and your laptop).
* TODO add emphasis that you need an account and permissions to access the images
    on pcr-internal.puppet.net

#### Static Hosts
To test on a server that's already been spun up or doesn't require a hypervisor,
you should set the name of the host to the FQDN of the server you want to use,
then remove the hypervisor and template settings. This is not recommended, and
you may run into issues with failures or overwritten configuration due to either
beaker provision steps or test provisioning steps.
```
---
HOSTS:
    azeqdqmk14mvu3g.delivery.puppetlabs.net:
        platform: el-7-x86_64
        packaging_platform: el-7-x86_64
        roles:
          - master
```
This is not recommended unless you are familiar with how [beaker][] and
[beaker-puppet][] provision hosts.

-------------

## Running Tests
### Testing with pre-built packages
```
bundle exec rake ci:test: SHA={sha|tag}
```

This is the primary method that we use to run puppet acceptance tests. It
requires puppet-agent packages that have been built with the version of the
puppet code that you want to test. As building packages usually takes quite a
bit of time, this method requires some patience. You are required to set `SHA`
when running acceptance tests against pre-built packages.

#### Testing a specific version
If you are testing a specific version, `SHA` must be set to a value that exists
on the path `#{ENV['DEV_BUILDS_URL']}/puppet-agent/#{ENV['SHA']}`. Note that
this value corresponds to the puppet-agent package, not to puppet.
`DEV_BUILDS_URL` defaults to the internal build server that is only accessible
to Puppet, Inc. employees. The method called here depends on information written
to a yaml file in that directory. Though you can override DEV_BUILDS_URL, the
automation here is very specific and likely will not work as you are expecting
it to.

```
bundle exec rake ci:test:aio SHA=3cfbac6857c10efc5b1e02262cfd7b849bb9c4b2
```
```
bundle exec rake ci:test:aio SHA=6.0.5
```

#### Testing Nightlies
If you do not have access to internal infrastructure, you can test against
packages that have been made available on nightlies.puppet.com. Currently, you
cannot specify a specific version. Instead, you have to use the latest shipped
package for the release stream you are interested in. To do this, `SHA` must be
set to `latest`. If you want to modify the release stream you are testing,
`RELEASE_STREAM` can be modified. It defaults to `puppet` which should
correspond to the latest stream available. If you want to modify
`RELEASE_STREAM`, set it to an available repo, such as `puppet5`.
```
bundle exec rake ci:test:aio SHA=latest RELEASE_STREAM=puppet5
```

### Testing with Git
```
bundle exec rake ci:test:git SHA={sha|tag|branch}
```

#### From a repo on a git server
Though we primarily run acceptance tests against a built package, it is possible
to run these tests with a git checkout. This is most useful when testing locally
to speed up the feedback cycle.

When testing from a github repo we need to unpack the appropriate
[runtime archive](https://github.com/puppetlabs/puppet-runtime)
for the platform we are testing on. These pre-built archives are stored on an
internal server, and are currently only available to Puppet, Inc. employees.
With these archives, we get all of the runtime dependencies that are usually
provided as a part of the puppet agent package. This allows us to replicate
the runtime environment produced via a package install for the purpose of
running acceptance tests.

When testing with git, `SHA` can be set to any git artifact: a long sha, a short
sha, a tag, a branch name, etc. What happens is that we write a gemfile with the
details of the puppet repo, pointing to the artifact referenced with `SHA`. Then
when we run `bundle install` on the testing host, bundler grabs puppet from
wherever the gemfile points. If the git artifact referenced is not from the
puppetlabs repo, you can use `FORK` to point to a different github namespace.
Likewise, if the artifact you want to access is not available on `github.com`
but a custom git server, you can set `SERVER` to customize the git uri bundler
pulls from. For more details on these environment variables, run
`bundle exec rake ci:help`.

As an example, if I have a development branch
(`developent/master/major-feature`) that I'm working on and it only exists in my
fork of puppet (`github.com/joeschmoe/puppet`), then I will run
```
bundle exec rake ci:test:git SHA=developent/master/major-feature FORK=joeschmoe
```

Please note that any changes you want to test must be pushed up to your github
server. This is how we access the code to be tested.

#### From a local repo
If yor are testing with git and using the docker hypervisor, you can run tests
against the puppet checkout on your local system. You need to update your hosts
file to add `mount_folders` to the docker host where you want the checkout of
puppet to be available. Here, `host_path` is the path to puppet on your local
machine. You must make sure this matches where puppet is on your machine. The
`container_path` is where puppet will end up on the docker image, so you can
leave it as `/build/puppet`. Note that although `SHA` is required, it is never
used in this workflow. For consistency, I would recommend setting `SHA` to your
working branch name.

We still need access to our runtime dependencies when testing against a local
git checkout. When we are testing with the docker hypervisor, we assume that the
docker image you are using will have this. As of this writing (Jan. 2019), the
docker image you'll want to use for these tests is not public. The image is
called `agent-runtime-{branch}`, where `{branch}` is the branch of puppet you
are testing. This image includes everything we build as a part of [the runtime
archive](https://github.com/puppetlabs/puppet-runtime). These components are
normally provided as a part of the puppet agent package.
```
---
HOSTS:
  debian8-64-1:
    hypervisor: docker
    docker_image_entrypoint: "/sbin/init"
    image: pcr-internal.puppet.net/pe-and-platform/agent-runtime-master:201810110.17.gb5afc66
    platform: debian-8-amd64
    packaging_platform: debian-8-amd64
    docker_image_commands:
      - rm -f /usr/sbin/policy-rc.d
      - systemctl mask getty@tty1.service getty-static.service
      - apt-get update && apt-get install -y cron locales-all net-tools wget
    mount_folders:
      puppet:
        host_path: ~/puppet
        container_path: /build/puppet
    roles:
      - agent
```

For more details on testing with docker, see [the docker section](#docker).
Remember that `HOSTS` must be set to your hosts file for the automation to honor
it.

### Testing with Gems
```
bundle exec rake ci:test:gem
```
Currently, running acceptance tests with gems is not working.

### Rerunning Failed Tests
The rake tasks we use here take advantage of a newer feature in beaker that gives us quite a bit of flexibility. We take advantage of beaker subcommands. Subcommands are individual beaker invocations that are used to run the different stages of running tests: provisioning, pre-suite setup, tests, etc. We do this by writing state to the file `.beaker/subcommand_options.yaml`. With each new invocation of a subcommand, beaker will check for this file and load the contents if the file exists. The important thing about this feature is that you can rerun tests without going through the entire provisioning process every time.

To ensure your hosts aren't cleaned up after a run, set `OPTIONS='--preserve-hosts=always'`. With this set, we can rerun a failed test using the infrastructure beaker has already provisioned.
```
bundle exec rake ci:test:aio OPTIONS='--preserve-hosts=always' SHA=6.0.5
```
If this run fails because a small handful of tests fail, I can rerun only those tests that failed. For example, assume that `tests/resource/package/yum.rb` and `tests/node/check_woy_cache_works.rb` both had failing tests. I can run
```
bundle exec beaker exec tests/resource/package/yum.rb,tests/node/check_woy_cache_works.rb
```

This will work regardless of which hypervisor or testing method you are using.

-------------

## Writing Tests
* TODO I'm definitely going to need help with this section. I'm not very good at writing tests. Jacob?

-------------

## Getting Help
### On the web
* [Puppet help messageboard](http://puppet.com/community/get-help)
* [Writing tests](https://docs.puppet.com/guides/module_guides/bgtm.html#step-three-module-testing)
* [General GitHub documentation](http://help.github.com/)
* [GitHub pull request documentation](http://help.github.com/send-pull-requests/)
### On chat
* Slack (slack.puppet.com) #testing, #puppet-dev, #windows

[bundler]: https://rubygems.org/gems/bundler
[rspec-puppet]: http://rspec-puppet.com/
[rspec-puppet_docs]: http://rspec-puppet.com/documentation/
[beaker]: https://github.com/puppetlabs/beaker
[beaker-puppet]: https://github.com/puppetlabs/beaker-puppet
[beaker-hostgenerator]: https://github.com/puppetlabs/beaker-hostgenerator
