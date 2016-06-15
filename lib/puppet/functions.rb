# Functions in the puppet language can be written in Ruby and distributed in
# puppet modules. The function is written by creating a file in the module's
# `lib/puppet/functions/<modulename>` directory, where `<modulename>` is
# replaced with the module's name. The file should have the name of the function.
# For example, to create a function named `min` in a module named `math` create
# a file named `lib/puppet/functions/math/min.rb` in the module.
#
# A function is implemented by calling {Puppet::Functions.create_function}, and
# passing it a block that defines the implementation of the function.
#
# Functions are namespaced inside the module that contains them. The name of
# the function is prefixed with the name of the module. For example,
# `math::min`.
#
# @example A simple function
#   Puppet::Functions.create_function('math::min') do
#     def min(a, b)
#       a <= b ? a : b
#     end
#   end
#
# Anatomy of a function
# ---
#
# Functions are composed of four parts: the name, the implementation methods,
# the signatures, and the dispatches.
#
# The name is the string given to the {Puppet::Functions.create_function}
# method. It specifies the name to use when calling the function in the puppet
# language, or from other functions.
#
# The implementation methods are ruby methods (there can be one or more) that
# provide that actual implementation of the function's behavior. In the
# simplest case the name of the function (excluding any namespace) and the name
# of the method are the same. When that is done no other parts (signatures and
# dispatches) need to be used.
#
# Signatures are a way of specifying the types of the function's parameters.
# The types of any arguments will be checked against the types declared in the
# signature and an error will be produced if they don't match. The types are
# defined by using the same syntax for types as in the puppet language.
#
# Dispatches are how signatures and implementation methods are tied together.
# When the function is called, puppet searches the signatures for one that
# matches the supplied arguments. Each signature is part of a dispatch, which
# specifies the method that should be called for that signature. When a
# matching signature is found, the corresponding method is called.
#
# Documentation for the function should be placed as comments to the
# implementation method(s).
#
# @todo Documentation for individual instances of these new functions is not
#   yet tied into the puppet doc system.
#
# @example Dispatching to different methods by type
#   Puppet::Functions.create_function('math::min') do
#     dispatch :numeric_min do
#       param 'Numeric', :a
#       param 'Numeric', :b
#     end
#
#     dispatch :string_min do
#       param 'String', :a
#       param 'String', :b
#     end
#
#     def numeric_min(a, b)
#       a <= b ? a : b
#     end
#
#     def string_min(a, b)
#       a.downcase <= b.downcase ? a : b
#     end
#   end
#
# Specifying Signatures
# ---
#
# If nothing is specified, the number of arguments given to the function must
# be the same as the number of parameters, and all of the parameters are of
# type 'Any'.
#
# The following methods can be used to define a parameter
#
#  - _param_ - the argument must be given in the call.
#  - _optional_param_ - the argument may be missing in the call. May not be followed by a required parameter
#  - _repeated_param_ - the type specifies a repeating type that occurs 0 to "infinite" number of times. It may only appear last or just before a block parameter.
#  - _block_param_ - a block must be given in the call. May only appear last.
#  - _optional_block_param_ - a block may be given in the call. May only appear last.
#
# The method name _required_param_ is an alias for _param_ and _required_block_param_ is an alias for _block_param_
#
# A parameter definition takes 2 arguments:
#  - _type_ A string that must conform to a type in the puppet language
#  - _name_ A symbol denoting the parameter name
#
# Both arguments are optional when defining a block parameter. The _type_ defaults to "Callable"
# and the _name_ to :block.
#
# Note that the dispatch definition is used to match arguments given in a call to the function with the defined
# parameters. It then dispatches the call to the implementation method simply passing the given arguments on to
# that method without any further processing and it is the responsibility of that method's implementor to ensure
# that it can handle those arguments.
#
# @example Variable number of arguments
#   Puppet::Functions.create_function('foo') do
#     dispatch :foo do
#       param 'Numeric', :first
#       repeated_param 'Numeric', :values
#     end
#
#     def foo(first, *values)
#       # do something
#     end
#   end
#
# There is no requirement for direct mapping between parameter definitions and the parameters in the
# receiving implementation method so the following example is also legal. Here the dispatch will ensure
# that `*values` in the receiver will be an array with at least one entry of type String and that any
# remaining entries are of type Numeric:
#
# @example Inexact mapping or parameters
#   Puppet::Functions.create_function('foo') do
#     dispatch :foo do
#       param 'String', :first
#       repeated_param 'Numeric', :values
#     end
#
#     def foo(*values)
#       # do something
#     end
#   end
#
# Access to Scope
# ---
# In general, functions should not need access to scope; they should be
# written to act on their given input only. If they absolutely must look up
# variable values, they should do so via the closure scope (the scope where
# they are defined) - this is done by calling `closure_scope()`.
#
# Calling other Functions
# ---
# Calling other functions by name is directly supported via
# {Puppet::Pops::Functions::Function#call_function}. This allows a function to
# call other functions visible from its loader.
#
# @api public
module Puppet::Functions
  # @param func_name [String, Symbol] a simple or qualified function name
  # @param block [Proc] the block that defines the methods and dispatch of the
  #   Function to create
  # @return [Class<Function>] the newly created Function class
  #
  # @api public
  def self.create_function(func_name, function_base = Function, &block)
    # Ruby < 2.1.0 does not have method on Binding, can only do eval
    # and it will fail unless protected with an if defined? if the local
    # variable does not exist in the block's binder.
    #
    loader = block.binding.eval('loader_injected_arg if defined?(loader_injected_arg)')
    create_loaded_function(func_name, loader, function_base, &block)
  end

  # Creates a function in, or in a local loader under the given loader.
  # This method should only be used when manually creating functions 
  # for the sake of testing. Functions that are autoloaded should
  # always use the `create_function` method and the autoloader will supply
  # the correct loader.
  #
  # @param func_name [String, Symbol] a simple or qualified function name
  # @param loader [Puppet::Pops::Loaders::Loader] the loader loading the function
  # @param block [Proc] the block that defines the methods and dispatch of the
  #   Function to create
  # @return [Class<Function>] the newly created Function class
  #
  # @api public
  def self.create_loaded_function(func_name, loader, function_base = Function, &block)
    if function_base.ancestors.none? { |s| s == Puppet::Pops::Functions::Function }
      raise ArgumentError, "Functions must be based on Puppet::Pops::Functions::Function. Got #{function_base}"
    end

    func_name = func_name.to_s
    # Creates an anonymous class to represent the function
    # The idea being that it is garbage collected when there are no more
    # references to it.
    #
    # (Do not give the class the block here, as instance variables should be set first)
    the_class = Class.new(function_base)

    unless loader.nil?
      the_class.instance_variable_set(:'@loader', loader.private_loader)
    end

    # Make the anonymous class appear to have the class-name <func_name>
    # Even if this class is not bound to such a symbol in a global ruby scope and
    # must be resolved via the loader.
    # This also overrides any attempt to define a name method in the given block
    # (Since it redefines it)
    #
    # TODO, enforce name in lower case (to further make it stand out since Ruby
    # class names are upper case)
    #
    the_class.instance_eval do
      @func_name = func_name

      def name
        @func_name
      end

      def loader
        @loader
      end
    end

    # The given block can now be evaluated and have access to name and loader
    #
    the_class.class_eval(&block)

    # Automatically create an object dispatcher based on introspection if the
    # loaded user code did not define any dispatchers. Fail if function name
    # does not match a given method name in user code.
    #
    if the_class.dispatcher.empty?
      simple_name = func_name.split(/::/)[-1]
      type, names = default_dispatcher(the_class, simple_name)
      last_captures_rest = (type.size_range[1] == Float::INFINITY)
      the_class.dispatcher.add_dispatch(type, simple_name, names, nil, nil, nil, last_captures_rest)
    end

    # The function class is returned as the result of the create function method
    the_class
  end

  # Creates a default dispatcher configured from a method with the same name as the function
  #
  # @api private
  def self.default_dispatcher(the_class, func_name)
    unless the_class.method_defined?(func_name)
      raise ArgumentError, "Function Creation Error, cannot create a default dispatcher for function '#{func_name}', no method with this name found"
    end
    any_signature(*min_max_param(the_class.instance_method(func_name)))
  end

  # @api private
  def self.min_max_param(method)
    result = {:req => 0, :opt => 0, :rest => 0 }
    # count per parameter kind, and get array of names
    names = method.parameters.map { |p| result[p[0]] += 1 ; p[1].to_s }
    from = result[:req]
    to = result[:rest] > 0 ? :default : from + result[:opt]
    [from, to, names]
  end

  # Construct a signature consisting of Object type, with min, and max, and given names.
  # (there is only one type entry).
  #
  # @api private
  def self.any_signature(from, to, names)
    # Construct the type for the signature
    # Tuple[Object, from, to]
    factory = Puppet::Pops::Types::TypeFactory
    [factory.callable(factory.any, from, to), names]
  end

  # Function
  # ===
  # This class is the base class for all Puppet 4x Function API functions. A
  # specialized class is created for each puppet function.
  #
  # @api public
  class Function < Puppet::Pops::Functions::Function

    # @api private
    def self.builder
      @all_callables ||= Puppet::Pops::Types::TypeFactory.all_callables
      DispatcherBuilder.new(dispatcher, Puppet::Pops::Types::TypeParser.singleton, @all_callables, loader)
    end

    # Dispatch any calls that match the signature to the provided method name.
    #
    # @param meth_name [Symbol] The name of the implementation method to call
    #   when the signature defined in the block matches the arguments to a call
    #   to the function.
    # @return [Void]
    #
    # @api public
    def self.dispatch(meth_name, &block)
      builder().instance_eval do
        dispatch(meth_name, &block)
      end
    end

    # Allows types local to the function to be defined to ease the use of complex types
    # in a 4.x function. Within the given block, calls to `type` can be made with a string
    # 'AliasType = ExistingType` can be made to define aliases. The defined aliases are
    # available for further aliases, and in all dispatchers.
    #
    # @since 4.5.0
    # @api public
    #
    def self.local_types(&block)
      if loader.nil?
        raise ArgumentError, "No loader present. Call create_loaded_function(:myname, loader,...), instead of 'create_function' if running tests"
      end
      aliases = LocalTypeAliasesBuilder.new(loader, name)
      aliases.instance_eval(&block)
      # Add the loaded types to the builder
      aliases.local_types.each do |type_alias_expr|
        # Bind the type alias to the local_loader using the alias
        t = Puppet::Pops::Loader::TypeDefinitionInstantiator.create_from_model(type_alias_expr, aliases.loader)

        # Also define a method for convenient access to the defined type alias.
        # Since initial capital letter in Ruby means a Constant these names use a prefix of 
        # `type`. As an example, the type 'MyType' is accessed by calling `type_MyType`.
        define_method("type_#{t.name}") { t }
      end
      # Store the loader in the class
      @loader = aliases.loader
    end

    # Creates a new function instance in the given closure scope (visibility to variables), and a loader
    # (visibility to other definitions). The created function will either use the `given_loader` or
    # (if it has local type aliases) a loader that was constructed from the loader used when loading
    # the function's class.
    #
    # TODO: It would be of value to get rid of the second parameter here, but that would break API.
    #
    def self.new(closure_scope, given_loader)
      super(closure_scope, @loader || given_loader)
    end
  end

  # Base class for all functions implemented in the puppet language
  class PuppetFunction < Function
    def self.init_dispatch(a_closure)
      # A closure is compatible with a dispatcher - they are both callable signatures
      dispatcher.add(a_closure)
    end
  end

  # Public api methods of the DispatcherBuilder are available within dispatch()
  # blocks declared in a Puppet::Function.create_function() call.
  #
  # @api public
  class DispatcherBuilder
    attr_reader :loader

    # @api private
    def initialize(dispatcher, type_parser, all_callables, loader)
      @type_parser = type_parser
      @all_callables = all_callables
      @dispatcher = dispatcher
      @loader = loader
    end

    # Defines a required positional parameter with _type_ and _name_.
    #
    # @param type [String] The type specification for the parameter.
    # @param name [Symbol] The name of the parameter. This is primarily used
    #   for error message output and does not have to match an implementation
    #   method parameter.
    # @return [Void]
    #
    # @api public
    def param(type, name)
      internal_param(type, name)
      raise ArgumentError, 'A required parameter cannot be added after an optional parameter' if @min != @max
      @min += 1
      @max += 1
    end
    alias required_param param

    # Defines an optional positional parameter with _type_ and _name_.
    # May not be followed by a required parameter.
    #
    # @param type [String] The type specification for the parameter.
    # @param name [Symbol] The name of the parameter. This is primarily used
    #   for error message output and does not have to match an implementation
    #   method parameter.
    # @return [Void]
    #
    # @api public
    def optional_param(type, name)
      internal_param(type, name)
      @max += 1
    end

    # Defines a repeated positional parameter with _type_ and _name_ that may occur 0 to "infinite" number of times.
    # It may only appear last or just before a block parameter.
    #
    # @param type [String] The type specification for the parameter.
    # @param name [Symbol] The name of the parameter. This is primarily used
    #   for error message output and does not have to match an implementation
    #   method parameter.
    # @return [Void]
    #
    # @api public
    def repeated_param(type, name)
      internal_param(type, name, true)
      @max = :default
    end
    alias optional_repeated_param repeated_param

    # Defines a repeated positional parameter with _type_ and _name_ that may occur 1 to "infinite" number of times.
    # It may only appear last or just before a block parameter.
    #
    # @param type [String] The type specification for the parameter.
    # @param name [Symbol] The name of the parameter. This is primarily used
    #   for error message output and does not have to match an implementation
    #   method parameter.
    # @return [Void]
    #
    # @api public
    def required_repeated_param(type, name)
      internal_param(type, name, true)
      raise ArgumentError, 'A required repeated parameter cannot be added after an optional parameter' if @min != @max
      @min += 1
      @max = :default
    end

    # Defines one required block parameter that may appear last. If type and name is missing the
    # default type is "Callable", and the name is "block". If only one
    # parameter is given, then that is the name and the type is "Callable".
    #
    # @api public
    def block_param(*type_and_name)
      case type_and_name.size
      when 0
        type = @all_callables
        name = :block
      when 1
        type = @all_callables
        name = type_and_name[0]
      when 2
        type_string, name = type_and_name
        type = @type_parser.parse(type_string, loader)
      else
        raise ArgumentError, "block_param accepts max 2 arguments (type, name), got #{type_and_name.size}."
      end

      unless Puppet::Pops::Types::TypeCalculator.is_kind_of_callable?(type, false)
        raise ArgumentError, "Expected PCallableType or PVariantType thereof, got #{type.class}"
      end

      unless name.is_a?(Symbol)
        raise ArgumentError, "Expected block_param name to be a Symbol, got #{name.class}"
      end

      if @block_type.nil?
        @block_type = type
        @block_name = name
      else
        raise ArgumentError, 'Attempt to redefine block'
      end
    end
    alias required_block_param block_param

    # Defines one optional block parameter that may appear last. If type or name is missing the
    # defaults are "any callable", and the name is "block". The implementor of the dispatch target
    # must use block = nil when it is optional (or an error is raised when the call is made).
    #
    # @api public
    def optional_block_param(*type_and_name)
      # same as required, only wrap the result in an optional type
      required_block_param(*type_and_name)
      @block_type = Puppet::Pops::Types::TypeFactory.optional(@block_type)
    end

    private

    # @api private
    def internal_param(type, name, repeat = false)
      raise ArgumentError, 'Parameters cannot be added after a block parameter' unless @block_type.nil?
      raise ArgumentError, 'Parameters cannot be added after a repeated parameter' if @max == :default

      if name.is_a?(String)
        raise ArgumentError, "Parameter name argument must be a Symbol. Got #{name.class}"
      end

      if type.is_a?(String)
        @types << type
        @names << name
        # mark what should be picked for this position when dispatching
        if repeat
          @weaving << -@names.size()
        else
          @weaving << @names.size()-1
        end
      else
        raise ArgumentError, "Parameter 'type' must be a String reference to a Puppet Data Type. Got #{type.class}"
      end
    end

    # @api private
    def dispatch(meth_name, &block)
      # an array of either an index into names/types, or an array with
      # injection information [type, name, injection_name] used when the call
      # is being made to weave injections into the given arguments.
      #
      @types = []
      @names = []
      @weaving = []
      @injections = []
      @min = 0
      @max = 0
      @block_type = nil
      @block_name = nil
      self.instance_eval &block
      callable_t = create_callable(@types, @block_type, @min, @max)
      @dispatcher.add_dispatch(callable_t, meth_name, @names, @block_name, @injections, @weaving, @max == :default)
    end

    # Handles creation of a callable type from strings specifications of puppet
    # types and allows the min/max occurs of the given types to be given as one
    # or two integer values at the end.  The given block_type should be
    # Optional[Callable], Callable, or nil.
    #
    # @api private
    def create_callable(types, block_type, from, to)
      mapped_types = types.map do |t|
        @type_parser.parse(t, loader)
      end

      if from != to
        # :optional and/or :repeated parameters are present.
        mapped_types << from
        mapped_types << to
      end

      if block_type
        mapped_types << block_type
      end

      Puppet::Pops::Types::TypeFactory.callable(*mapped_types)
    end
  end

  # The LocalTypeAliasBuilder is used by the 'local_types' method to collect the individual
  # type aliases given by the function's author.
  # 
  class LocalTypeAliasesBuilder
    attr_reader :local_types, :parser, :loader

    def initialize(loader, name)
      @loader = Puppet::Pops::Loader::PredefinedLoader.new(loader, :"local_function_#{name}")
      @local_types = []
      # get the shared parser used by puppet's compiler
      @parser = Puppet::Pops::Parser::EvaluatingParser.singleton()
    end

    # Defines a local type alias, the given string should be a Puppet Language type alias expression
    # in string form without the leading 'type' keyword.
    # Calls to local_type must be made before the first parameter definition or an error will
    # be raised.
    # 
    # @param assignment_string [String] a string on the form 'AliasType = ExistingType'
    # @api public
    #
    def type(assignment_string)
      result = parser.parse_string("type #{assignment_string}", nil) # no file source :-(
      unless result.body.kind_of?(Puppet::Pops::Model::TypeAlias)
        raise ArgumentError, "Expected a type alias assignment on the form 'AliasType = T', got '#{assignment_string}'"
      end
      @local_types << result.body
    end
  end

  private

  # @note WARNING: This style of creating functions is not public. It is a system
  #   under development that will be used for creating "system" functions.
  #
  # This is a private, internal, system for creating functions. It supports
  # everything that the public function definition system supports as well as a
  # few extra features.
  #
  # Injection Support
  # ===
  # The Function API supports injection of data and services. It is possible to
  # make injection that takes effect when the function is loaded (for services
  # and runtime configuration that does not change depending on how/from where
  # in what context the function is called. It is also possible to inject and
  # weave argument values into a call.
  #
  # Injection of attributes
  # ---
  # Injection of attributes is performed by one of the methods `attr_injected`,
  # and `attr_injected_producer`.  The injected attributes are available via
  # accessor method calls.
  #
  # @example using injected attributes
  #   Puppet::Functions.create_function('test') do
  #     attr_injected String, :larger, 'message_larger'
  #     attr_injected String, :smaller, 'message_smaller'
  #     def test(a, b)
  #       a > b ? larger() : smaller()
  #     end
  #   end
  #
  # @api private
  class InternalFunction < Function
    # @api private
    def self.builder
      @all_callables ||= Puppet::Pops::Types::TypeFactory.all_callables
      InternalDispatchBuilder.new(dispatcher, Puppet::Pops::Types::TypeParser.singleton, @all_callables, loader)
    end

    # Defines class level injected attribute with reader method
    #
    # @api private
    def self.attr_injected(type, attribute_name, injection_name = nil)
      define_method(attribute_name) do
        ivar = :"@#{attribute_name.to_s}"
        unless instance_variable_defined?(ivar)
          injector = Puppet.lookup(:injector)
          instance_variable_set(ivar, injector.lookup(closure_scope, type, injection_name))
        end
        instance_variable_get(ivar)
      end
    end

    # Defines class level injected producer attribute with reader method
    #
    # @api private
    def self.attr_injected_producer(type, attribute_name, injection_name = nil)
      define_method(attribute_name) do
        ivar = :"@#{attribute_name.to_s}"
        unless instance_variable_defined?(ivar)
          injector = Puppet.lookup(:injector)
          instance_variable_set(ivar, injector.lookup_producer(closure_scope, type, injection_name))
        end
        instance_variable_get(ivar)
      end
    end

    # Allows the implementation of a function to call other functions by name and pass the caller
    # scope. The callable functions are those visible to the same loader that loaded this function
    # (the calling function).
    #
    # @param scope [Puppet::Parser::Scope] The caller scope
    # @param function_name [String] The name of the function
    # @param *args [Object] splat of arguments
    # @return [Object] The result returned by the called function
    #
    # @api public
    def call_function_with_scope(scope, function_name, *args)
      internal_call_function(scope, function_name, args)
    end
  end

  # @note WARNING: This style of creating functions is not public. It is a system
  #   under development that will be used for creating "system" functions.
  #
  # Injection and Weaving of parameters
  # ---
  # It is possible to inject and weave parameters into a call. These extra
  # parameters are not part of the parameters passed from the Puppet logic, and
  # they can not be overridden by parameters given as arguments in the call.
  # They are invisible to the Puppet Language.
  #
  # @example using injected parameters
  #   Puppet::Functions.create_function('test') do
  #     dispatch :test do
  #       param 'Scalar', 'a'
  #       param 'Scalar', 'b'
  #       injected_param 'String', 'larger', 'message_larger'
  #       injected_param 'String', 'smaller', 'message_smaller'
  #     end
  #     def test(a, b, larger, smaller)
  #       a > b ? larger : smaller
  #     end
  #   end
  #
  # The function in the example above is called like this:
  #
  #     test(10, 20)
  #
  # Using injected value as default
  # ---
  # Default value assignment is handled by using the regular Ruby mechanism (a
  # value is assigned to the variable).  The dispatch simply indicates that the
  # value is optional. If the default value should be injected, it can be
  # handled different ways depending on what is desired:
  #
  # * by calling the accessor method for an injected Function class attribute.
  #   This is suitable if the value is constant across all instantiations of the
  #   function, and across all calls.
  # * by injecting a parameter into the call
  #   to the left of the parameter, and then assigning that as the default value.
  # * One of the above forms, but using an injected producer instead of a
  #   directly injected value.
  #
  # @example method with injected default values
  #   Puppet::Functions.create_function('test') do
  #     dispatch :test do
  #       injected_param String, 'b_default', 'b_default_value_key'
  #       param 'Scalar', 'a'
  #       param 'Scalar', 'b'
  #     end
  #     def test(b_default, a, b = b_default)
  #       # ...
  #     end
  #   end
  #
  # @api private
  class InternalDispatchBuilder < DispatcherBuilder
    def scope_param()
      @injections << [:scope, 'scope', '', :dispatcher_internal]
      # mark what should be picked for this position when dispatching
      @weaving << [@injections.size()-1]
    end
    # TODO: is param name really needed? Perhaps for error messages? (it is unused now)
    #
    # @api private
    def injected_param(type, name, injection_name = '')
      @injections << [type, name, injection_name]
      # mark what should be picked for this position when dispatching
      @weaving << [@injections.size() -1]
    end

    # TODO: is param name really needed? Perhaps for error messages? (it is unused now)
    #
    # @api private
    def injected_producer_param(type, name, injection_name = '')
      @injections << [type, name, injection_name, :producer]
      # mark what should be picked for this position when dispatching
      @weaving << [@injections.size()-1]
    end
  end
end
