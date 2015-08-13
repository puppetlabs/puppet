require 'puppet/acceptance/common_utils'
require 'puppet/acceptance/install_utils'

extend Puppet::Acceptance::InstallUtils

test_name "Install Packages"

step "Install repositories on target machines..." do

  sha = ENV['SHA']
  repo_configs_dir = 'repo-configs'

  hosts.each do |host|
    install_repos_on(host, 'puppet-agent', sha, repo_configs_dir)
  end

  if master['passenger']
    passenger_version = ENV['PASSENGER_VERSION'] || '3518347c3480172fcef41406cad31b7ed34cd14f'
    install_repos_on(master, 'puppet-master-passenger', passenger_version, repo_configs_dir)
  else
    server_version = ENV['SERVER_VERSION'] || 'nightly'
    install_repos_on(master, 'puppetserver', server_version, repo_configs_dir)
  end
end

if master['passenger']
  MASTER_PACKAGES = {
    :redhat => [
      'puppet-master-passenger',
    ],
    :debian => [
      'puppet-master-passenger',
    ],
  }
else
  MASTER_PACKAGES = {
    :redhat => [
      'puppetserver',
    ],
    :debian => [
      'puppetserver',
    ],
#  :solaris => [
#    'puppet-server',
#  ],
#  :windows => [
#    'puppet-server',
#  ],
  }
end

AGENT_PACKAGES = {
  :redhat => [
    'puppet-agent',
  ],
  :debian => [
    'puppet-agent',
  ],
#  :solaris => [
#    'puppet',
#  ],
#  :windows => [
#    'puppet',
#  ],
}

install_packages_on(master, MASTER_PACKAGES)
install_packages_on(agents, AGENT_PACKAGES)

# make sure install is sane, beaker has already added puppet and ruby
# to PATH in ~/.ssh/environment
agents.each do |agent|
  on agent, puppet('--version')
  ruby = Puppet::Acceptance::CommandUtils.ruby_command(agent)
  on agent, "#{ruby} --version"
end

configure_gem_mirror(hosts)
