# frozen_string_literal: true

# dnfmodule - A puppet package provider for DNF modules
#
# Installing a module:
#  package { 'postgresql':
#   provider => 'dnfmodule',
#   ensure   => '9.6',  # install a specific stream
#   flavor   => 'client',  # install a specific profile
# }

require_relative '../../../puppet/provider/package'

Puppet::Type.type(:package).provide :dnfmodule, :parent => :dnf do
  has_feature :installable, :uninstallable, :versionable, :supports_flavors, :disableable
  # has_feature :upgradeable
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
    cmd = "#{command(:dnf)} module list -d 0 -e #{error_level}"
    execute(cmd).each_line do |line|
      # select only lines with actual packages since DNF clutters the output
      next unless line =~ /\[[eix]\][, ]/

      line.gsub!(/\[d\]/, '') # we don't care about the default flag

      flavor = if line.include?('[i]')
                 line.split('[i]').first.split.last
               else
                 :absent
               end

      packages << new(
        name: line.split[0],
        ensure: if line.include?('[x]')
                  :disabled
                else
                  line.split[1]
                end,
        flavor: flavor,
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

  # to install specific streams and profiles:
  # $ dnf module install module-name:stream/profile
  # $ dnf module install perl:5.24/minimal
  # if unspecified, they will be defaulted (see [d] param in dnf module list output)
  def install
    # ensure we start fresh (remove existing stream)
    uninstall unless [:absent, :purged].include?(@property_hash[:ensure])

    args = @resource[:name].dup
    case @resource[:ensure]
    when true, false, Symbol
      # pass
    else
      args << ":#{@resource[:ensure]}"
    end
    args << "/#{@resource[:flavor]}" if @resource[:flavor]

    if @resource[:enable_only] == true
      enable(args)
    else
      begin
        execute([command(:dnf), 'module', 'install', '-d', '0', '-e', self.class.error_level, '-y', args])
      rescue Puppet::ExecutionFailure => e
        # module has no default profile and no profile was requested, so just enable the stream
        # DNF versions prior to 4.2.8 do not need this workaround
        # see https://bugzilla.redhat.com/show_bug.cgi?id=1669527
        if @resource[:flavor].nil? && e.message =~ /^(?:missing|broken) groups or modules: #{Regexp.quote(args)}$/
          enable(args)
        else
          raise
        end
      end
    end
  end

  # should only get here when @resource[ensure] is :disabled
  def insync?(is)
    if resource[:ensure] == :disabled
      # in sync only if package is already disabled
      pkg = self.class.instances.find do |package|
        @resource[:name] == package.name && package.properties[:ensure] == :disabled
      end
      return true if pkg
    end
    return false
  end

  def enable(args = @resource[:name])
    execute([command(:dnf), 'module', 'enable', '-d', '0', '-e', self.class.error_level, '-y', args])
  end

  def uninstall
    execute([command(:dnf), 'module', 'remove', '-d', '0', '-e', self.class.error_level, '-y', @resource[:name]])
    reset # reset module to the default stream
  end

  def disable(args = @resource[:name])
    execute([command(:dnf), 'module', 'disable', '-d', '0', '-e', self.class.error_level, '-y', args])
  end

  def reset
    execute([command(:dnf), 'module', 'reset', '-d', '0', '-e', self.class.error_level, '-y', @resource[:name]])
  end

  def flavor
    @property_hash[:flavor]
  end

  def flavor=(value)
    install if flavor != @resource.should(:flavor)
  end
end
