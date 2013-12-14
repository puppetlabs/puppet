require 'puppet/acceptance/install_utils'

extend Puppet::Acceptance::InstallUtils

test_name "Install Packages"

step "Install repositories on target machines..." do

  sha = ENV['SHA']
  repo_configs_dir = 'repo-configs'

  hosts.each do |host|
    install_repos_on(host, sha, repo_configs_dir)
  end
end


MASTER_PACKAGES = {
  :redhat => [
    'puppet-server',
  ],
  :debian => [
    'puppetmaster',
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
if master['platform'] =~ /debian|ubuntu/
  on(master, '/etc/init.d/puppetmaster stop')
end
install_packages_on(agents, AGENT_PACKAGES)
