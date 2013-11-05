test_name "Setup environment"

step "Ensure Git and Ruby"

require 'puppet/acceptance/install_utils'
extend Puppet::Acceptance::InstallUtils

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
    on host, 'echo $PATH'
    on host, 'git clone https://github.com/puppetlabs/puppet-win32-ruby'
    on host, 'cp -r puppet-win32-ruby/ruby/* /'
    on host, 'cd /lib; icacls ruby /grant "Everyone:(OI)(CI)(RX)"'
    on host, 'cd /lib; icacls ruby /reset /T'
    on host, 'ruby --version'
    on host, 'cmd /c gem list'
  end
end
