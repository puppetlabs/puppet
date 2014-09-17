#!/bin/bash
##!/bin/bash +e +x

#source /usr/local/rvm/scripts/rvm
#rvm use ruby-1.9.3-p392

umask 0002

if [[ -z "$beaker_gem" || -z "$tests" || -z "$platform" || -z "$layout" || -z "$pe_dist_dir" ]]; then
  echo "
  Usage: env <env variables listed below> bin/ci-pe-puppet.sh
    The following environment variables need to be set:
    'pe_dist_dir' (to http://enterprise.delivery.puppetlabs.net/3.3/ci-ready/ for PE 3.3.x for example)
    'platform'    (to one of the http://vcloud.delivery.puppetlabs.net/ platform names...'curl --url http://vcloud.delivery.puppetlabs.net/vm' for more info)
    'layout'      (to '64mcd' or '32mcd' or '32m-32d-32c' or '64m-64d-64c' for various cpu & master/database/console node combinations)
    'tests'       (to the comma separated list of tests or directory of tests to execute)
    'beaker_gem'  (to either 'beaker' or 'pe-beaker' which is holding some temporary puppetserver related changes)
"
  exit 1
fi

INSTALL_PATH=`mktemp -d`

cd acceptance
cat > Gemfile << EOGEMFILE
if ENV['NO_MIRROR']
  source 'https://rubygems.org'
else
  source 'http://rubygems.delivery.puppetlabs.net'
end

gem '$beaker_gem'

# beaker-util lives only in our environment.
unless ENV['NO_MIRROR']
  gem 'sqa-utils'
end
EOGEMFILE

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

rm -rf $INSTALL_PATH

exit $RESULT
