require 'puppet/settings/string_setting'

# A file.
class Puppet::Settings::FileSetting < Puppet::Settings::StringSetting
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

  def munge(value)
    if value.is_a?(String)
      value = File.expand_path(value)
    end
    value
  end

  def type
    :file
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
      if self.mode
        # This ends up mimicking the munge method of the mode
        # parameter to make sure that we're always passing the string
        # version of the octal number.  If we were setting the
        # 'should' value for mode rather than the 'is', then the munge
        # method would be called for us automatically.  Normally, one
        # wouldn't need to call the munge method manually, since
        # 'should' gets set by the provider and it should be able to
        # provide the data in the appropriate format.
        mode = self.mode
        mode = mode.to_i(8) if mode.is_a?(String)
        mode = mode.to_s(8)
        resource[:mode] = mode
      end

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
