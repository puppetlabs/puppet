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
  :solaris_11 => [
    ['git', 'developer/versioning/git'],
    ['ruby', 'runtime/ruby-19'],
    # there isn't a package for json, so it is installed later via gems
  ],
  :solaris_10 => [
    'coreutils',
    'curl', # update curl to fix "CURLOPT_SSL_VERIFYHOST no longer supports 1 as value!" issue
    'git',
    'ruby19',
    'ruby19_dev',
    'gcc4core',
  ],
  :windows => [
    'git',
    # there isn't a need for json on windows because it is bundled in ruby 1.9
  ],
}

hosts.each do |host|
  case host['platform']
  when  /solaris-10/
    on host, 'mkdir -p /var/lib'
    on host, 'ln -sf /opt/csw/bin/pkgutil /usr/bin/pkgutil'
    on host, 'ln -sf /opt/csw/bin/gem19 /usr/bin/gem'
    on host, 'ln -sf /opt/csw/bin/git /usr/bin/git'
    on host, 'ln -sf /opt/csw/bin/ruby19 /usr/bin/ruby'
    on host, 'ln -sf /opt/csw/bin/gstat /usr/bin/stat'
    on host, 'ln -sf /opt/csw/bin/greadlink /usr/bin/readlink'
  end
end

install_packages_on(hosts, PACKAGES, :check_if_exists => true)

hosts.each do |host|
  case host['platform']
  when /windows/
    arch = host[:ruby_arch] || 'x86'
    step "#{host} Selected architecture #{arch}"

    revision = if arch == 'x64'
                 '2.0.0-x64'
               else
                 '1.9.3-x86'
               end

    step "#{host} Install ruby from git using revision #{revision}"
    # TODO remove this step once we are installing puppet from msi packages
    install_from_git(host, "/opt/puppet-git-repos",
                     :name => 'puppet-win32-ruby',
                     :path => build_giturl('puppet-win32-ruby'),
                     :rev  => revision)
    on host, 'cd /opt/puppet-git-repos/puppet-win32-ruby; cp -r ruby/* /'
    on host, 'cd /lib; icacls ruby /grant "Everyone:(OI)(CI)(RX)"'
    on host, 'cd /lib; icacls ruby /reset /T'
    on host, 'cd /; icacls bin /grant "Everyone:(OI)(CI)(RX)"'
    on host, 'cd /; icacls bin /reset /T'
    on host, 'ruby --version'
    on host, 'cmd /c gem list'
  when /solaris-10/
    step "#{host} Install json from rubygems"
    on host, 'gem install json_pure'
  when /solaris-11/
    step "#{host} Install json from rubygems"
    on host, 'gem install json_pure'
  end
end
