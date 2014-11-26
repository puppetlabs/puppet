test_name "Setup acceptance environment"

step "Ensure package build tools"

require 'puppet/acceptance/install_utils'
extend Puppet::Acceptance::InstallUtils

PACKAGES = {
  :redhat => [
    'rpm-build',
    'createrepo',
  ],
}

install_packages_on(hosts, PACKAGES, :check_if_exists => true)

