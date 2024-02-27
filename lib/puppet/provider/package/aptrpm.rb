# frozen_string_literal: true

Puppet::Type.type(:package).provide :aptrpm, :parent => :rpm, :source => :rpm do
  # Provide sorting functionality
  include Puppet::Util::Package

  desc "Package management via `apt-get` ported to `rpm`."

  has_feature :versionable

  commands :aptget => "apt-get"
  commands :aptcache => "apt-cache"
  commands :rpm => "rpm"

  # Mixing confine statements, control expressions, and exception handling
  # confuses Rubocop's Layout cops, so we disable them entirely.
  # rubocop:disable Layout
  if command('rpm')
    confine :true => begin
      rpm('-ql', 'rpm')
      rescue Puppet::ExecutionFailure
        false
      else
        true
      end
  end
  # rubocop:enable Layout

  # Install a package using 'apt-get'.  This function needs to support
  # installing a specific version.
  def install
    should = @resource.should(:ensure)

    str = @resource[:name]
    case should
    when true, false, Symbol
      # pass
    else
      # Add the package version
      str += "=#{should}"
    end
    cmd = %w[-q -y]

    cmd << 'install' << str

    aptget(*cmd)
  end

  # What's the latest package version available?
  def latest
    output = aptcache :showpkg, @resource[:name]

    if output =~ /Versions:\s*\n((\n|.)+)^$/
      versions = Regexp.last_match(1)
      available_versions = versions.split(/\n/).filter_map { |version|
        if version =~ /^([^\(]+)\(/
          Regexp.last_match(1)
        else
          self.warning _("Could not match version '%{version}'") % { version: version }
          nil
        end
      }.sort { |a, b| versioncmp(a, b) }

      if available_versions.length == 0
        self.debug "No latest version"
        print output if Puppet[:debug]
      end

      # Get the latest and greatest version number
      return available_versions.pop
    else
      self.err _("Could not match string")
    end
  end

  def update
    self.install
  end

  def uninstall
    aptget "-y", "-q", 'remove', @resource[:name]
  end

  def purge
    aptget '-y', '-q', 'remove', '--purge', @resource[:name]
  end
end
