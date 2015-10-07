# A file.
class Puppet::Settings::FileSetting < Puppet::Settings::StringSetting
  class SettingError < StandardError; end

  # An unspecified user or group
  #
  # @api private
  class Unspecified
    def value
      nil
    end
  end

  # A "root" user or group
  #
  # @api private
  class Root
    def value
      "root"
    end
  end

  # A "service" user or group that picks up values from settings when the
  # referenced user or group is safe to use (it exists or will be created), and
  # uses the given fallback value when not safe.
  #
  # @api private
  class Service
    # @param name [Symbol] the name of the setting to use as the service value
    # @param fallback [String, nil] the value to use when the service value cannot be used
    # @param settings [Puppet::Settings] the puppet settings object
    # @param available_method [Symbol] the name of the method to call on
    #   settings to determine if the value in settings is available on the system
    #
    def initialize(name, fallback, settings, available_method)
      @settings = settings
      @available_method = available_method
      @name = name
      @fallback = fallback
    end

    def value
      if safe_to_use_settings_value?
        @settings[@name]
      else
        @fallback
      end
    end

  private
    def safe_to_use_settings_value?
      @settings[:mkusers] or @settings.send(@available_method)
    end
  end

  attr_accessor :mode, :create

  def initialize(args)
    @group = Unspecified.new
    @owner = Unspecified.new
    super(args)
  end

  # Should we create files, rather than just directories?
  def create_files?
    create
  end

  # @param value [String] the group to use on the created file (can only be "root" or "service")
  # @api public
  def group=(value)
    @group = case value
             when "root"
               Root.new
             when "service"
               # Group falls back to `nil` because we cannot assume that a "root" group exists.
               # Some systems have root group, others have wheel, others have something else.
               Service.new(:group, nil, @settings, :service_group_available?)
             else
               unknown_value(':group', value)
             end
  end

  # @param value [String] the owner to use on the created file (can only be "root" or "service")
  # @api public
  def owner=(value)
    @owner = case value
             when "root"
               Root.new
             when "service"
               Service.new(:user, "root", @settings, :service_user_available?)
             else
               unknown_value(':owner', value)
             end
  end

  # @return [String, nil] the name of the group to use for the file or nil if the group should not be managed
  # @api public
  def group
    @group.value
  end

  # @return [String, nil] the name of the user to use for the file or nil if the user should not be managed
  # @api public
  def owner
    @owner.value
  end

  def set_meta(meta)
    self.owner = meta.owner if meta.owner
    self.group = meta.group if meta.group
    self.mode = meta.mode if meta.mode
  end

  def munge(value)
    if value.is_a?(String) and value != ':memory:' # for sqlite3 in-memory tests
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

    return nil unless type == :directory or create_files? or Puppet::FileSystem.exist?(path)
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

  # @api private
  def exclusive_open(option = 'r', &block)
    controlled_access do |mode|
      Puppet::FileSystem.exclusive_open(file(), mode, option, &block)
    end
  end

  # @api private
  def open(option = 'r', &block)
    controlled_access do |mode|
      Puppet::FileSystem.open(file, mode, option, &block)
    end
  end

  private

  def file
    Puppet::FileSystem.pathname(value)
  end

  def unknown_value(parameter, value)
    raise SettingError, "The #{parameter} parameter for the setting '#{name}' must be either 'root' or 'service', not '#{value}'"
  end

  def controlled_access(&block)
    chown = nil
    if Puppet.features.root?
      chown = [owner, group]
    else
      chown = [nil, nil]
    end

    Puppet::Util::SUIDManager.asuser(*chown) do
      # Update the umask to make non-executable files
      Puppet::Util.withumask(File.umask ^ 0111) do
        yielded_value = case self.mode
                        when String
                          self.mode.to_i(8)
                        when NilClass
                          0640
                        else
                          self.mode
                        end

        yield yielded_value
      end
    end
  end
end
