# frozen_string_literal: true

require_relative '../../../puppet/file_serving/configuration'
require_relative '../../../puppet/util/watched_file'

class Puppet::FileServing::Configuration::Parser
  Mount = Puppet::FileServing::Mount
  MODULES = 'modules'

  # Parse our configuration file.
  def parse
    raise(_("File server configuration %{config_file} does not exist") % { config_file: @file }) unless Puppet::FileSystem.exist?(@file)
    raise(_("Cannot read file server configuration %{config_file}") % { config_file: @file }) unless FileTest.readable?(@file)

    @mounts = {}
    @count = 0

    File.open(@file) do |f|
      mount = nil
      f.each_line do |line|
        # Have the count increment at the top, in case we throw exceptions.
        @count += 1

        case line
        when /^\s*#/; next # skip comments
        when /^\s*$/; next # skip blank lines
        when /\[([-\w]+)\]/
          mount = newmount(::Regexp.last_match(1))
        when /^\s*(\w+)\s+(.+?)(\s*#.*)?$/
          var = ::Regexp.last_match(1)
          value = ::Regexp.last_match(2)
          value.strip!
          raise(ArgumentError, _("Fileserver configuration file does not use '=' as a separator")) if value =~ /^=/

          case var
          when "path"
            path(mount, value)
          when "allow", "deny"
            # ignore `allow *`, otherwise report error
            if var != 'allow' || value != '*'
              error_location_str = Puppet::Util::Errors.error_location(@file.filename, @count)
              Puppet.err("Entry '#{line.chomp}' is unsupported and will be ignored at #{error_location_str}")
            end
          else
            error_location_str = Puppet::Util::Errors.error_location(@file.filename, @count)
            raise ArgumentError.new(_("Invalid argument '%{var}' at %{error_location}") %
                                        { var: var, error_location: error_location_str })
          end
        else
          error_location_str = Puppet::Util::Errors.error_location(@file.filename, @count)
          raise ArgumentError.new(_("Invalid entry at %{error_location}: '%{file_text}'") %
                                      { file_text: line.chomp, error_location: error_location_str })
        end
      end
    end

    validate

    @mounts
  end

  def initialize(filename)
    @file = Puppet::Util::WatchedFile.new(filename)
  end

  def changed?
    @file.changed?
  end

  private

  # Create a new mount.
  def newmount(name)
    if @mounts.include?(name)
      error_location_str = Puppet::Util::Errors.error_location(@file, @count)
      raise ArgumentError.new(_("%{mount} is already mounted at %{name} at %{error_location}") %
                                  { mount: @mounts[name], name: name, error_location: error_location_str })
    end
    case name
    when "modules"
      mount = Mount::Modules.new(name)
    when "plugins"
      mount = Mount::Plugins.new(name)
    when "scripts"
      mount = Mount::Scripts.new(name)
    when "tasks"
      mount = Mount::Tasks.new(name)
    when "locales"
      mount = Mount::Locales.new(name)
    else
      mount = Mount::File.new(name)
    end
    @mounts[name] = mount
    mount
  end

  # Set the path for a mount.
  def path(mount, value)
    if mount.respond_to?(:path=)
      begin
        mount.path = value
      rescue ArgumentError => detail
        Puppet.log_exception(detail, _("Removing mount \"%{mount}\": %{detail}") % { mount: mount.name, detail: detail })
        @mounts.delete(mount.name)
      end
    else
      Puppet.warning _("The '%{mount}' module can not have a path. Ignoring attempt to set it") % { mount: mount.name }
    end
  end

  # Make sure all of our mounts are valid.  We have to do this after the fact
  # because details are added over time as the file is parsed.
  def validate
    @mounts.each { |_name, mount| mount.validate }
  end
end
