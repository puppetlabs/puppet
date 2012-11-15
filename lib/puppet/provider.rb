# The container class for implementations.
class Puppet::Provider
  include Puppet::Util
  include Puppet::Util::Errors
  include Puppet::Util::Warnings
  extend Puppet::Util::Warnings

  require 'puppet/provider/confiner'
  require 'puppet/provider/command'

  extend Puppet::Provider::Confiner

  Puppet::Util.logmethods(self, true)

  class << self
    # Include the util module so we have access to things like 'which'
    include Puppet::Util, Puppet::Util::Docs
    include Puppet::Util::Logging
    attr_accessor :name

    # The source parameter exists so that providers using the same
    # source can specify this, so reading doesn't attempt to read the
    # same package multiple times.
    attr_writer :source

    # LAK 2007-05-09: Keep the model stuff around for backward compatibility
    attr_reader :model
    attr_accessor :resource_type
    attr_writer :doc
  end

  # LAK 2007-05-09: Keep the model stuff around for backward compatibility
  attr_reader :model
  attr_accessor :resource

  # Provide access to execution of arbitrary commands in providers. Execution methods are
  # available on both the instance and the class of a provider because it seems that a lot of
  # providers switch between these contexts fairly freely.
  #
  # @see Puppet::Util::Execution for how to use these methods
  def execute(*args)
    Puppet::Util::Execution.execute(*args)
  end

  def self.execute(*args)
    Puppet::Util::Execution.execute(*args)
  end

  def execpipe(*args, &block)
    Puppet::Util::Execution.execpipe(*args, &block)
  end

  def self.execpipe(*args, &block)
    Puppet::Util::Execution.execpipe(*args, &block)
  end

  def execfail(*args)
    Puppet::Util::Execution.execfail(*args)
  end

  def self.execfail(*args)
    Puppet::Util::Execution.execfail(*args)
  end
  #########

  def self.command(name)
    name = name.intern

    if defined?(@commands) and command = @commands[name]
      # nothing
    elsif superclass.respond_to? :command and command = superclass.command(name)
      # nothing
    else
      raise Puppet::DevError, "No command #{name} defined for provider #{self.name}"
    end

    which(command)
  end

  # Define commands that are not optional.
  #
  # @param [Hash{String => String}] command_specs Named commands that the provider will 
  #   be executing on the system. Each command is specified with a name and the path of the executable.
  # (@see #has_command)
  def self.commands(command_specs)
    command_specs.each do |name, path|
      has_command(name, path)
    end
  end

  # Define commands that are optional.
  #
  # @param [Hash{String => String}] command_specs Named commands that the provider will 
  #   be executing on the system. Each command is specified with a name and the path of the executable.
  # (@see #has_command)
  def self.optional_commands(hash)
    hash.each do |name, target|
      has_command(name, target) do
        is_optional
      end
    end
  end

  # Define a single command
  #
  # A method will be generated on the provider that allows easy execution of the command. The generated 
  # method can take arguments that will be passed through to the executable as the command line arguments 
  # when it is run.
  #
  #     has_command(:echo, "/bin/echo")
  #     def some_method
  #       echo("arg 1", "arg 2")
  #     end
  #
  #     # or
  #
  #     has_command(:echo, "/bin/echo") do
  #       is_optional
  #       environment :HOME => "/var/tmp", :PWD => "/tmp"
  #     end
  #
  # @param [Symbol] name Name of the command (will be the name of the generated method to call the command)
  # @param [String] path The path to the executable for the command
  # @yield A block that configures the command (@see Puppet::Provider::Command) 
  def self.has_command(name, path, &block)
    name = name.intern
    command = CommandDefiner.define(name, path, self, &block)

    @commands[name] = command.executable

    # Now define the class and instance methods.
    create_class_and_instance_method(name) do |*args|
      return command.execute(*args)
    end
  end

  class CommandDefiner
    private_class_method :new

    def self.define(name, path, confiner, &block)
      definer = new(name, path, confiner)
      definer.instance_eval(&block) if block
      definer.command
    end

    def initialize(name, path, confiner)
      @name = name
      @path = path
      @optional = false
      @confiner = confiner
      @custom_environment = {}
    end

    def is_optional
      @optional = true
    end

    def environment(env)
      @custom_environment = @custom_environment.merge(env)
    end

    def command
      if not @optional
        @confiner.confine :exists => @path, :for_binary => true
      end

      Puppet::Provider::Command.new(@name, @path, Puppet::Util, Puppet::Util::Execution, { :custom_environment => @custom_environment })
    end
  end

  # Is the provided feature a declared feature?
  def self.declared_feature?(name)
    defined?(@declared_features) and @declared_features.include?(name)
  end

  # Does this implementation match all of the default requirements?  If
  # defaults are empty, we return false.
  def self.default?
    return false if @defaults.empty?
    if @defaults.find do |fact, values|
        values = [values] unless values.is_a? Array
        if fval = Facter.value(fact).to_s and fval != ""
          fval = fval.to_s.downcase.intern
        else
          return false
        end

        # If any of the values match, we're a default.
        if values.find do |value| fval == value.to_s.downcase.intern end
          false
        else
          true
        end
      end
      return false
    else
      return true
    end
  end

  # Store how to determine defaults.
  def self.defaultfor(hash)
    hash.each do |d,v|
      @defaults[d] = v
    end
  end

  def self.specificity
    (@defaults.length * 100) + ancestors.select { |a| a.is_a? Class }.length
  end

  def self.initvars
    @defaults = {}
    @commands = {}
  end

  # The method for returning a list of provider instances.  Note that it returns providers, preferably with values already
  # filled in, not resources.
  def self.instances
    raise Puppet::DevError, "Provider #{self.name} has not defined the 'instances' class method"
  end

  # Create the methods for a given command.
  #
  # @deprecated Use {#commands}, {#optional_commands}, or {#has_command} instead. This was not meant to be part of a public API
  def self.make_command_methods(name)
    Puppet.deprecation_warning "Provider.make_command_methods is deprecated; use Provider.commands or Provider.optional_commands instead for creating command methods"

    # Now define a method for that command
    unless singleton_class.method_defined?(name)
      meta_def(name) do |*args|
        # This might throw an ExecutionFailure, but the system above
        # will catch it, if so.
        command = Puppet::Provider::Command.new(name, command(name), Puppet::Util, Puppet::Util::Execution)
        return command.execute(*args)
      end

      # And then define an instance method that just calls the class method.
      # We need both, so both instances and classes can easily run the commands.
      unless method_defined?(name)
        define_method(name) do |*args|
          self.class.send(name, *args)
        end
      end
    end
  end

  # Create getter/setter methods for each property our resource type supports.
  # They all get stored in @property_hash.  This method is useful
  # for those providers that use prefetch and flush.
  def self.mk_resource_methods
    [resource_type.validproperties, resource_type.parameters].flatten.each do |attr|
      attr = attr.intern
      next if attr == :name
      define_method(attr) do
        @property_hash[attr] || :absent
      end

      define_method(attr.to_s + "=") do |val|
        @property_hash[attr] = val
      end
    end
  end

  self.initvars

  def self.create_class_and_instance_method(name, &block)
    unless singleton_class.method_defined?(name)
      meta_def(name, &block)
    end

    unless method_defined?(name)
      define_method(name) do |*args|
        self.class.send(name, *args)
      end
    end
  end
  private_class_method :create_class_and_instance_method

  # Retrieve the data source.  Defaults to the provider name.
  def self.source
    @source ||= self.name
  end

  # Does this provider support the specified parameter?
  def self.supports_parameter?(param)
    if param.is_a?(Class)
      klass = param
    else
      unless klass = resource_type.attrclass(param)
        raise Puppet::DevError, "'#{param}' is not a valid parameter for #{resource_type.name}"
      end
    end
    return true unless features = klass.required_features

    !!satisfies?(*features)
  end

