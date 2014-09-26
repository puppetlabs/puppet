#!/bin/bash
##!/bin/bash +e +x

#source /usr/local/rvm/scripts/rvm
#rvm use ruby-1.9.3-p392

umask 0002

cd acceptance

if [ -z "$tests" ]; then
echo "Must provide tests to run in the environment variable 'tests': got '$tests'"
exit 1
fi

if [ -z "$platform" ]; then
  echo "'platform' not set: assuming 'el-6-x86_64'"
  platform="el-6-x86_64"
fi

if [ -z "$1" ]; then
echo "Must provide the hostname: got '$1'"
exit 1
fi

if [ -z "$2" ]; then

  cat > hosts-immediate.cfg << EOHOSTS
---
HOSTS:
  ${1}:
    roles:
    - agent
    - master
    - dashboard
    - database
    platform: ${platform} 
CONFIG:
  nfs_server: none
  consoleport: 443
  datastore: instance0
  folder: Delivery/Quality Assurance/Enterprise/Dynamic
  resourcepool: delivery/Quality Assurance/Enterprise/Dynamic
  pooling_api: http://vcloud.delivery.puppetlabs.net/
EOHOSTS

else

  if [ -z "$3" ]; then

    cat > hosts-immediate.cfg << EOHOSTS
---
HOSTS:
  ${1}:
    roles:
    - agent
    - dashboard
    - database
    - master
    platform: ${platform}
  ${2}:
    roles:
    - agent
    platform: ${platform}
CONFIG:
  nfs_server: none
  consoleport: 443
  datastore: instance0
  folder: Delivery/Quality Assurance/Enterprise/Dynamic
  resourcepool: delivery/Quality Assurance/Enterprise/Dynamic
  pooling_api: http://vcloud.delivery.puppetlabs.net/
EOHOSTS

  else

    cat > hosts-immediate.cfg << EOHOSTS
---
HOSTS:
  ${1}:
    roles:
    - agent
    - master
    platform: ${platform}
  ${2}:
    roles:
    - agent
    - dashboard
    platform: ${platform}
  ${3}:
    roles:
    - agent
    - database
    platform: ${platform}
CONFIG:
  nfs_server: none
  consoleport: 443
  datastore: instance0
  folder: Delivery/Quality Assurance/Enterprise/Dynamic
  resourcepool: delivery/Quality Assurance/Enterprise/Dynamic
  pooling_api: http://vcloud.delivery.puppetlabs.net/
EOHOSTS

  fi

fi

export forge_host=api-forge-aio01-petest.puppetlabs.com

bundle exec beaker           \
  --xml                      \
  --debug                    \
  --repo-proxy               \
  --config hosts-immediate.cfg         \
  --pre-suite setup/common/pre-suite/110_SetPEPuppetService.rb \
  --tests=${tests}           \
  --keyfile ${HOME}/.ssh/id_rsa-acceptance \
  --root-keys \
  --helper lib/helper.rb \
  --preserve-hosts onfail \
  --no-color

RESULT=$?

exit $RESULT
