# frozen_string_literal: true

require_relative '../../puppet'
require_relative '../../puppet/file_serving'
require_relative '../../puppet/file_serving/mount'
require_relative '../../puppet/file_serving/mount/file'
require_relative '../../puppet/file_serving/mount/modules'
require_relative '../../puppet/file_serving/mount/plugins'
require_relative '../../puppet/file_serving/mount/locales'
require_relative '../../puppet/file_serving/mount/pluginfacts'
require_relative '../../puppet/file_serving/mount/scripts'
require_relative '../../puppet/file_serving/mount/tasks'

class Puppet::FileServing::Configuration
  require_relative 'configuration/parser'

  def self.configuration
    @configuration ||= new
  end

  Mount = Puppet::FileServing::Mount

  private_class_method :new

  attr_reader :mounts

  # private :mounts

  # Find the right mount.  Does some shenanigans to support old-style module
  # mounts.
  def find_mount(mount_name, environment)
    # Reparse the configuration if necessary.
    readconfig
    # This can be nil.
    mounts[mount_name]
  end

  def initialize
    @mounts = {}
    @config_file = nil

    # We don't check to see if the file is modified the first time,
    # because we always want to parse at first.
    readconfig(false)
  end

  # Is a given mount available?
  def mounted?(name)
    @mounts.include?(name)
  end

  # Split the path into the separate mount point and path.
  def split_path(request)
    # Reparse the configuration if necessary.
    readconfig

    mount_name, path = request.key.split(File::Separator, 2)

    raise(ArgumentError, _("Cannot find file: Invalid mount '%{mount_name}'") % { mount_name: mount_name }) unless mount_name =~ /^[-\w]+$/
    raise(ArgumentError, _("Cannot find file: Invalid relative path '%{path}'") % { path: path }) if path and path.split('/').include?('..')

    mount = find_mount(mount_name, request.environment)
    return nil unless mount

    if mount.name == "modules" and mount_name != "modules"
      # yay backward-compatibility
      path = "#{mount_name}/#{path}"
    end

    if path == ""
      path = nil
    elsif path
      # Remove any double slashes that might have occurred
      path = path.gsub(%r{/+}, "/")
    end

    [mount, path]
  end

  def umount(name)
    @mounts.delete(name) if @mounts.include? name
  end

  private

  def mk_default_mounts
    @mounts["modules"] ||= Mount::Modules.new("modules")
    @mounts["plugins"] ||= Mount::Plugins.new("plugins")
    @mounts["locales"] ||= Mount::Locales.new("locales")
    @mounts["pluginfacts"] ||= Mount::PluginFacts.new("pluginfacts")
    @mounts["scripts"] ||= Mount::Scripts.new("scripts")
    @mounts["tasks"] ||= Mount::Tasks.new("tasks")
  end

  # Read the configuration file.
  def readconfig(check = true)
    config = Puppet[:fileserverconfig]

    return unless Puppet::FileSystem.exist?(config)

    @parser ||= Puppet::FileServing::Configuration::Parser.new(config)

    return if check and !@parser.changed?

    # Don't assign the mounts hash until we're sure the parsing succeeded.
    begin
      newmounts = @parser.parse
      @mounts = newmounts
    rescue => detail
      Puppet.log_exception(detail, _("Error parsing fileserver configuration: %{detail}; using old configuration") % { detail: detail })
    end
  ensure
    # Make sure we've got our plugins and modules.
    mk_default_mounts
  end
end
