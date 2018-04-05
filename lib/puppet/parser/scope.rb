
# The scope class, which handles storing and retrieving variables and types and
# such.
require 'forwardable'

require 'puppet/parser'
require 'puppet/parser/templatewrapper'
require 'puppet/parser/resource'

require 'puppet/util/methodhelper'

# This class is part of the internal parser/evaluator/compiler functionality of Puppet.
# It is passed between the various classes that participate in evaluation.
# None of its methods are API except those that are clearly marked as such.
#
# @api public
class Puppet::Parser::Scope
  extend Forwardable
  include Puppet::Util::MethodHelper

  # Variables that always exist with nil value even if not set
  BUILT_IN_VARS = ['module_name'.freeze, 'caller_module_name'.freeze].freeze
  EMPTY_HASH = {}.freeze

  Puppet::Util.logmethods(self)

  include Puppet::Util::Errors
  attr_accessor :source, :resource
  attr_reader :compiler
  attr_accessor :parent

  # Hash of hashes of default values per type name
  attr_reader :defaults

  # Alias for `compiler.environment`
  def environment
    @compiler.environment
  end

  # Alias for `compiler.catalog`
  def catalog
    @compiler.catalog
  end

  # Abstract base class for LocalScope and MatchScope
  #
  class Ephemeral

    attr_reader :parent

    def initialize(parent = nil)
      @parent = parent
    end

    def is_local_scope?
      false
    end

    def [](name)
      if @parent
        @parent[name]
      end
    end

    def include?(name)
      (@parent and @parent.include?(name))
    end

    def bound?(name)
      false
    end

    def add_entries_to(target = {})
      @parent.add_entries_to(target) unless @parent.nil?
      # do not include match data ($0-$n)
      target
    end
  end

  class LocalScope < Ephemeral

    def initialize(parent=nil)
      super parent
      @symbols = {}
    end

    def [](name)
      val = @symbols[name]
      val.nil? && !@symbols.include?(name) ? super : val
    end

    def is_local_scope?
      true
    end

    def []=(name, value)
      @symbols[name] = value
    end

    def include?(name)
      bound?(name) || super
    end

    def delete(name)
      @symbols.delete(name)
    end

    def bound?(name)
      @symbols.include?(name)
    end

    def add_entries_to(target = {})
      super
      @symbols.each do |k, v|
        if v == :undef || v.nil?
          target.delete(k)
        else
          target[ k ] = v
        end
      end
      target
    end
  end

  class MatchScope < Ephemeral

    attr_accessor :match_data

    def initialize(parent = nil, match_data = nil)
      super parent
      @match_data = match_data
    end

    def is_local_scope?
      false
    end

    def [](name)
      if bound?(name)
        @match_data[name.to_i]
      else
        super
      end
    end

    def include?(name)
      bound?(name) or super
    end

    def bound?(name)
      # A "match variables" scope reports all numeric variables to be bound if the scope has
      # match_data. Without match data the scope is transparent.
      #
      @match_data && name =~ /^\d+$/
    end

    def []=(name, value)
      # TODO: Bad choice of exception
      raise Puppet::ParseError, _("Numerical variables cannot be changed. Attempt to set $%{name}") % { name: name }
    end

    def delete(name)
      # TODO: Bad choice of exception
      raise Puppet::ParseError, _("Numerical variables cannot be deleted: Attempt to delete: $%{name}") % { name: name }
    end

    def add_entries_to(target = {})
      # do not include match data ($0-$n)
      super
    end

  end

  # @api private
  class ParameterScope < Ephemeral
    class Access
      attr_accessor :value

      def assigned?
        instance_variable_defined?(:@value)
      end
    end

    # A parameter default must be evaluated using a special scope. The scope that is given to this method must
    # have a `ParameterScope` as its last ephemeral scope. This method will then push a `MatchScope` while the
    # given `expression` is evaluated. The method will catch any throw of `:unevaluated_parameter` and produce
    # an error saying that the evaluated parameter X tries to access the unevaluated parameter Y.
    #
    # @param name [String] the name of the currently evaluated parameter
    # @param expression [Puppet::Parser::AST] the expression to evaluate
    # @param scope [Puppet::Parser::Scope] a scope where a `ParameterScope` has been pushed
    # @return [Object] the result of the evaluation
    #
    # @api private
    def evaluate3x(name, expression, scope)
      scope.with_guarded_scope do
        bad = catch(:unevaluated_parameter) do
          scope.new_match_scope(nil)
          return as_read_only { expression.safeevaluate(scope) }
        end
        parameter_reference_failure(name, bad)
      end
    end

    def evaluate(name, expression, scope, evaluator)
      scope.with_guarded_scope do
        bad = catch(:unevaluated_parameter) do
          scope.new_match_scope(nil)
          return as_read_only { evaluator.evaluate(expression, scope) }
        end
        parameter_reference_failure(name, bad)
      end
    end

    def parameter_reference_failure(from, to)
      # Parameters are evaluated in the order they have in the @params hash.
      keys = @params.keys
      raise Puppet::Error, _("%{callee}: expects a value for parameter $%{to}") % { callee: @callee_name, to: to } if keys.index(to) < keys.index(from)
      raise Puppet::Error, _("%{callee}: default expression for $%{from} tries to illegally access not yet evaluated $%{to}") % { callee: @callee_name, from: from, to: to }
    end
    private :parameter_reference_failure

    def initialize(parent, callee_name, param_names)
      super(parent)
      @callee_name = callee_name
      @params = {}
      param_names.each { |name| @params[name] = Access.new }
    end

    def [](name)
      access = @params[name]
      return super if access.nil?
      throw(:unevaluated_parameter, name) unless access.assigned?
      access.value
    end

    def []=(name, value)
      raise Puppet::Error, _("Attempt to assign variable %{name} when evaluating parameters") % { name: name } if @read_only
      @params[name] ||= Access.new
      @params[name].value = value
    end

    def bound?(name)
      @params.include?(name)
    end

    def include?(name)
      @params.include?(name) || super
    end

    def is_local_scope?
      true
    end

    def as_read_only
      read_only = @read_only
      @read_only = true
      begin
        yield
      ensure
        @read_only = read_only
      end
    end

    def to_hash
      Hash[@params.select {|_, access| access.assigned? }.map { |name, access| [name, access.value] }]
    end
  end


  # Returns true if the variable of the given name has a non nil value.
  # TODO: This has vague semantics - does the variable exist or not?
  #       use ['name'] to get nil or value, and if nil check with exist?('name')
  #       this include? is only useful because of checking against the boolean value false.
  #
  def include?(name)
    catch(:undefined_variable) {
      return ! self[name].nil?
    }
    false
  end

  # Returns true if the variable of the given name is set to any value (including nil)
  #
  # @return [Boolean] if variable exists or not
  #
  def exist?(name)
    # Note !! ensure the answer is boolean
    !! if name =~ /^(.*)::(.+)$/
      class_name = $1
      variable_name = $2
      return true if class_name == '' && BUILT_IN_VARS.include?(variable_name)

      # lookup class, but do not care if it is not evaluated since that will result
      # in it not existing anyway. (Tests may run with just scopes and no evaluated classes which
      # will result in class_scope for "" not returning topscope).
      klass = find_hostclass(class_name)
      other_scope = klass.nil? ? nil : class_scope(klass)
      if other_scope.nil?
        class_name == '' ? compiler.topscope.exist?(variable_name) : false
      else
        other_scope.exist?(variable_name)
      end
    else
      next_scope = inherited_scope || enclosing_scope
      effective_symtable(true).include?(name) || next_scope && next_scope.exist?(name) || BUILT_IN_VARS.include?(name)
    end
  end

  # Returns true if the given name is bound in the current (most nested) scope for assignments.
  #
  def bound?(name)
    # Do not look in ephemeral (match scope), the semantics is to answer if an assignable variable is bound
    effective_symtable(false).bound?(name)
  end

  # Is the value true?  This allows us to control the definition of truth
  # in one place.
  def self.true?(value)
    case value
    when ''
      false
    when :undef
      false
    else
      !!value
    end
  end

  # Coerce value to a number, or return `nil` if it isn't one.
  def self.number?(value)
    case value
    when Numeric
      value
    when /^-?\d+(:?\.\d+|(:?\.\d+)?e\d+)$/
      value.to_f
    when /^0x[0-9a-f]+$/i
      value.to_i(16)
    when /^0[0-7]+$/
      value.to_i(8)
    when /^-?\d+$/
      value.to_i
    else
      nil
    end
  end

  def find_hostclass(name)
    environment.known_resource_types.find_hostclass(name)
  end

  def find_definition(name)
    environment.known_resource_types.find_definition(name)
  end

  def find_global_scope()
    # walk upwards until first found node_scope or top_scope
    if is_nodescope? || is_topscope?
      self
    else
      next_scope = inherited_scope || enclosing_scope
      if next_scope.nil?
        # this happens when testing, and there is only a single test scope and no link to any
        # other scopes
        self
      else
        next_scope.find_global_scope()
      end
    end
  end

  def findresource(type, title = nil)
    @compiler.catalog.resource(type, title)
  end

  # Initialize our new scope.  Defaults to having no parent.
  def initialize(compiler, options = EMPTY_HASH)
    if compiler.is_a? Puppet::Parser::AbstractCompiler
      @compiler = compiler
    else
      raise Puppet::DevError, _("you must pass a compiler instance to a new scope object")
    end

    set_options(options)

    extend_with_functions_module

    # The symbol table for this scope.  This is where we store variables.
    #    @symtable = Ephemeral.new(nil, true)
    @symtable = LocalScope.new(nil)

    @ephemeral = [ MatchScope.new(@symtable, nil) ]

    # All of the defaults set for types.  It's a hash of hashes,
    # with the first key being the type, then the second key being
    # the parameter.
    @defaults = Hash.new { |dhash,type|
      dhash[type] = {}
    }

    # The table for storing class singletons.  This will only actually
    # be used by top scopes and node scopes.
    @class_scopes = {}
  end

  # Store the fact that we've evaluated a class, and store a reference to
  # the scope in which it was evaluated, so that we can look it up later.
  def class_set(name, scope)
    if parent
      parent.class_set(name, scope)
    else
      @class_scopes[name] = scope
    end
  end

  # Return the scope associated with a class.  This is just here so
  # that subclasses can set their parent scopes to be the scope of
  # their parent class, and it's also used when looking up qualified
  # variables.
  def class_scope(klass)
    # They might pass in either the class or class name
    k = klass.respond_to?(:name) ? klass.name : klass
    @class_scopes[k] || (parent && parent.class_scope(k))
  end

  # Collect all of the defaults set at any higher scopes.
  # This is a different type of lookup because it's
  # additive -- it collects all of the defaults, with defaults
  # in closer scopes overriding those in later scopes.
  #
  # The lookupdefaults searches in the the order:
  #
  #   * inherited
  #   * contained (recursive)
  #   * self
  #
  def lookupdefaults(type)
    values = {}

    # first collect the values from the parents
    if parent
      parent.lookupdefaults(type).each { |var,value|
        values[var] = value
      }
    end

    # then override them with any current values
    # this should probably be done differently
    if @defaults.include?(type)
      @defaults[type].each { |var,value|
        values[var] = value
      }
    end

    values
  end

  # Check if the given value is a known default for the given type
  #
  def is_default?(type, key, value)
    defaults_for_type = @defaults[type]
    unless defaults_for_type.nil?
      default_param = defaults_for_type[key]
      return true if !default_param.nil? && value == default_param.value
    end
    !parent.nil? && parent.is_default?(type, key, value)
  end

  # Look up a defined type.
  def lookuptype(name)
    # This happens a lot, avoid making a call to make a call
    krt = environment.known_resource_types
    krt.find_definition(name) || krt.find_hostclass(name)
  end

  def undef_as(x,v)
    if v.nil? or v == :undef
      x
    else
      v
    end
  end

  # Lookup a variable within this scope using the Puppet language's
  # scoping rules. Variables can be qualified using just as in a
  # manifest.
  #
  # @param [String] name the variable name to lookup
  # @param [Hash] hash of options, only internal code should give this
  # @param [Boolean] if resolution is of the leaf of a qualified name - only internal code should give this
  # @return Object the value of the variable, or if not found; nil if `strict_variables` is false, and thrown :undefined_variable otherwise
  #
  # @api public
  def lookupvar(name, options = EMPTY_HASH)
    unless name.is_a? String
      raise Puppet::ParseError, _("Scope variable name %{name} is a %{klass}, not a string") % { name: name.inspect, klass: name.class }
    end

    # If name has '::' in it, it is resolved as a qualified variable
    unless (idx = name.index('::')).nil?
      # Always drop leading '::' if present as that is how the values are keyed.
      return lookup_qualified_variable(idx == 0 ? name[2..-1] : name, options)
    end

    # At this point, search is for a non qualified (simple) name
    table = @ephemeral.last
    val = table[name]
    return val unless val.nil? && !table.include?(name)

    next_scope = inherited_scope || enclosing_scope
    if next_scope
      next_scope.lookupvar(name, options)
    else
      variable_not_found(name)
    end
  end

  UNDEFINED_VARIABLES_KIND = 'undefined_variables'.freeze

  # The exception raised when a throw is uncaught is different in different versions
  # of ruby. In >=2.2.0 it is UncaughtThrowError (which did not exist prior to this)
  #
  UNCAUGHT_THROW_EXCEPTION = defined?(UncaughtThrowError) ? UncaughtThrowError : ArgumentError

  def variable_not_found(name, reason=nil)
    # Built in variables and numeric variables always exist
    if BUILT_IN_VARS.include?(name) || name =~ Puppet::Pops::Patterns::NUMERIC_VAR_NAME
      return nil
    end
    begin
      throw(:undefined_variable, reason)
    rescue  UNCAUGHT_THROW_EXCEPTION
      case Puppet[:strict]
      when :off
        # do nothing
      when :warning
        Puppet.warn_once(UNDEFINED_VARIABLES_KIND, _("Variable: %{name}") % { name: name },
        _("Undefined variable '%{name}'; %{reason}") % { name: name, reason: reason } )
      when :error
        raise ArgumentError, _("Undefined variable '%{name}'; %{reason}") % { name: name, reason: reason }
      end
    end
    nil
  end

  # Retrieves the variable value assigned to the name given as an argument. The name must be a String,
  # and namespace can be qualified with '::'. The value is looked up in this scope, its parent scopes,
  # or in a specific visible named scope.
  #
  # @param varname [String] the name of the variable (may be a qualified name using `(ns'::')*varname`
  # @param options [Hash] Additional options, not part of api.
  # @return [Object] the value assigned to the given varname
  # @see #[]=
  # @api public
  #
  def [](varname, options = EMPTY_HASH)
    lookupvar(varname, options)
  end

  # The class scope of the inherited thing of this scope's resource.
  #
  # @return [Puppet::Parser::Scope] The scope or nil if there is not an inherited scope
  def inherited_scope
    if resource && resource.type == TYPENAME_CLASS && !resource.resource_type.parent.nil?
      qualified_scope(resource.resource_type.parent)
    else
      nil
    end
  end

  # The enclosing scope (topscope or nodescope) of this scope.
  # The enclosing scopes are produced when a class or define is included at
  # some point. The parent scope of the included class or define becomes the
  # scope in which it was included. The chain of parent scopes is followed
  # until a node scope or the topscope is found
  #
  # @return [Puppet::Parser::Scope] The scope or nil if there is no enclosing scope
  def enclosing_scope
     if has_enclosing_scope?
      if parent.is_topscope? || parent.is_nodescope?
        parent
      else
        parent.enclosing_scope
      end
     end
  end

  def is_classscope?
    resource && resource.type == TYPENAME_CLASS
  end

  def is_nodescope?
    resource && resource.type == TYPENAME_NODE
  end

  def is_topscope?
    equal?(@compiler.topscope)
  end

  # @api private
  def lookup_qualified_variable(fqn, options)
    table = @compiler.qualified_variables
    val = table[fqn]
    return val if !val.nil? || table.include?(fqn)

    # not found - search inherited scope for class
    leaf_index = fqn.rindex('::')
    unless leaf_index.nil?
      leaf_name = fqn[ (leaf_index+2)..-1 ]
      class_name = fqn[ 0, leaf_index ]
      begin
        qs = qualified_scope(class_name)
        unless qs.nil?
          return qs.get_local_variable(leaf_name) if qs.has_local_variable?(leaf_name)
          iscope = qs.inherited_scope
          return lookup_qualified_variable("#{iscope.source.name}::#{leaf_name}", options) unless iscope.nil?
        end
      rescue RuntimeError => e
        # because a failure to find the class, or inherited should be reported against given name
        return handle_not_found(class_name, leaf_name, options, e.message)
      end
    end
    # report with leading '::' by using empty class_name
    return handle_not_found('', fqn, options)
  end

  # @api private
  def has_local_variable?(name)
    @ephemeral.last.include?(name)
  end

  # @api private
  def get_local_variable(name)
    @ephemeral.last[name]
  end

  def handle_not_found(class_name, variable_name, position, reason = nil)
    unless Puppet[:strict_variables]
      # Do not issue warning if strict variables are on, as an error will be raised by variable_not_found
      location = if position[:lineproc]
                   Puppet::Util::Errors.error_location_with_space(nil, position[:lineproc].call)
                 else
                   Puppet::Util::Errors.error_location_with_space(position[:file], position[:line])
                 end
      variable_not_found("#{class_name}::#{variable_name}", "#{reason}#{location}")
      return nil
    end
    variable_not_found("#{class_name}::#{variable_name}", reason)
  end

  def has_enclosing_scope?
    ! parent.nil?
  end
  private :has_enclosing_scope?

  def qualified_scope(classname)
    raise _("class %{classname} could not be found") % { classname: classname }     unless klass = find_hostclass(classname)
    raise _("class %{classname} has not been evaluated") % { classname: classname } unless kscope = class_scope(klass)
    kscope
  end
  private :qualified_scope

  # Returns a Hash containing all variables and their values, optionally (and
  # by default) including the values defined in parent. Local values
  # shadow parent values. Ephemeral scopes for match results ($0 - $n) are not included.
  #
  def to_hash(recursive = true)
    if recursive and has_enclosing_scope?
      target = enclosing_scope.to_hash(recursive)
      if !(inherited = inherited_scope).nil?
        target.merge!(inherited.to_hash(recursive))
      end
    else
      target = Hash.new
    end

    # add all local scopes
    @ephemeral.last.add_entries_to(target)
    target
  end

  # Create a new scope and set these options.
  def newscope(options = {})
    compiler.newscope(self, options)
  end

  def parent_module_name
    return nil unless @parent && @parent.source
    @parent.source.module_name
  end

  # Set defaults for a type.  The typename should already be downcased,
  # so that the syntax is isolated.  We don't do any kind of type-checking
  # here; instead we let the resource do it when the defaults are used.
  def define_settings(type, params)
    table = @defaults[type]

    # if we got a single param, it'll be in its own array
    params = [params] unless params.is_a?(Array)

    params.each { |param|
      if table.include?(param.name)
        raise Puppet::ParseError.new(_("Default already defined for %{type} { %{param} }; cannot redefine") % { type: type, param: param.name }, param.file, param.line)
      end
      table[param.name] = param
    }
  end

  # Merge all settings for the given _env_name_ into this scope
  # @param env_name [Symbol] the name of the environment
  # @param set_in_this_scope [Boolean] if the settings variables should also be set in this instance of scope
  def merge_settings(env_name, set_in_this_scope=true)
    settings = Puppet.settings
    table = effective_symtable(false)
    global_table = compiler.qualified_variables
    all_local = {}
    settings.each_key do |name|
      next if :name == name
      key = name.to_s
      value = transform_setting(settings.value_sym(name, env_name))
      if set_in_this_scope
        table[key] = value
      end
      all_local[key] = value
      # also write the fqn into global table for direct lookup
      global_table["settings::#{key}"] = value
    end
    # set the 'all_local' - a hash of all settings
    global_table["settings::all_local"] = all_local
    nil
  end

  def transform_setting(val)
    if val.is_a?(String) || val.is_a?(Numeric) || true == val || false == val || nil == val
      val
    elsif val.is_a?(Array)
      val.map {|entry| transform_setting(entry) }
    elsif val.is_a?(Hash)
      result = {}
      val.each {|k,v| result[transform_setting(k)] = transform_setting(v) }
      result
    else
      # not ideal, but required as there are settings values that are special
      :undef == val ? nil : val.to_s
    end
  end
  private :transform_setting

  VARNAME_TRUSTED = 'trusted'.freeze
  VARNAME_FACTS = 'facts'.freeze
  VARNAME_SERVER_FACTS = 'server_facts'.freeze
  RESERVED_VARIABLE_NAMES = [VARNAME_TRUSTED, VARNAME_FACTS].freeze
  TYPENAME_CLASS = 'Class'.freeze
  TYPENAME_NODE = 'Node'.freeze

  # Set a variable in the current scope.  This will override settings
  # in scopes above, but will not allow variables in the current scope
  # to be reassigned.
  #   It's preferred that you use self[]= instead of this; only use this
  # when you need to set options.
  def setvar(name, value, options = EMPTY_HASH)
    if name =~ /^[0-9]+$/
      raise Puppet::ParseError.new(_("Cannot assign to a numeric match result variable '$%{name}'") % { name: name }) # unless options[:ephemeral]
    end
    unless name.is_a? String
      raise Puppet::ParseError, _("Scope variable name %{name} is a %{class_type}, not a string") % { name: name.inspect, class_type: name.class }
    end

    # Check for reserved variable names
    if (name == VARNAME_TRUSTED || name == VARNAME_FACTS) && !options[:privileged]
      raise Puppet::ParseError, _("Attempt to assign to a reserved variable name: '%{name}'") % { name: name }
    end

    # Check for server_facts reserved variable name if the trusted_sever_facts setting is true
    if name == VARNAME_SERVER_FACTS && !options[:privileged] && Puppet[:trusted_server_facts]
      raise Puppet::ParseError, _("Attempt to assign to a reserved variable name: '%{name}'") % { name: name }
    end

    table = effective_symtable(options[:ephemeral])
    if table.bound?(name)
      error = Puppet::ParseError.new(_("Cannot reassign variable '$%{name}'") % { name: name })
      error.file = options[:file] if options[:file]
      error.line = options[:line] if options[:line]
      raise error
    end

    table[name] = value

    # Assign the qualified name in the environment
    # Note that Settings scope has a source set to Boolean true.
    #
    # Only meaningful to set a fqn globally if table to assign to is the top of the scope's ephemeral stack
    if @symtable.equal?(table)
      if is_topscope?
        # the scope name is '::'
        compiler.qualified_variables[name] = value
      elsif source.is_a?(Puppet::Resource::Type) && source.type == :hostclass
        # the name is the name of the class
        sourcename = source.name
        compiler.qualified_variables["#{sourcename}::#{name}"] = value
      end
    end
    value
  end

  def set_trusted(hash)
    setvar('trusted', deep_freeze(hash), :privileged => true)
  end

  def set_facts(hash)
    setvar('facts', deep_freeze(hash), :privileged => true)
  end

  def set_server_facts(hash)
    setvar('server_facts', deep_freeze(hash), :privileged => true)
  end

  # Deeply freezes the given object. The object and its content must be of the types:
  # Array, Hash, Numeric, Boolean, Symbol, Regexp, NilClass, or String. All other types raises an Error.
  # (i.e. if they are assignable to Puppet::Pops::Types::Data type).
  #
  def deep_freeze(object)
    case object
    when Array
      object.each {|v| deep_freeze(v) }
      object.freeze
    when Hash
      object.each {|k, v| deep_freeze(k); deep_freeze(v) }
      object.freeze
    when NilClass, Numeric, TrueClass, FalseClass
      # do nothing
    when String
      object.freeze
    else
      raise Puppet::Error, _("Unsupported data type: '%{klass}'") % { klass: object.class }
    end
    object
  end
  private :deep_freeze

  # Return the effective "table" for setting variables.
  # This method returns the first ephemeral "table" that acts as a local scope, or this
  # scope's symtable. If the parameter `use_ephemeral` is true, the "top most" ephemeral "table"
  # will be returned (irrespective of it being a match scope or a local scope).
  #
  # @param use_ephemeral [Boolean] whether the top most ephemeral (of any kind) should be used or not
  def effective_symtable(use_ephemeral)
    s = @ephemeral[-1]
    return s || @symtable if use_ephemeral

    while s && !s.is_local_scope?()
      s = s.parent
    end
    s || @symtable
  end

  # Sets the variable value of the name given as an argument to the given value. The value is
  # set in the current scope and may shadow a variable with the same name in a visible outer scope.
  # It is illegal to re-assign a variable in the same scope. It is illegal to set a variable in some other
  # scope/namespace than the scope passed to a method.
  #
  # @param varname [String] The variable name to which the value is assigned. Must not contain `::`
  # @param value [String] The value to assign to the given variable name.
  # @param options [Hash] Additional options, not part of api and no longer used.
  #
  # @api public
  #
  def []=(varname, value, _ = nil)
    setvar(varname, value)
  end

  # Used mainly for logging
  def to_s
    # As this is used for logging, this should really not be done in this class at all...
    return "Scope(#{@resource})" unless @resource.nil?

    # For logging of function-scope - it is now showing the file and line.
    detail = Puppet::Pops::PuppetStack.top_of_stack
    return "Scope()" if detail.empty?

    # shorten the path if possible
    path = detail[0]
    env_path = nil
    env_path = environment.configuration.path_to_env unless (environment.nil? || environment.configuration.nil?)
    # check module paths first since they may be in the environment (i.e. they are longer)
    if module_path = environment.full_modulepath.detect {|m_path| path.start_with?(m_path) }
      path = "<module>" + path[module_path.length..-1]
    elsif env_path && path && path.start_with?(env_path)
      path = "<env>" + path[env_path.length..-1]
    end
    # Make the output appear as "Scope(path, line)"
    "Scope(#{[path, detail[1]].join(', ')})" 
  end

  alias_method :inspect, :to_s

  # Pop ephemeral scopes up to level and return them
  #
  # @param level [Integer] a positive integer
  # @return [Array] the removed ephemeral scopes
  # @api private
  def pop_ephemerals(level)
    @ephemeral.pop(@ephemeral.size - level)
  end

  # Push ephemeral scopes onto the ephemeral scope stack
  # @param ephemeral_scopes [Array]
  # @api private
  def push_ephemerals(ephemeral_scopes)
    ephemeral_scopes.each { |ephemeral_scope| @ephemeral.push(ephemeral_scope) } unless ephemeral_scopes.nil?
  end

  def ephemeral_level
    @ephemeral.size
  end

  # TODO: Who calls this?
  def new_ephemeral(local_scope = false)
    if local_scope
      @ephemeral.push(LocalScope.new(@ephemeral.last))
    else
      @ephemeral.push(MatchScope.new(@ephemeral.last, nil))
    end
  end

  # Execute given block in global scope with no ephemerals present
  #
  # @yieldparam [Scope] global_scope the global and ephemeral less scope
  # @return [Object] the return of the block
  #
  # @api private
  def with_global_scope(&block)
    find_global_scope.without_ephemeral_scopes(&block)
  end

  # Execute given block with a ephemeral scope containing the given variables
  # @api private
  def with_local_scope(scope_variables)
    local = LocalScope.new(@ephemeral.last)
    scope_variables.each_pair { |k, v| local[k] = v }
    @ephemeral.push(local)
    begin
      yield(self)
    ensure
      @ephemeral.pop
    end
  end

  # Execute given block with all ephemeral popped from the ephemeral stack
  #
  # @api private
  def without_ephemeral_scopes
    save_ephemeral = @ephemeral
    begin
      @ephemeral = [ @symtable ]
      yield(self)
    ensure
      @ephemeral = save_ephemeral
    end
  end

  # Nests a parameter scope
  # @param [String] callee_name the name of the function, template, or resource that defines the parameters
  # @param [Array<String>] param_names list of parameter names
  # @yieldparam [ParameterScope] param_scope the nested scope
  # @api private
  def with_parameter_scope(callee_name, param_names)
    param_scope = ParameterScope.new(@ephemeral.last, callee_name, param_names)
    with_guarded_scope do
      @ephemeral.push(param_scope)
      yield(param_scope)
    end
  end

  # Execute given block and ensure that ephemeral level is restored
  #
  # @return [Object] the return of the block
  #
  # @api private
  def with_guarded_scope
    elevel = ephemeral_level
    begin
      yield
    ensure
      pop_ephemerals(elevel)
    end
  end

  # Sets match data in the most nested scope (which always is a MatchScope), it clobbers match data already set there
  #
  def set_match_data(match_data)
    @ephemeral.last.match_data = match_data
  end

  # Nests a match data scope
  def new_match_scope(match_data)
    @ephemeral.push(MatchScope.new(@ephemeral.last, match_data))
  end

  def ephemeral_from(match, file = nil, line = nil)
    case match
    when Hash
      # Create local scope ephemeral and set all values from hash
      new_ephemeral(true)
      match.each {|k,v| setvar(k, v, :file => file, :line => line, :ephemeral => true) }
      # Must always have an inner match data scope (that starts out as transparent)
      # In 3x slightly wasteful, since a new nested scope is created for a match
      # (TODO: Fix that problem)
      new_ephemeral(false)
    else
      raise(ArgumentError,_("Invalid regex match data. Got a %{klass}") % { klass: match.class }) unless match.is_a?(MatchData)
      # Create a match ephemeral and set values from match data
      new_match_scope(match)
    end
  end

  # @api private
  def find_resource_type(type)
    raise Puppet::DevError, _("Scope#find_resource_type() is no longer supported, use Puppet::Pops::Evaluator::Runtime3ResourceSupport instead")
  end

  # @api private
  def find_builtin_resource_type(type)
    raise Puppet::DevError, _("Scope#find_builtin_resource_type() is no longer supported, use Puppet::Pops::Evaluator::Runtime3ResourceSupport instead")
  end

  # @api private
  def find_defined_resource_type(type)
    raise Puppet::DevError, _("Scope#find_defined_resource_type() is no longer supported, use Puppet::Pops::Evaluator::Runtime3ResourceSupport instead")
  end


  def method_missing(method, *args, &block)
    method.to_s =~ /^function_(.*)$/
    name = $1
    super unless name
    super unless Puppet::Parser::Functions.function(name)
    # In odd circumstances, this might not end up defined by the previous
    # method, so we might as well be certain.
    if respond_to? method
      send(method, *args)
    else
      raise Puppet::DevError, _("Function %{name} not defined despite being loaded!") % { name: name }
    end
  end

  # To be removed when enough time has passed after puppet 5.0.0
  # @api private
  def resolve_type_and_titles(type, titles)
    raise Puppet::DevError, _("Scope#resolve_type_and_title() is no longer supported, use Puppet::Pops::Evaluator::Runtime3ResourceSupport instead")
  end

  # Transforms references to classes to the form suitable for
  # lookup in the compiler.
  #
  # Makes names passed in the names array absolute if they are relative.
  #
  # Transforms Class[] and Resource[] type references to class name
  # or raises an error if a Class[] is unspecific, if a Resource is not
  # a 'class' resource, or if unspecific (no title).
  #
  #
  # @param names [Array<String>] names to (optionally) make absolute
  # @return [Array<String>] names after transformation
  #
  def transform_and_assert_classnames(names)
    names.map do |name|
      case name
      when NilClass
        raise ArgumentError, _("Cannot use undef as a class name")
      when String
        raise ArgumentError, _("Cannot use empty string as a class name") if name.empty?
        name.sub(/^([^:]{1,2})/, '::\1')

      when Puppet::Resource
        assert_class_and_title(name.type, name.title)
        name.title.sub(/^([^:]{1,2})/, '::\1')

      when Puppet::Pops::Types::PClassType
        #TRANSLATORS "Class" and "Type" are Puppet keywords and should not be translated
        raise ArgumentError, _("Cannot use an unspecific Class[] Type") unless name.class_name
        name.class_name.sub(/^([^:]{1,2})/, '::\1')

      when Puppet::Pops::Types::PResourceType
        assert_class_and_title(name.type_name, name.title)
        name.title.sub(/^([^:]{1,2})/, '::\1')
      end.downcase
    end
  end

  # Calls a 3.x or 4.x function by name with arguments given in an array using the 4.x calling convention
  # and returns the result.
  # Note that it is the caller's responsibility to rescue the given ArgumentError and provide location information
  # to aid the user find the problem. The problem is otherwise reported against the source location that
  # invoked the function that ultimately called this method.
  #
  # @return [Object] the result of the called function
  # @raise ArgumentError if the function does not exist
  def call_function(func_name, args, &block)
    Puppet::Pops::Parser::EvaluatingParser.new.evaluator.external_call_function(func_name, args, self, &block)
  end

  private

  def assert_class_and_title(type_name, title)
    if type_name.nil? || type_name == ''
      #TRANSLATORS "Resource" is a class name and should not be translated
      raise ArgumentError, _("Cannot use an unspecific Resource[] where a Resource['class', name] is expected")
    end
    unless type_name =~ /^[Cc]lass$/
      #TRANSLATORS "Resource" is a class name and should not be translated
      raise ArgumentError, _("Cannot use a Resource[%{type_name}] where a Resource['class', name] is expected") % { type_name: type_name }
    end
    if title.nil?
      #TRANSLATORS "Resource" is a class name and should not be translated
      raise ArgumentError, _("Cannot use an unspecific Resource['class'] where a Resource['class', name] is expected")
    end
  end

  def extend_with_functions_module
    root = Puppet.lookup(:root_environment)
    extend Puppet::Parser::Functions.environment_module(root)
    extend Puppet::Parser::Functions.environment_module(environment) if environment != root
  end
end
