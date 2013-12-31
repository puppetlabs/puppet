test_name "Setup environment"

step "Ensure Git and Ruby"

require 'puppet/acceptance/install_utils'
extend Puppet::Acceptance::InstallUtils
require 'beaker/dsl/install_utils'
extend Beaker::DSL::InstallUtils

PACKAGES = {
  :redhat => [
    'git',
    'ruby',
  ],
  :debian => [
    ['git', 'git-core'],
    'ruby',
  ],
  :solaris => [
    ['git', 'developer/versioning/git'],
    ['ruby', 'runtime/ruby-18'],
  ],
  :windows => [
    'git',
  ],
}

install_packages_on(hosts, PACKAGES, :check_if_exists => true)

hosts.each do |host|
  if host['platform'] =~ /windows/
    step "#{host} Install ruby from git"
    install_from_git(host, "/opt/puppet-git-repos", :name => 'puppet-win32-ruby', :path => 'git://github.com/puppetlabs/puppet-win32-ruby')
    on host, 'cd /opt/puppet-git-repos/puppet-win32-ruby; cp -r ruby/* /'
    on host, 'cd /lib; icacls ruby /grant "Everyone:(OI)(CI)(RX)"'
    on host, 'cd /lib; icacls ruby /reset /T'
    on host, 'ruby --version'
    on host, 'cmd /c gem list'
  end
end
