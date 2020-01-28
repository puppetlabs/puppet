# dnfmodule - A puppet package provider for DNF modules
#
# Installing a module:
#  package { 'postgresql':
#   provider => 'dnfmodule',
#   ensure   => '9.6',  # install a specific stream
#   flavor   => 'client',  # install a specific profile
# }


require 'puppet/provider/package'

Puppet::Type.type(:package).provide :dnfmodule, :parent => :dnf do

  has_feature :installable, :uninstallable, :versionable, :supports_flavors
  #has_feature :upgradeable
  # it's not (yet) feasible to make this upgradeable since module streams don't
  # always have matching version types (i.e. idm has streams DL1 and client,
  # other modules have semver streams, others have string streams... we cannot
  # programatically determine a latest version for ensure => 'latest'

  commands :dnf => '/usr/bin/dnf'

  def self.current_version
    @current_version ||= dnf('--version').split.first
  end

  def self.prefetch(packages)
    if Puppet::Util::Package.versioncmp(current_version, '3.0.1') < 0
      raise Puppet::Error, _("Modules are not supported on DNF versions lower than 3.0.1")
    end
    super
  end

  def self.instances
    packages = []
    cmd = "#{command(:dnf)} module list --installed -d 0 -e #{error_level}"
    execute(cmd).each_line do |line|
      next unless line =~ /\[i\][, ]/  # get rid of non-package lines (including last Hint line)
      line.gsub!(/\[[de]\]/, '')  # we don't care about default/enabled flags
      packages << new(
        name: line.split[0],
        ensure: line.split[1],
        flavor: line.split('[i]').first.split.last,  # this is nasty
        provider: name
      )
    end
    packages
  end

  def query
    pkg = self.class.instances.find do |package|
            @resource[:name] == package.name
          end
    pkg ? pkg.properties : nil
  end

  def reset
    execute([command(:dnf), 'module', 'reset', '-d', '0', '-e', self.class.error_level, '-y', @resource[:name]])
  end

  # to install specific streams and profiles:
  # $ dnf module install module-name:stream/profile
  # $ dnf module install perl:5.24/minimal
  # if unspecified, they will be defaulted (see [d] param in dnf module list output)
  def install
    args = @resource[:name]
    # ensure we start fresh (remove existing stream)
    uninstall unless [:absent, :purged].include?(@property_hash[:ensure])
    case @resource[:ensure]
    when true, false, Symbol
      # pass
    else
      args << ":#{@resource[:ensure]}"
    end
    if @resource[:flavor]
      args << "/#{@resource[:flavor]}"
    end
    execute([command(:dnf), 'module', 'install', '-d', '0', '-e', self.class.error_level, '-y', args])
  end

  def uninstall
    execute([command(:dnf), 'module', 'remove', '-d', '0', '-e', self.class.error_level, '-y', @resource[:name]])
    reset  # reset module to the default stream
  end

  def flavor
    @property_hash[:flavor]
  end

  def flavor=(value)
    install if flavor != @resource.should(:flavor)
  end
end
