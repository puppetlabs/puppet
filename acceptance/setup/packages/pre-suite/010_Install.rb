require 'puppet/acceptance/install_utils'

extend Puppet::Acceptance::InstallUtils

test_name "Install Packages"

step "Install repositories on target machines..." do

  sha = ENV['SHA']
  repo_configs_dir = 'repo-configs'

  hosts.each do |host|
    install_repos_on(host, 'puppet', sha, repo_configs_dir)
  end
end


MASTER_PACKAGES = {
  :redhat => [
    'puppet-server',
  ],
  :debian => [
    'puppetmaster-passenger',
  ],
#  :solaris => [
#    'puppet-server',
#  ],
#  :windows => [
#    'puppet-server',
#  ],
}

AGENT_PACKAGES = {
  :redhat => [
    'puppet',
  ],
  :debian => [
    'puppet',
  ],
#  :solaris => [
#    'puppet',
#  ],
#  :windows => [
#    'puppet',
#  ],
}

install_packages_on(master, MASTER_PACKAGES)
if ENV['AIO_AGENT_INSTALL']
  install_aio_on(agents)
else
  install_packages_on(agents, AGENT_PACKAGES)
end

configure_gem_mirror(hosts)
