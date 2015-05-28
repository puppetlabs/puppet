# A Provider is an implementation of the actions that manage resources (of some type) on a system.
# This class is the base class for all implementation of a Puppet Provider.
#
# Concepts:
#--
# * **Confinement** - confinement restricts providers to only be applicable under certain conditions.
#    It is possible to confine a provider several different ways:
#    * the included {#confine} method which provides filtering on fact, feature, existence of files, or a free form
#      predicate.
#    * the {commands} method that filters on the availability of given system commands.
# * **Property hash** - the important instance variable `@property_hash` contains all current state values
#   for properties (it is lazily built). It is important that these values are managed appropriately in the
#   methods {instances}, {prefetch}, and in methods that alters the current state (those that change the
#   lifecycle (creates, destroys), or alters some value reflected backed by a property).
# * **Flush** - is a hook that is called once per resource when everything has been applied. The intent is
#   that an implementation may defer modification of the current state typically done in property setters
#   and instead record information that allows flush to perform the changes more efficiently.
# * **Execution Methods** -  The execution methods provides access to execution of arbitrary commands.
#   As a convenience execution methods are available on both the instance and the class of a provider since a
#   lot of provider logic switch between these contexts fairly freely.
# * **System Entity/Resource** - this documentation uses the term "system entity" for system resources to make
#   it clear if talking about a resource on the system being managed (e.g. a file in the file system)
#   or about a description of such a resource (e.g. a Puppet Resource).
# * **Resource Type** - this is an instance of Type that describes a classification of instances of Resource (e.g.
#   the `File` resource type describes all instances of `file` resources).
#   (The term is used to contrast with "type" in general, and specifically to contrast with the implementation
#   class of Resource or a specific Type).
#
# @note An instance of a Provider is associated with one resource.
#
# @note Class level methods are only called once to configure the provider (when the type is created), and not
#   for each resource the provider is operating on.
#   The instance methods are however called for each resource.
#
# @api public
#
class Puppet::Provider
  include Puppet::Util
  include Puppet::Util::Errors
  include Puppet::Util::Warnings
  extend Puppet::Util::Warnings

  require 'puppet/confiner'
  require 'puppet/provider/command'

  extend Puppet::Confiner

  Puppet::Util.logmethods(self, true)

  class << self
    # Include the util module so we have access to things like 'which'
    include Puppet::Util, Puppet::Util::Docs
    include Puppet::Util::Logging

    # @return [String] The name of the provider
    attr_accessor :name

    #
    # @todo Original = _"The source parameter exists so that providers using the same
    #   source can specify this, so reading doesn't attempt to read the
    #   same package multiple times."_ This seems to be a package type specific attribute. Is this really
    #   used?
    #
    # @return [???] The source is WHAT?
    attr_writer :source

    # @todo What is this type? A reference to a Puppet::Type ?
    # @return [Puppet::Type] the resource type (that this provider is ... WHAT?)
    #
    attr_accessor :resource_type

    # @!attribute [r] doc
    #   The (full) documentation for this provider class. The documentation for the provider class itself
    #   should be set with the DSL method {desc=}. Setting the documentation with with {doc=} has the same effect
    #   as setting it with {desc=} (only the class documentation part is set). In essence this means that
    #   there is no getter for the class documentation part (since the getter returns the full
    #   documentation when there are additional contributors).
    #
    #   @return [String] Returns the full documentation for the provider.
    # @see Puppet::Utils::Docs
    # @comment This is puzzling ... a write only doc attribute??? The generated setter never seems to be
    #   used, instead the instance variable @doc is set in the `desc` method. This seems wrong. It is instead
    #   documented as a read only attribute (to get the full documentation). Also see doc below for
    #   desc.
    # @!attribute [w] desc
    #   Sets the documentation of this provider class. (The full documentation is read via the
    #   {doc} attribute).
    #
    #   @dsl type
    #
    attr_writer :doc
  end

  # @return [???] This resource is what? Is an instance of a provider attached to one particular Puppet::Resource?
  #
  attr_accessor :resource

  # Convenience methods - see class method with the same name.
  # @see execute
  # @return (see execute)
  def execute(*args)
    Puppet::Util::Execution.execute(*args)
  end

  # (see Puppet::Util::Execution.execute)
  def self.execute(*args)
    Puppet::Util::Execution.execute(*args)
  end

  # Convenience methods - see class method with the same name.
  # @see execpipe
  # @return (see execpipe)
  def execpipe(*args, &block)
    Puppet::Util::Execution.execpipe(*args, &block)
  end

  # (see Puppet::Util::Execution.execpipe)
  def self.execpipe(*args, &block)
    Puppet::Util::Execution.execpipe(*args, &block)
  end

  # Convenience methods - see class method with the same name.
  # @see execfail
  # @return (see execfail)
  def execfail(*args)
    Puppet::Util::Execution.execfail(*args)
  end

  # (see Puppet::Util::Execution.execfail)
  def self.execfail(*args)
    Puppet::Util::Execution.execfail(*args)
  end

  # Returns the absolute path to the executable for the command referenced by the given name.
  # @raise [Puppet::DevError] if the name does not reference an existing command.
  # @return [String] the absolute path to the found executable for the command
  # @see which
  # @api public
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

  # Confines this provider to be suitable only on hosts where the given commands are present.
  # Also see {Puppet::Confiner#confine} for other types of confinement of a provider by use of other types of
  # predicates.
  #
  # @note It is preferred if the commands are not entered with absolute paths as this allows puppet
  #   to search for them using the PATH variable.
  #
  # @param command_specs [Hash{String => String}] Map of name to command that the provider will
  #   be executing on the system. Each command is specified with a name and the path of the executable.
  # @return [void]
  # @see optional_commands
  # @api public
  #
  def self.commands(command_specs)
    command_specs.each do |name, path|
      has_command(name, path)
    end
  end

  # Defines optional commands.
  # Since Puppet 2.7.8 this is typically not needed as evaluation of provider suitability
  # is lazy (when a resource is evaluated) and the absence of commands
  # that will be present after other resources have been applied no longer needs to be specified as
  # optional.
  # @param [Hash{String => String}] hash Named commands that the provider will
  #   be executing on the system. Each command is specified with a name and the path of the executable.
  # (@see #has_command)
  # @see commands
  # @api public
  def self.optional_commands(hash)
    hash.each do |name, target|
      has_command(name, target) do
        is_optional
      end
    end
  end

  # Creates a convenience method for invocation of a command.
  #
  # This generates a Provider method that allows easy execution of the command. The generated
  # method may take arguments that will be passed through to the executable as the command line arguments
  # when it is invoked.
  #
  # @example Use it like this:
  #   has_command(:echo, "/bin/echo")
  #   def some_method
  #     echo("arg 1", "arg 2")
  #   end
  # @comment the . . .  below is intentional to avoid the three dots to become an illegible ellipsis char.
  # @example . . . or like this
  #   has_command(:echo, "/bin/echo") do
  #     is_optional
  #     environment :HOME => "/var/tmp", :PWD => "/tmp"
  #   end
  #
  # @param name [Symbol] The name of the command (will become the name of the generated method that executes the command)
  # @param path [String] The path to the executable for the command
  # @yield [ ] A block that configures the command (see {Puppet::Provider::Command})
  # @comment a yield [ ] produces {|| ...} in the signature, do not remove the space.
  # @note the name ´has_command´ looks odd in an API context, but makes more sense when seen in the internal
  #   DSL context where a Provider is declaratively defined.
  # @api public
  #
  def self.has_command(name, path, &block)
    name = name.intern
    command = CommandDefiner.define(name, path, self, &block)

    @commands[name] = command.executable

    # Now define the class and instance methods.
    create_class_and_instance_method(name) do |*args|
      return command.execute(*args)
    end
  end

  # Internal helper class when creating commands - undocumented.
  # @api private
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

      Puppet::Provider::Command.new(@name, @path, Puppet::Util, Puppet::Util::Execution, { :failonfail => true, :combine => true, :custom_environment => @custom_environment })
    end
  end

  # @return [Boolean] Return whether the given feature has been declared or not.
  def self.declared_feature?(name)
    defined?(@declared_features) and @declared_features.include?(name)
  end

  # @return [Boolean] Returns whether this implementation satisfies all of the default requirements or not.
  #   Returns false if there is no matching defaultfor
  # @see Provider.defaultfor
  #
  def self.default?
    default_match ? true : false
  end

  # Look through the array of defaultfor hashes and return the first match.
  # @return [Hash<{String => Object}>] the matching hash specified by a defaultfor
  # @see Provider.defaultfor
  # @api private
  def self.default_match
    @defaults.find do |default|
      default.all? do |key, values|
        case key
          when :feature
            feature_match(values)
          else
            fact_match(key, values)
        end
      end
    end
  end

  def self.fact_match(fact, values)
    values = [values] unless values.is_a? Array
    values.map! { |v| v.to_s.downcase.intern }

    if fval = Facter.value(fact).to_s and fval != ""
      fval = fval.to_s.downcase.intern

      values.include?(fval)
    else
      false
    end
  end

  def self.feature_match(value)
    Puppet.features.send(value.to_s + "?")
  end

  # Sets a facts filter that determine which of several suitable providers should be picked by default.
  # This selection only kicks in if there is more than one suitable provider.
  # To filter on multiple facts the given hash may contain more than one fact name/value entry.
  # The filter picks the provider if all the fact/value entries match the current set of facts. (In case
  # there are still more than one provider after this filtering, the first found is picked).
  # @param hash [Hash<{String => Object}>] hash of fact name to fact value.
  # @return [void]
  #
  def self.defaultfor(hash)
    @defaults << hash
  end

  # @return [Integer] Returns a numeric specificity for this provider based on how many requirements it has
  #  and number of _ancestors_. The higher the number the more specific the provider.
  # The number of requirements is based on the hash size of the matching {Provider.defaultfor}.
  #
  # The _ancestors_ is the Ruby Module::ancestors method and the number of classes returned is used
  # to boost the score. The intent is that if two providers are equal, but one is more "derived" than the other
  # (i.e. includes more classes), it should win because it is more specific).
  # @note Because of how this value is
  #   calculated there could be surprising side effects if a provider included an excessive amount of classes.
  #
  def self.specificity
    # This strange piece of logic attempts to figure out how many parent providers there
    # are to increase the score. What is will actually do is count all classes that Ruby Module::ancestors
    # returns (which can be other classes than those the parent chain) - in a way, an odd measure of the
    # complexity of a provider).
    match = default_match
    length = match ? match.length : 0
    (length * 100) + ancestors.select { |a| a.is_a? Class }.length
  end

  # Initializes defaults and commands (i.e. clears them).
  # @return [void]
  def self.initvars
    @defaults = []
    @commands = {}
  end

  # Returns a list of system resources (entities) this provider may/can manage.
  # This is a query mechanism that lists entities that the provider may manage on a given system. It is
  # is directly used in query services, but is also the foundation for other services; prefetching, and
  # purging.
  #
  # As an example, a package provider lists all installed packages. (In contrast, the File provider does
  # not list all files on the file-system as that would make execution incredibly slow). An implementation
  # of this method should be made if it is possible to quickly (with a single system call) provide all
  # instances.
  #
  # An implementation of this method should only cache the values of properties
  # if they are discovered as part of the process for finding existing resources.
  # Resource properties that require additional commands (than those used to determine existence/identity)
  # should be implemented in their respective getter method. (This is important from a performance perspective;
  # it may be expensive to compute, as well as wasteful as all discovered resources may perhaps not be managed).
  #
  # An implementation may return an empty list (naturally with the effect that it is not possible to query
  # for manageable entities).
  #
  # By implementing this method, it is possible to use the `resources´ resource type to specify purging
  # of all non managed entities.
  #
  # @note The returned instances are instance of some subclass of Provider, not resources.
  # @return [Array<Puppet::Provider>] a list of providers referencing the system entities
  # @abstract this method must be implemented by a subclass and this super method should never be called as it raises an exception.
  # @raise [Puppet::DevError] Error indicating that the method should have been implemented by subclass.
  # @see prefetch
  def self.instances
    raise Puppet::DevError, "Provider #{self.name} has not defined the 'instances' class method"
  end

  # Creates getter- and setter- methods for each property supported by the resource type.
  # Call this method to generate simple accessors for all properties supported by the
  # resource type. These simple accessors lookup and sets values in the property hash.
  # The generated methods may be overridden by more advanced implementations if something
  # else than a straight forward getter/setter pair of methods is required.
  # (i.e. define such overriding methods after this method has been called)
  #
  # An implementor of a provider that makes use of `prefetch` and `flush` can use this method since it uses
  # the internal `@property_hash` variable to store values. An implementation would then update the system
  # state on a call to `flush` based on the current values in the `@property_hash`.
  #
  # @return [void]
  #
  def self.mk_resource_methods
    [resource_type.validproperties, resource_type.parameters].flatten.each do |attr|
      attr = attr.intern
      next if attr == :name
      define_method(attr) do
        if @property_hash[attr].nil?
          :absent
        else
          @property_hash[attr]
        end
      end

      define_method(attr.to_s + "=") do |val|
        @property_hash[attr] = val
      end
    end
  end

  self.initvars

  # This method is used to generate a method for a command.
  # @return [void]
  # @api private
  #
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

  # @return [String] Returns the data source, which is the provider name if no other source has been set.
  # @todo Unclear what "the source" is used for?
  def self.source
    @source ||= self.name
  end

  # Returns true if the given attribute/parameter is supported by the provider.
  # The check is made that the parameter is a valid parameter for the resource type, and then
  # if all its required features (if any) are supported by the provider.
  #
  # @param param [Class, Puppet::Parameter] the parameter class, or a parameter instance
  # @return [Boolean] Returns whether this provider supports the given parameter or not.
  # @raise [Puppet::DevError] if the given parameter is not valid for the resource type
  #
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

  dochook(:defaults) do
    if @defaults.length > 0
      return @defaults.collect do |d|
        "Default for " + d.collect do |f, v|
          "`#{f}` == `#{[v].flatten.join(', ')}`"
        end.sort.join(" and ") + "."
      end.join(" ")
    end
  end

  dochook(:commands) do
    if @commands.length > 0
      return "Required binaries: " + @commands.collect do |n, c|
        "`#{c}`"
      end.sort.join(", ") + "."
    end
  end

  dochook(:features) do
    if features.length > 0
      return "Supported features: " + features.collect do |f|
        "`#{f}`"
      end.sort.join(", ") + "."
    end
  end

  # Clears this provider instance to allow GC to clean up.
  def clear
    @resource = nil
  end

  # (see command)
  def command(name)
    self.class.command(name)
  end

  # Returns the value of a parameter value, or `:absent` if it is not defined.
  # @param param [Puppet::Parameter] the parameter to obtain the value of
  # @return [Object] the value of the parameter or `:absent` if not defined.
  #
  def get(param)
    @property_hash[param.intern] || :absent
  end

  # Creates a new provider that is optionally initialized from a resource or a hash of properties.
  # If no argument is specified, a new non specific provider is initialized. If a resource is given
  # it is remembered for further operations. If a hash is used it becomes the internal `@property_hash`
  # structure of the provider - this hash holds the current state property values of system entities
  # as they are being discovered by querying or other operations (typically getters).
  #
  # @todo The use of a hash as a parameter needs a better exaplanation; why is this done? What is the intent?
  # @param resource [Puppet::Resource, Hash] optional resource or hash
  #
  def initialize(resource = nil)
    if resource.is_a?(Hash)
      # We don't use a duplicate here, because some providers (ParsedFile, at least)
      # use the hash here for later events.
      @property_hash = resource
    elsif resource
      @resource = resource
      @property_hash = {}
    else
      @property_hash = {}
    end
  end

  # Returns the name of the resource this provider is operating on.
  # @return [String] the name of the resource instance (e.g. the file path of a File).
  # @raise [Puppet::DevError] if no resource is set, or no name defined.
  #
  def name
    if n = @property_hash[:name]
      return n
    elsif self.resource
      resource.name
    else
      raise Puppet::DevError, "No resource and no name in property hash in #{self.class.name} instance"
    end
  end

  # Sets the given parameters values as the current values for those parameters.
  # Other parameters are unchanged.
  # @param [Array<Puppet::Parameter>] params the parameters with values that should be set
  # @return [void]
  #
  def set(params)
    params.each do |param, value|
      @property_hash[param.intern] = value
    end
  end

  # @return [String] Returns a human readable string with information about the resource and the provider.
  def to_s
    "#{@resource}(provider=#{self.class.name})"
  end

  # @return [String] Returns a human readable string with information about the resource and the provider.
  def inspect
    to_s
  end

  # Makes providers comparable.
  include Comparable
  # Compares this provider against another provider.
  # Comparison is only possible with another provider (no other class).
  # The ordering is based on the class name of the two providers.
  #
  # @return [-1,0,+1, nil] A comparison result -1, 0, +1 if this is before other, equal or after other. Returns
  #   nil oif not comparable to other.
  # @see Comparable
  def <=>(other)
    # We can only have ordering against other providers.
    return nil unless other.is_a? Puppet::Provider
    # Otherwise, order by the providers class name.
    return self.class.name <=> other.class.name
  end

  # @comment Document prefetch here as it does not exist anywhere else (called from transaction if implemented)
  # @!method self.prefetch(resource_hash)
  # @abstract A subclass may implement this - it is not implemented in the Provider class
  # This method may be implemented by a provider in order to pre-fetch resource properties.
  # If implemented it should set the provider instance of the managed resources to a provider with the
  # fetched state (i.e. what is returned from the {instances} method).
  # @param resources_hash [Hash<{String => Puppet::Resource}>] map from name to resource of resources to prefetch
  # @return [void]
  # @api public

  # @comment Document post_resource_eval here as it does not exist anywhere else (called from transaction if implemented)
  # @!method self.post_resource_eval()
  # @since 3.4.0
  # @api public
  # @abstract A subclass may implement this - it is not implemented in the Provider class
  # This method may be implemented by a provider in order to perform any
  # cleanup actions needed.  It will be called at the end of the transaction if
  # any resources in the catalog make use of the provider, regardless of
  # whether the resources are changed or not and even if resource failures occur.
  # @return [void]

  # @comment Document flush here as it does not exist anywhere (called from transaction if implemented)
  # @!method flush()
  # @abstract A subclass may implement this - it is not implemented in the Provider class
  # This method may be implemented by a provider in order to flush properties that has not been individually
  # applied to the managed entity's current state.
  # @return [void]
  # @api public
end

