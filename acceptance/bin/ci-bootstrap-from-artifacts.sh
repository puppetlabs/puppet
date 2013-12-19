#! /usr/bin/env bash

###############################################################################
# Initial preparation for a ci acceptance job in Jenkins.  Crucially, it
# handles the untarring of the build artifact and bundle install, getting us to
# a state where we can then bundle exec rake the particular ci:test we want to
# run.
#
# Having this checked in in a script makes it much easier to have multiple
# acceptance jobs.  It must be kept agnostic between Linux/Solaris/Windows
# builds, however.

set -x

# Use our internal rubygems mirror for the bundle install
if [ -z $GEM_SOURCE ]; then
  export GEM_SOURCE='http://rubygems.delivery.puppetlabs.net'
fi

echo "SHA: ${SHA}"
echo "BUILD_SELECTOR: ${BUILD_SELECTOR}"
echo "PACKAGE_BUILD_STATUS: ${PACKAGE_BUILD_STATUS}"

rm -rf acceptance
mkdir acceptance
cd acceptance
tar -xzvf ../acceptance-artifacts.tar.gz

echo "===== This artifact is from ====="
cat creator.txt

cd config/el6
bundle install --without=development --path=.bundle/gems

cat > local_options.rb <<-EOF
{
  :hosts_file => 'config/nodes/${platform}.yaml',
  :ssh => {
    :keys => ["${HOME}/.ssh/id_rsa-old.private"],
  },
}
EOF

[[ (-z "${PACKAGE_BUILD_STATUS}") || ("${PACKAGE_BUILD_STATUS}" = "success") ]] || exit 1
