test_name "Setup environment"

step "Ensure Git and Ruby"

require 'puppet/acceptance/install_utils'
extend Puppet::Acceptance::InstallUtils
require 'puppet/acceptance/git_utils'
extend Puppet::Acceptance::GitUtils
require 'beaker/dsl/install_utils'
extend Beaker::DSL::InstallUtils

PACKAGES = {
  :redhat => [
    'git',
    'ruby',
    'rubygem-json',
  ],
  :debian => [
    ['git', 'git-core'],
    'ruby',
  ],
  :debian_ruby18 => [
    'libjson-ruby',
  ],
  :solaris => [
    ['git', 'developer/versioning/git'],
    ['ruby', 'runtime/ruby-18'],
    # there isn't a package for json, so it is installed later via gems
  ],
  :windows => [
    'git',
    # there isn't a need for json on windows because it is bundled in ruby 1.9
  ],
}

install_packages_on(hosts, PACKAGES, :check_if_exists => true)

hosts.each do |host|
  case host['platform']
  when /windows/
    step "#{host} Install ruby from git"
    # TODO remove this step once we are installing puppet from msi packages
    install_from_git(host, "/opt/puppet-git-repos",
                     :name => 'puppet-win32-ruby',
                     :path => build_giturl('puppet-win32-ruby'))
    on host, 'cd /opt/puppet-git-repos/puppet-win32-ruby; cp -r ruby/* /'
    on host, 'cd /lib; icacls ruby /grant "Everyone:(OI)(CI)(RX)"'
    on host, 'cd /lib; icacls ruby /reset /T'
    on host, 'ruby --version'
    on host, 'cmd /c gem list'
  when /solaris/
    step "#{host} Install json from rubygems"
    on host, 'gem install json'
  end
end
