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
    platform: el-6-x86_64
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
echo "Must provide three hostnames: got '$1' '$2' '$3'"
exit 1
fi

cat > hosts-immediate.cfg << EOHOSTS
---
HOSTS:
  ${1}:
    roles:
    - agent
    - master
    platform: el-6-x86_64
  ${2}:
    roles:
    - agent
    - dashboard
    platform: el-6-x86_64
  ${3}:
    roles:
    - agent
    - database
    platform: el-6-x86_64
CONFIG:
  nfs_server: none
  consoleport: 443
  datastore: instance0
  folder: Delivery/Quality Assurance/Enterprise/Dynamic
  resourcepool: delivery/Quality Assurance/Enterprise/Dynamic
  pooling_api: http://vcloud.delivery.puppetlabs.net/
EOHOSTS

fi

export forge_host=export forge_host=api-forge-aio01-petest.puppetlabs.com

bundle exec beaker           \
  --xml                      \
  --debug                    \
  --repo-proxy               \
  --config hosts-immediate.cfg         \
  --tests=${tests}           \
  --keyfile ${HOME}/.ssh/id_rsa-acceptance \
  --root-keys \
  --helper lib/helper.rb \
  --preserve-hosts onfail \
  --no-color

RESULT=$?

exit $RESULT
