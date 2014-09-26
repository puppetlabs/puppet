#!/bin/bash
##!/bin/bash +e +x

#source /usr/local/rvm/scripts/rvm
#rvm use ruby-1.9.3-p392

umask 0002

if [[ -z "$BEAKER_GEM" || -z "$tests" || -z "$platform" || -z "$layout" || -z "$pe_dist_dir" ]]; then
  echo "
  Usage: env <env variables listed below> bin/ci-pe-puppet.sh
    The following environment variables need to be set:
    'pe_dist_dir' (to http://enterprise.delivery.puppetlabs.net/3.3/ci-ready/ for PE 3.3.x for example)
    'platform'    (to one of the http://vcloud.delivery.puppetlabs.net/ platform names...'curl --url http://vcloud.delivery.puppetlabs.net/vm' for more info)
    'layout'      (to '64mcda' or '32mcda' or '32m-32d-32c-32a' or '64mdc-32a' for various cpu & master/database/console node combinations)
    'tests'       (to the comma separated list of tests or directory of tests to execute)
    'BEAKER_GEM'  (to either 'beaker' or 'pe-beaker' which is holding some temporary puppetserver related changes)
"
  exit 1
fi

cd acceptance

rm -f Gemfile.lock

bundle install --path=./.bundle/gems

#export pe_version=${pe_version_override:-$pe_version}
#export pe_family=3.4
bundle exec genconfig ${platform}-${layout} > hosts.cfg

export forge_host=api-forge-aio01-petest.puppetlabs.com

# export PRE_SUITE=./config/el6/setup/pe/pre-suite/
export PRE_SUITE=./setup/pe/pre-suite/

bundle exec beaker           \
  --xml                      \
  --debug                    \
  --repo-proxy               \
  --config hosts.cfg         \
  --pre-suite ${PRE_SUITE}  \
  --tests=${tests}           \
  --keyfile ${HOME}/.ssh/id_rsa-acceptance \
  --root-keys \
  --helper lib/helper.rb \
  --preserve-hosts always \
  --no-color

RESULT=$?

exit $RESULT