#    def self.to_s
#        unless defined?(@str)
#            if self.resource_type
#                @str = "#{resource_type.name} provider #{self.name}"
#            else
#                @str = "unattached provider #{self.name}"
#            end
#        end
#        @str
#    end

  dochook(:defaults) do
    if @defaults.length > 0
      return "Default for " + @defaults.collect do |f, v|
        "`#{f}` == `#{[v].flatten.join(', ')}`"
      end.join(" and ") + "."
    end
  end

  dochook(:commands) do
    if @commands.length > 0
      return "Required binaries: " + @commands.collect do |n, c|
        "`#{c}`"
      end.join(", ") + "."
    end
  end

  dochook(:features) do
    if features.length > 0
      return "Supported features: " + features.collect do |f|
        "`#{f}`"
      end.join(", ") + "."
    end
  end

  # Remove the reference to the resource, so GC can clean up.
  def clear
    @resource = nil
    @model = nil
  end

  # Retrieve a named command.
  def command(name)
    self.class.command(name)
  end

  # Get a parameter value.
  def get(param)
    @property_hash[param.intern] || :absent
  end

  def initialize(resource = nil)
    if resource.is_a?(Hash)
      # We don't use a duplicate here, because some providers (ParsedFile, at least)
      # use the hash here for later events.
      @property_hash = resource
    elsif resource
      @resource = resource
      # LAK 2007-05-09: Keep the model stuff around for backward compatibility
      @model = resource
      @property_hash = {}
    else
      @property_hash = {}
    end
  end

  def name
    if n = @property_hash[:name]
      return n
    elsif self.resource
      resource.name
    else
      raise Puppet::DevError, "No resource and no name in property hash in #{self.class.name} instance"
    end
  end

  # Set passed params as the current values.
  def set(params)
    params.each do |param, value|
      @property_hash[param.intern] = value
    end
  end

  def to_s
    "#{@resource}(provider=#{self.class.name})"
  end

  # Make providers comparable.
  include Comparable
  def <=>(other)
    # We can only have ordering against other providers.
    return nil unless other.is_a? Puppet::Provider
    # Otherwise, order by the providers class name.
    return self.class.name <=> other.class.name
  end
end

