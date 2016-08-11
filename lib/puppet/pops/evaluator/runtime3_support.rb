module Puppet::Pops
module Evaluator
# A module with bindings between the new evaluator and the 3x runtime.
# The intention is to separate all calls into scope, compiler, resource, etc. in this module
# to make it easier to later refactor the evaluator for better implementations of the 3x classes.
#
# @api private
module Runtime3Support

  NAME_SPACE_SEPARATOR = '::'.freeze

  # Fails the evaluation of _semantic_ with a given issue.
  #
  # @param issue [Issue] the issue to report
  # @param semantic [ModelPopsObject] the object for which evaluation failed in some way. Used to determine origin.
  # @param options [Hash] hash of optional named data elements for the given issue
  # @return [!] this method does not return
  # @raise [Puppet::ParseError] an evaluation error initialized from the arguments (TODO: Change to EvaluationError?)
  #
  def fail(issue, semantic, options={}, except=nil)
    optionally_fail(issue, semantic, options, except)
    # an error should have been raised since fail always fails
    raise ArgumentError, "Internal Error: Configuration of runtime error handling wrong: should have raised exception"
  end

  # Optionally (based on severity) Fails the evaluation of _semantic_ with a given issue
  # If the given issue is configured to be of severity < :error it is only reported, and the function returns.
  #
  # @param issue [Issue] the issue to report
  # @param semantic [ModelPopsObject] the object for which evaluation failed in some way. Used to determine origin.
  # @param options [Hash] hash of optional named data elements for the given issue
  # @return [!] this method does not return
  # @raise [Puppet::ParseError] an evaluation error initialized from the arguments (TODO: Change to EvaluationError?)
  #
  def optionally_fail(issue, semantic, options={}, except=nil)
    if except.nil?
      # Want a stacktrace, and it must be passed as an exception
      begin
       raise EvaluationError.new()
      rescue EvaluationError => e
        except = e
      end
    end
    diagnostic_producer.accept(issue, semantic, options, except)
  end

  # Binds the given variable name to the given value in the given scope.
  # The reference object `o` is intended to be used for origin information - the 3x scope implementation
  # only makes use of location when there is an error. This is now handled by other mechanisms; first a check
  # is made if a variable exists and an error is raised if attempting to change an immutable value. Errors
  # in name, numeric variable assignment etc. have also been validated prior to this call. In the event the
  # scope.setvar still raises an error, the general exception handling for evaluation of the assignment
  # expression knows about its location. Because of this, there is no need to extract the location for each
  # setting (extraction is somewhat expensive since 3x requires line instead of offset).
  #
  def set_variable(name, value, o, scope)
    # Scope also checks this but requires that location information are passed as options.
    # Those are expensive to calculate and a test is instead made here to enable failing with better information.
    # The error is not specific enough to allow catching it - need to check the actual message text.
    # TODO: Improve the messy implementation in Scope.
    #
    if scope.bound?(name)
      if Puppet::Parser::Scope::RESERVED_VARIABLE_NAMES.include?(name)
        fail(Issues::ILLEGAL_RESERVED_ASSIGNMENT, o, {:name => name} )
      elsif name == "server_facts" && Puppet[:trusted_server_facts]
        fail(Issues::ILLEGAL_RESERVED_ASSIGNMENT, o, {:name => name} )
      else
        fail(Issues::ILLEGAL_REASSIGNMENT, o, {:name => name} )
      end
    end
    scope.setvar(name, value)
  end

  # Returns the value of the variable (nil is returned if variable has no value, or if variable does not exist)
  #
  def get_variable_value(name, o, scope)
    # Puppet 3x stores all variables as strings (then converts them back to numeric with a regexp... to see if it is a match variable)
    # Not ideal, scope should support numeric lookup directly instead.
    # TODO: consider fixing scope
    catch(:undefined_variable) {
      x = scope.lookupvar(name.to_s)
      # Must convert :undef back to nil - this can happen when an undefined variable is used in a
      # parameter's default value expression - there nil must be :undef to work with the rest of 3x.
      # Now that the value comes back to 4x it is changed to nil.
      return :undef.equal?(x) ? nil : x
    }
    # It is always ok to reference numeric variables even if they are not assigned. They are always undef
    # if not set by a match expression.
    #
    unless name =~ Puppet::Pops::Patterns::NUMERIC_VAR_NAME
      optionally_fail(Puppet::Pops::Issues::UNKNOWN_VARIABLE, o, {:name => name})
    end
    nil # in case unknown variable is configured as a warning or ignore
  end

  # Returns true if the variable of the given name is set in the given most nested scope. True is returned even if
  # variable is bound to nil.
  #
  def variable_bound?(name, scope)
    scope.bound?(name.to_s)
  end

  # Returns true if the variable is bound to a value or nil, in the scope or it's parent scopes.
  #
  def variable_exists?(name, scope)
    scope.exist?(name.to_s)
  end

  def set_match_data(match_data, scope)
    # See set_variable for rationale for not passing file and line to ephemeral_from.
    # NOTE: The 3x scope adds one ephemeral(match) to its internal stack per match that succeeds ! It never
    # clears anything. Thus a context that performs many matches will get very deep (there simply is no way to
    # clear the match variables without rolling back the ephemeral stack.)
    # This implementation does not attempt to fix this, it behaves the same bad way.
    unless match_data.nil?
      scope.ephemeral_from(match_data)
    end
  end

  # Creates a local scope with vairalbes set from a hash of variable name to value
  #
  def create_local_scope_from(hash, scope)
    # two dummy values are needed since the scope tries to give an error message (can not happen in this
    # case - it is just wrong, the error should be reported by the caller who knows in more detail where it
    # is in the source.
    #
    raise ArgumentError, "Internal error - attempt to create a local scope without a hash" unless hash.is_a?(Hash)
    scope.ephemeral_from(hash)
  end

  # Creates a nested match scope
  def create_match_scope_from(scope)
    # Create a transparent match scope (for future matches)
    scope.new_match_scope(nil)
  end

  def get_scope_nesting_level(scope)
    scope.ephemeral_level
  end

  def set_scope_nesting_level(scope, level)
    # 3x uses this method to reset the level,
    scope.pop_ephemerals(level)
  end

  # Adds a relationship between the given `source` and `target` of the given `relationship_type`
  # @param source [Puppet:Pops::Types::PCatalogEntryType] the source end of the relationship (from)
  # @param target [Puppet:Pops::Types::PCatalogEntryType] the target end of the relationship (to)
  # @param relationship_type [:relationship, :subscription] the type of the relationship
  #
  def add_relationship(source, target, relationship_type, scope)
    # The 3x way is to record a Puppet::Parser::Relationship that is evaluated at the end of the compilation.
    # This means it is not possible to detect any duplicates at this point (and signal where an attempt is made to
    # add a duplicate. There is also no location information to signal the original place in the logic. The user will have
    # to go fish.
    # The 3.x implementation is based on Strings :-o, so the source and target must be transformed. The resolution is
    # done by Catalog#resource(type, title). To do that, it creates a Puppet::Resource since it is responsible for
    # translating the name/type/title and create index-keys used by the catalog. The Puppet::Resource has bizarre parsing of
    # the type and title (scan for [] that is interpreted as type/title (but it gets it wrong).
    # Moreover if the type is "" or "component", the type is Class, and if the type is :main, it is :main, all other cases
    # undergo capitalization of name-segments (foo::bar becomes Foo::Bar). (This was earlier done in the reverse by the parser).
    # Further, the title undergoes the same munging !!!
    #
    # That bug infested nest of messy logic needs serious Exorcism!
    #
    # Unfortunately it is not easy to simply call more intelligent methods at a lower level as the compiler evaluates the recorded
    # Relationship object at a much later point, and it is responsible for invoking all the messy logic.
    #
    # TODO: Revisit the below logic when there is a sane implementation of the catalog, compiler and resource. For now
    # concentrate on transforming the type references to what is expected by the wacky logic.
    #
    # HOWEVER, the Compiler only records the Relationships, and the only method it calls is @relationships.each{|x| x.evaluate(catalog) }
    # Which means a smarter Relationship class could do this right. Instead of obtaining the resource from the catalog using
    # the borked resource(type, title) which creates a resource for the purpose of looking it up, it needs to instead
    # scan the catalog's resources
    #
    # GAAAH, it is even worse!
    # It starts in the parser, which parses "File['foo']" into an AST::ResourceReference with type = File, and title = foo
    # This AST is evaluated by looking up the type/title in the scope - causing it to be loaded if it exists, and if not, the given
    # type name/title is used. It does not search for resource instances, only classes and types. It returns symbolic information
    # [type, [title, title]]. From this, instances of Puppet::Resource are created and returned. These only have type/title information
    # filled out. One or an array of resources are returned.
    # This set of evaluated (empty reference) Resource instances are then passed to the relationship operator. It creates a
    # Puppet::Parser::Relationship giving it a source and a target that are (empty reference) Resource instances. These are then remembered
    # until the relationship is evaluated by the compiler (at the end). When evaluation takes place, the (empty reference) Resource instances
    # are converted to String (!?! WTF) on the simple format "#{type}[#{title}]", and the catalog is told to find a resource, by giving
    # it this string. If it cannot find the resource it fails, else the before/notify parameter is appended with the target.
    # The search for the resource begin with (you guessed it) again creating an (empty reference) resource from type and title (WTF?!?!).
    # The catalog now uses the reference resource to compute a key [r.type, r.title.to_s] and also gets a uniqueness key from the
    # resource (This is only a reference type created from title and type). If it cannot find it with the first key, it uses the
    # uniqueness key to lookup.
    #
    # This is probably done to allow a resource type to munge/translate the title in some way (but it is quite unclear from the long
    # and convoluted path of evaluation.
    # In order to do this in a way that is similar to 3.x two resources are created to be used as keys.
    #
    # And if that is not enough, a source/target may be a Collector (a baked query that will be evaluated by the
    # compiler - it is simply passed through here for processing by the compiler at the right time).
    #
    if source.is_a?(Collectors::AbstractCollector)
      # use verbatim - behavior defined by 3x
      source_resource = source
    else
      # transform into the wonderful String representation in 3x
      type, title = Runtime3Converter.instance.catalog_type_to_split_type_title(source)
      source_resource = Puppet::Resource.new(type, title)
    end
    if target.is_a?(Collectors::AbstractCollector)
      # use verbatim - behavior defined by 3x
      target_resource = target
    else
      # transform into the wonderful String representation in 3x
      type, title = Runtime3Converter.instance.catalog_type_to_split_type_title(target)
      target_resource = Puppet::Resource.new(type, title)
    end
    # Add the relationship to the compiler for later evaluation.
    scope.compiler.add_relationship(Puppet::Parser::Relationship.new(source_resource, target_resource, relationship_type))
  end

  # Coerce value `v` to numeric or fails.
  # The given value `v` is coerced to Numeric, and if that fails the operation
  # calls {#fail}.
  # @param v [Object] the value to convert
  # @param o [Object] originating instruction
  # @param scope [Object] the (runtime specific) scope where evaluation of o takes place
  # @return [Numeric] value `v` converted to Numeric.
  #
  def coerce_numeric(v, o, scope)
    unless n = Utils.to_n(v)
      fail(Issues::NOT_NUMERIC, o, {:value => v})
    end
    n
  end

  # Provides the ability to call a 3.x or 4.x function from the perspective of a 3.x function or ERB template.
  # The arguments to the function must be an Array containing values compliant with the 4.x calling convention.
  # If the targeted function is a 3.x function, the values will be transformed.
  # @param name [String] the name of the function (without the 'function_' prefix used by scope)
  # @param args [Array] arguments, may be empty
  # @param scope [Object] the (runtime specific) scope where evaluation takes place
  # @raise ArgumentError 'unknown function' if the function does not exist
  #
  def external_call_function(name, args, scope, &block)
    # Call via 4x API if the function exists there
    loaders = scope.compiler.loaders
    # Since this is a call from non puppet code, it is not possible to relate it to a module loader
    # It is known where the call originates by using the scope associated module - but this is the calling scope
    # and it does not defined the visibility of functions from a ruby function's perspective. Instead,
    # this is done from the perspective of the environment.
    loader = loaders.private_environment_loader
    if loader && func = loader.load(:function, name)
      Puppet::Util::Profiler.profile(name, [:functions, name]) do
        return func.call(scope, *args, &block)
      end
    end

    # Call via 3x API if function exists there
    raise ArgumentError, "Unknown function '#{name}'" unless Puppet::Parser::Functions.function(name)

    # Arguments must be mapped since functions are unaware of the new and magical creatures in 4x.
    # NOTE: Passing an empty string last converts nil/:undef to empty string
    mapped_args = Runtime3Converter.map_args(args, scope, '')
    result = scope.send("function_#{name}", mapped_args, &block)
    # Prevent non r-value functions from leaking their result (they are not written to care about this)
    Puppet::Parser::Functions.rvalue?(name) ? result : nil
  end

  def call_function(name, args, o, scope, &block)
    file, line = extract_file_line(o)
    loader = Adapters::LoaderAdapter.loader_for_model_object(o, scope)
    if loader && func = loader.load(:function, name)
      Puppet::Util::Profiler.profile(name, [:functions, name]) do
        # Add stack frame when calling
        return Puppet::Pops::PuppetStack.stack(file, line, func, :call, [scope, *args], &block)
      end
    end
    # Call via 3x API if function exists there
    fail(Issues::UNKNOWN_FUNCTION, o, {:name => name}) unless Puppet::Parser::Functions.function(name)

    # Arguments must be mapped since functions are unaware of the new and magical creatures in 4x.
    # NOTE: Passing an empty string last converts nil/:undef to empty string
    mapped_args = Runtime3Converter.map_args(args, scope, '')
    result = Puppet::Pops::PuppetStack.stack(file, line, scope, "function_#{name}", [mapped_args], &block)
    # Prevent non r-value functions from leaking their result (they are not written to care about this)
    Puppet::Parser::Functions.rvalue?(name) ? result : nil
  end

  # The o is used for source reference
  def create_resource_parameter(o, scope, name, value, operator)
    file, line = extract_file_line(o)
    Puppet::Parser::Resource::Param.new(
      :name   => name,
      :value  => convert(value, scope, nil), # converted to 3x since 4x supports additional objects / types
      :source => scope.source, :line => line, :file => file,
      :add    => operator == :'+>'
    )
  end

  def convert(value, scope, undef_value)
    Runtime3Converter.convert(value, scope, undef_value)
  end

  def create_resources(o, scope, virtual, exported, type_name, resource_titles, evaluated_parameters)
    # Not 100% accurate as this is the resource expression location and each title is processed separately
    # The titles are however the result of evaluation and they have no location at this point (an array
    # of positions for the source expressions are required for this to work).
    # TODO: Revisit and possible improve the accuracy.
    #
    file, line = extract_file_line(o)
    Runtime3ResourceSupport.create_resources(file, line, scope, virtual, exported, type_name, resource_titles, evaluated_parameters)
  end

  # Defines default parameters for a type with the given name.
  #
  def create_resource_defaults(o, scope, type_name, evaluated_parameters)
    # Note that name must be capitalized in this 3x call
    # The 3x impl creates a Resource instance with a bogus title and then asks the created resource
    # for the type of the name.
    # Note, locations are available per parameter.
    #
    scope.define_settings(capitalize_qualified_name(type_name), evaluated_parameters.flatten)
  end

  # Capitalizes each segment of a qualified name
  #
  def capitalize_qualified_name(name)
    name.split(/::/).map(&:capitalize).join(NAME_SPACE_SEPARATOR)
  end

  # Creates resource overrides for all resource type objects in evaluated_resources. The same set of
  # evaluated parameters are applied to all.
  #
  def create_resource_overrides(o, scope, evaluated_resources, evaluated_parameters)
    # Not 100% accurate as this is the resource expression location and each title is processed separately
    # The titles are however the result of evaluation and they have no location at this point (an array
    # of positions for the source expressions are required for this to work.
    # TODO: Revisit and possible improve the accuracy.
    #
    file, line = extract_file_line(o)
    # A *=> results in an array of arrays
    evaluated_parameters = evaluated_parameters.flatten
    evaluated_resources.each do |r|
      unless r.is_a?(Types::PResourceType) && r.type_name != 'class'
        fail(Issues::ILLEGAL_OVERRIDEN_TYPE, o, {:actual => r} )
      end
      resource = Puppet::Parser::Resource.new(
      r.type_name, r.title,
        :parameters => evaluated_parameters,
        :file => file,
        :line => line,
        # WTF is this? Which source is this? The file? The name of the context ?
        :source => scope.source,
        :scope => scope
      )

      scope.compiler.add_override(resource)
    end
  end

  # Finds a resource given a type and a title.
  #
  def find_resource(scope, type_name, title)
    scope.compiler.findresource(type_name, title)
  end

  # Returns the value of a resource's parameter by first looking up the parameter in the resource
  # and then in the defaults for the resource. Since the resource exists (it must in order to look up its
  # parameters, any overrides have already been applied). Defaults are not applied to a resource until it
  # has been finished (which typically has not taken place when this is evaluated; hence the dual lookup).
  #
  def get_resource_parameter_value(scope, resource, parameter_name)
    # This gets the parameter value, or nil (for both valid parameters and parameters that do not exist).
    val = resource[parameter_name]

    # Sometimes the resource is a Puppet::Parser::Resource and sometimes it is
    # a Puppet::Resource. The Puppet::Resource case occurs when puppet language
    # is evaluated against an already completed catalog (where all instances of
    # Puppet::Parser::Resource are converted to Puppet::Resource instances).
    # Evaluating against an already completed catalog is really only found in
    # the language specification tests, where the puppet language is used to
    # test itself.
    if resource.is_a?(Puppet::Parser::Resource)
      # The defaults must be looked up in the scope where the resource was created (not in the given
      # scope where the lookup takes place.
      resource_scope = resource.scope
      if val.nil? && resource_scope && defaults = resource_scope.lookupdefaults(resource.type)
        # NOTE: 3x resource keeps defaults as hash using symbol for name as key to Parameter which (again) holds
        # name and value.
        # NOTE: meta parameters that are unset ends up here, and there are no defaults for those encoded
        # in the defaults, they may receive hardcoded defaults later (e.g. 'tag').
        param = defaults[parameter_name.to_sym]
        # Some parameters (meta parameters like 'tag') does not return a param from which the value can be obtained
        # at all times. Instead, they return a nil param until a value has been set.
        val = param.nil? ? nil : param.value
      end
    end
    val
  end

  # Returns true, if the given name is the name of a resource parameter.
  #
  def is_parameter_of_resource?(scope, resource, name)
    return false unless name.is_a?(String)
    resource.valid_parameter?(name)
  end

  def resource_to_ptype(resource)
    nil if resource.nil?
    # inference returns the meta type since the 3x Resource is an alternate way to describe a type
    type_calculator.infer(resource).type
  end

  # This is the same type of "truth" as used in the current Puppet DSL.
  #
  def is_true?(value, o)
    # Is the value true?  This allows us to control the definition of truth
    # in one place.
    case value
    # Support :undef since it may come from a 3x structure
    when :undef
      false
    when String
      true
    else
      !!value
    end
  end

  # Utility method for TrueClass || FalseClass
  # @param x [Object] the object to test if it is instance of TrueClass or FalseClass
  def is_boolean? x
    x.is_a?(TrueClass) || x.is_a?(FalseClass)
  end

  def extract_file_line(o)
    source_pos = Utils.find_closest_positioned(o)
    return [nil, -1] unless source_pos
    [source_pos.locator.file, source_pos.line]
  end

  def find_closest_positioned(o)
    return nil if o.nil? || o.is_a?(Model::Program)
    o.offset.nil? ? find_closest_positioned(o.eContainer) : Adapters::SourcePosAdapter.adapt(o)
  end

  # Creates a diagnostic producer
  def diagnostic_producer
    Validation::DiagnosticProducer.new(
      ExceptionRaisingAcceptor.new(),                   # Raises exception on all issues
      SeverityProducer.new(), # All issues are errors
      Model::ModelLabelProvider.new())
  end

  # Configure the severity of failures
  class SeverityProducer < Validation::SeverityProducer
    Issues = Issues

    def initialize
      super
      p = self
      # Issues triggering warning only if --debug is on
      if Puppet[:debug]
        p[Issues::EMPTY_RESOURCE_SPECIALIZATION] = :warning
      else
        p[Issues::EMPTY_RESOURCE_SPECIALIZATION] = :ignore
      end

      # if strict variables are on, an error is raised
      # if strict variables are off, the Puppet[strict] defines what is done
      #
      if Puppet[:strict_variables]
        p[Issues::UNKNOWN_VARIABLE] = :error
      elsif Puppet[:strict] == :off
        p[Issues::UNKNOWN_VARIABLE] = :ignore
      else
        p[Issues::UNKNOWN_VARIABLE] = Puppet[:strict]
      end

      # Store config issues, ignore or warning
      p[Issues::RT_NO_STORECONFIGS_EXPORT]    = Puppet[:storeconfigs] ? :ignore : :warning
      p[Issues::RT_NO_STORECONFIGS]           = Puppet[:storeconfigs] ? :ignore : :warning
    end
  end

  # An acceptor of diagnostics that immediately raises an exception.
  class ExceptionRaisingAcceptor < Validation::Acceptor
    def accept(diagnostic)
      super
      IssueReporter.assert_and_report(self, {
        :message => "Evaluation Error:",
        :emit_warnings => true,  # log warnings
        :exception_class => Puppet::PreformattedError
      })
      if errors?
        raise ArgumentError, "Internal Error: Configuration of runtime error handling wrong: should have raised exception"
      end
    end
  end

  class EvaluationError < StandardError
  end
end
end
end
