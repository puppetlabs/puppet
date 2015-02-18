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
install_packages_on(agents, AGENT_PACKAGES)

configure_gem_mirror(hosts)

hosts.each do |host|
  case host['platform']
  when /windows/
    # skip deep_merge gem on windows

  else
    step "#{host} Install deep_merge from rubygems"
    on host, 'gem install deep_merge'
  end
end

