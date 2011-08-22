require 'puppet/util/settings/setting'

# A file.
class Puppet::Util::Settings::FileSetting < Puppet::Util::Settings::Setting
  AllowedOwners = %w{root service}
  AllowedGroups = %w{root service}

  class SettingError < StandardError; end

  attr_accessor :mode, :create

  # Should we create files, rather than just directories?
  def create_files?
    create
  end

  def group=(value)
    unless AllowedGroups.include?(value)
      identifying_fields = [desc,name,default].compact.join(': ')
      raise SettingError, "Internal error: The :group setting for #{identifying_fields} must be 'service', not '#{value}'"
    end
    @group = value
  end

  def group
    return unless @group
    @settings[:group]
  end

  def owner=(value)
    unless AllowedOwners.include?(value)
      identifying_fields = [desc,name,default].compact.join(': ')
      raise SettingError, "Internal error: The :owner setting for #{identifying_fields} must be either 'root' or 'service', not '#{value}'"
    end
    @owner = value
  end

  def owner
    return unless @owner
    return "root" if @owner == "root" or ! use_service_user?
    @settings[:user]
  end

  def use_service_user?
    @settings[:mkusers] or @settings.service_user_available?
  end

  # Set the type appropriately.  Yep, a hack.  This supports either naming
  # the variable 'dir', or adding a slash at the end.
  def munge(value)
    # If it's not a fully qualified path...
    if value.is_a?(String) and value !~ /^\$/ and value != 'false'
      # Make it one
      value = File.expand_path(value)
    end
    if value.to_s =~ /\/$/
      @type = :directory
      return value.sub(/\/$/, '')
    end
    value
  end

  # Return the appropriate type.
  def type
    value = @settings.value(self.name)
    if @name.to_s =~ /dir/
      return :directory
    elsif value.to_s =~ /\/$/
      return :directory
    elsif value.is_a? String
      return :file
    else
      return nil
    end
  end

  # Turn our setting thing into a Puppet::Resource instance.
  def to_resource
    return nil unless type = self.type

    path = self.value

    return nil unless path.is_a?(String)

    # Make sure the paths are fully qualified.
    path = File.expand_path(path)

    return nil unless type == :directory or create_files? or File.exist?(path)
    return nil if path =~ /^\/dev/ or path =~ /^[A-Z]:\/dev/i

    resource = Puppet::Resource.new(:file, path)

    if Puppet[:manage_internal_file_permissions]
      resource[:mode] = self.mode if self.mode

      # REMIND fails on Windows because chown/chgrp functionality not supported yet
      if Puppet.features.root? and !Puppet.features.microsoft_windows?
        resource[:owner] = self.owner if self.owner
        resource[:group] = self.group if self.group
      end
    end

    resource[:ensure] = type
    resource[:loglevel] = :debug
    resource[:links] = :follow
    resource[:backup] = false

    resource.tag(self.section, self.name, "settings")

    resource
  end

  # Make sure any provided variables look up to something.
  def validate(value)
    return true unless value.is_a? String
    value.scan(/\$(\w+)/) { |name|
      name = $1
      unless @settings.include?(name)
        raise ArgumentError,
          "Settings parameter '#{name}' is undefined"
      end
    }
  end
end

