require 'puppet/settings/errors'

# The base setting type
class Puppet::Settings::BaseSetting
  attr_accessor :name, :desc, :section, :default, :call_hook
  attr_reader :short, :deprecated

  def self.available_call_hook_values
    [:on_define_and_write, :on_initialize_and_write, :on_write_only]
  end

  def call_hook=(value)
    if value.nil?
      Puppet.warning "Setting :#{name} :call_hook is nil, defaulting to :on_write_only"
      value = :on_write_only
    end
    raise ArgumentError, "Invalid option #{value} for call_hook" unless self.class.available_call_hook_values.include? value
    @call_hook = value
  end

  def call_hook_on_define?
    call_hook == :on_define_and_write
  end

  def call_hook_on_initialize?
    call_hook == :on_initialize_and_write
  end

  # get the arguments in getopt format
  def getopt_args
    if short
      [["--#{name}", "-#{short}", GetoptLong::REQUIRED_ARGUMENT]]
    else
      [["--#{name}", GetoptLong::REQUIRED_ARGUMENT]]
    end
  end

  # get the arguments in OptionParser format
  def optparse_args
    if short
      ["--#{name}", "-#{short}", desc, :REQUIRED]
    else
      ["--#{name}", desc, :REQUIRED]
    end
  end

  def hook=(block)
    @has_hook = true
    meta_def :handle, &block
  end

  def has_hook?
    @has_hook
  end

  # Create the new element.  Pretty much just sets the name.
  def initialize(args = {})
    unless @settings = args.delete(:settings)
      raise ArgumentError.new("You must refer to a settings object")
    end

    # explicitly set name prior to calling other param= methods to provide meaningful feedback during
    # other warnings
    @name = args[:name] if args.include? :name

    #set the default value for call_hook
    @call_hook = :on_write_only if args[:hook] and not args[:call_hook]
    @has_hook = false

    raise ArgumentError, "Cannot reference :call_hook for :#{@name} if no :hook is defined" if args[:call_hook] and not args[:hook]

    args.each do |param, value|
      method = param.to_s + "="
      raise ArgumentError, "#{self.class} (setting '#{args[:name]}') does not accept #{param}" unless self.respond_to? method

      self.send(method, value)
    end

    raise ArgumentError, "You must provide a description for the #{self.name} config option" unless self.desc
  end

  def iscreated
    @iscreated = true
  end

  def iscreated?
    @iscreated
  end

  # short name for the celement
  def short=(value)
    raise ArgumentError, "Short names can only be one character." if value.to_s.length != 1
    @short = value.to_s
  end

  def default(check_application_defaults_first = false)
    if @default.is_a? Proc
      # Give unit tests a chance to reevaluate the call by removing the instance variable
      unless instance_variable_defined?(:@evaluated_default)
        @evaluated_default = @default.call
      end
      default_value = @evaluated_default
    else
      default_value = @default
    end
    return default_value unless check_application_defaults_first
    return @settings.value(name, :application_defaults, true) || default_value
  end

  # Convert the object to a config statement.
  def to_config
    require 'puppet/util/docs'
    # Scrub any funky indentation; comment out description.
    str = Puppet::Util::Docs.scrub(@desc).gsub(/^/, "# ") + "\n"

    # Add in a statement about the default.
    str << "# The default value is '#{default(true)}'.\n" if default(true)

    # If the value has not been overridden, then print it out commented
    # and unconverted, so it's clear that that's the default and how it
    # works.
    value = @settings.value(self.name)

    if value != @default
      line = "#{@name} = #{value}"
    else
      line = "# #{@name} = #{@default}"
    end

    str << (line + "\n")

    # Indent
    str.gsub(/^/, "    ")
  end

  # @param bypass_interpolation [Boolean] Set this true to skip the
  #   interpolation step, returning the raw setting value.  Defaults to false.
  # @return [String] Retrieves the value, or if it's not set, retrieves the default.
  # @api public
  def value(bypass_interpolation = false)
    @settings.value(self.name, nil, bypass_interpolation)
  end

  # Modify the value when it is first evaluated
  def munge(value)
    value
  end

  def set_meta(meta)
    Puppet.notice("#{name} does not support meta data. Ignoring.")
  end

  def deprecated=(deprecation)
    raise(ArgumentError, "'#{deprecation}' is an unknown setting deprecation state.  Must be either :completely or :allowed_on_commandline") unless [:completely, :allowed_on_commandline].include?(deprecation)
    @deprecated = deprecation
  end

  def deprecated?
    !!@deprecated
  end

  # True if we should raise a deprecation_warning if the setting is submitted
  # on the commandline or is set in puppet.conf.
  def completely_deprecated?
    @deprecated == :completely
  end

  # True if we should raise a deprecation_warning if the setting is found in
  # puppet.conf, but not if the user sets it on the commandline
  def allowed_on_commandline?
    @deprecated == :allowed_on_commandline
  end

  def inspect
    %Q{<#{self.class}:#{self.object_id} @name="#{@name}" @section="#{@section}" @default="#{@default}" @call_hook="#{@call_hook}">}
  end
end
