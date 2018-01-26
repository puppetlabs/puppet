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
    'rubygem-json',       # invalid on RHEL6
    'rubygem-io-console', # required for Fedora25 to bundle install
    'rubygem-rdoc'        # required for Fedora25 to install gems
  ],
  :debian => [
    ['git', 'git-core'],
    'ruby',
  ],
  :debian_ruby18 => [
    'libjson-ruby',
  ],
  # necessary to build Ruby on SLES11 which ships 1.8.7
  :sles_11 => [
    'git',
    'make',
    'gcc',
    'openssl',
    'openssl-devel',
    # 'zlib',
    'zlib-devel'
  ],
  :solaris_11 => [
    ['git', 'developer/versioning/git'],
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

UNSUPPORTED_PLATFORMS = [
  /sles-10/, # requires building git
]

hosts.each do |host|
  if UNSUPPORTED_PLATFORMS.any? { |p| host['platform'] =~ p }
    raise "ci:test:git is not currently suported on #{host['platform']}"
  end
end

# override incorrect FOSS (git) defaults from Beaker with AIO applicable ones
#
# Remove after PUP-4867 breaks distmoduledir and sitemoduledir into individual
# settings from modulepath and Beaker can properly introspect these settings
hosts.each do |host|
  platform = host['platform'] =~ /windows/ ? 'windows' : 'unix'

  host['puppetbindir'] = '/usr/bin' if platform == 'windows'

  if host['platform'] =~ /osx|sles/
    # because of OSX SIP, /usr/bin is not writable and /usr/local/bin is preferred
    host['puppetbindir'] = '/usr/local/bin'
  end

  if platform == 'unix'
    backup_extension = "''" if host['platform'] =~ /osx/

    # inject /usr/local/bin into ~/.ssh/environment until BKR-1139 is released
    # this helps to resolve bundle, puppet and other Ruby binstubs // no restart necessary
    on host, "sed -i #{backup_extension} \"s/^PATH=PATH:/PATH=PATH:\\/usr\\/local\\/bin:/\" ~/.ssh/environment"

    # TODO: the above doesn't work right on SLES - only way to get /usr/local/bin early in path is to add ~/.bashrc like
    # PATH=/usr/local/bin:$PATH
    on host, "echo 'PATH=/usr/local/bin:$PATH' > ~/.bashrc"
  end

  # Beakers add_aio_defaults_on helper is not appropriate here as it
  # also alters puppetbindir / privatebindir to use package installed
  # paths rather than git installed paths
  host['distmoduledir'] = AIO_DEFAULTS[platform]['distmoduledir']
  host['sitemoduledir'] = AIO_DEFAULTS[platform]['sitemoduledir']
end

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
  when /solaris-11/
    step "#{host} jump through hoops to install ruby19; switch back to runtime/ruby-19 after template upgrade to sol11.2"
    create_remote_file host, "/root/shutupsolaris", <<END
mail=
# Overwrite already installed instances
instance=overwrite
# Do not bother checking for partially installed packages
partial=nocheck
# Do not bother checking the runlevel
runlevel=nocheck
# Do not bother checking package dependencies (We take care of this)
idepend=nocheck
rdepend=nocheck
# DO check for available free space and abort if there isn't enough
space=quit
# Do not check for setuid files.
setuid=nocheck
# Do not check if files conflict with other packages
conflict=nocheck
# We have no action scripts.  Do not check for them.
action=nocheck
# Install to the default base directory.
basedir=default
END
    on host, 'pkgadd -a /root/shutupsolaris -d http://get.opencsw.org/now all'
    on host, '/opt/csw/bin/pkgutil -U all'
    on host, '/opt/csw/bin/pkgutil -i -y ruby19_dev'
    on host, '/opt/csw/bin/pkgutil -i -y ruby19'
    on host, 'ln -sf /opt/csw/bin/gem19 /usr/bin/gem'
    on host, 'ln -sf /opt/csw/bin/ruby19 /usr/bin/ruby'
  end
end

install_packages_on(hosts, PACKAGES, :check_if_exists => true)

hosts.each do |host|
  case host['platform']
  when /windows/
    arch = host[:ruby_arch] || 'x86'
    step "#{host} Selected architecture #{arch}"

    revision = if arch == 'x64'
                 '2.1.x-x64'
               else
                 '2.1.x-x86'
               end

    step "#{host} Install ruby from git using revision #{revision}"
    # TODO remove this step once we are installing puppet from msi packages
    win_path = on(host, 'cygpath -m /opt/puppet-git-repos').stdout.chomp
    install_from_git_on(host, win_path,
                     :name => 'puppet-win32-ruby',
                     :path => build_git_url('puppet-win32-ruby'),
                     :rev  => revision)
    on host, 'cd /opt/puppet-git-repos/puppet-win32-ruby; cp -r ruby/* /'
    on host, 'cd /lib; icacls ruby /grant "Everyone:(OI)(CI)(RX)"'
    on host, 'cd /lib; icacls ruby /reset /T'
    on host, 'cd /; icacls bin /grant "Everyone:(OI)(CI)(RX)"'
    on host, 'cd /; icacls bin /reset /T'
    on host, 'ruby --version'
    on host, 'cmd /c gem list'
  when /sles-11/
    ruby_version = '2.4.1'

    step "#{host} Build ruby #{ruby_version} from source"

    on host, "wget http://buildsources.delivery.puppetlabs.net/ruby-#{ruby_version}.tar.gz"
    on host, "tar xfvz ruby-#{ruby_version}.tar.gz"
    on host, "cd ~/ruby-#{ruby_version} && ./configure"
    on host, "cd ~/ruby-#{ruby_version} && make"
    on host, "cd ~/ruby-#{ruby_version} && sudo make install"
  end
end

# Only configure gem mirror after Ruby has been installed, but before any gems are installed.
configure_gem_mirror(hosts)

hosts.each do |host|
  case host['platform']
  when /solaris/
    step "#{host} Install json from rubygems"
    on host, 'gem install json_pure --no-ri --no-rdoc --version 1.8.3' # json_pure 2.0 requires ruby 2
    on host, 'gem install bundler --no-ri --no-rdoc'
    on host, "ln -sf /opt/csw/bin/bundle #{host['puppetbindir']}/bundle"
  when /windows/
    on host, 'cmd /c gem install bundler --no-ri --no-rdoc'
  else
    on host, 'gem install bundler --no-ri --no-rdoc'
  end
end
