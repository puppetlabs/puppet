# The scope class, which handles storing and retrieving variables and types and
# such.

require 'puppet/parser/parser'
require 'puppet/parser/templatewrapper'
require 'puppet/transportable'
require 'strscan'

require 'puppet/resource/type_collection_helper'

class Puppet::Parser::Scope
  include Puppet::Resource::TypeCollectionHelper
  require 'puppet/parser/resource'

  AST = Puppet::Parser::AST

  Puppet::Util.logmethods(self)

  include Enumerable
  include Puppet::Util::Errors
  attr_accessor :source, :resource
  attr_accessor :base, :keyword
  attr_accessor :top, :translated, :compiler
  attr_accessor :parent, :dynamic
  attr_reader :namespaces

  # thin wrapper around an ephemeral
  # symbol table.
  # when a symbol
  class Ephemeral
    def initialize(parent=nil)
      @symbols = {}
      @parent = parent
    end

    [:include?, :delete, :[]=].each do |m|
      define_method(m) do |*args|
        @symbols.send(m, *args)
      end
    end

    def [](name)
      unless @symbols.include?(name) or @parent.nil?
        @parent[name]
      else
        @symbols[name]
      end
    end
  end

  # A demeterific shortcut to the catalog.
  def catalog
    compiler.catalog
  end

  def environment
    compiler.environment
  end

  # Proxy accessors
  def host
    @compiler.node.name
  end

  # Is the value true?  This allows us to control the definition of truth
  # in one place.
  def self.true?(value)
    (value != false and value != "" and value != :undef)
  end

  # Is the value a number?, return the correct object or nil if not a number
  def self.number?(value)
    return nil unless value.is_a?(Fixnum) or value.is_a?(Bignum) or value.is_a?(Float) or value.is_a?(String)

    if value.is_a?(String)
      if value =~ /^-?\d+(:?\.\d+|(:?\.\d+)?e\d+)$/
        return value.to_f
      elsif value =~ /^0x[0-9a-f]+$/i
        return value.to_i(16)
      elsif value =~ /^0[0-7]+$/
        return value.to_i(8)
      elsif value =~ /^-?\d+$/
        return value.to_i
      else
        return nil
      end
    end
    # it is one of Fixnum,Bignum or Float
    value
  end

  # Add to our list of namespaces.
  def add_namespace(ns)
    return false if @namespaces.include?(ns)
    if @namespaces == [""]
      @namespaces = [ns]
    else
      @namespaces << ns
    end
  end

  # Remove this when rebasing
  def environment
    compiler ? compiler.environment : nil
  end

  def find_hostclass(name)
    known_resource_types.find_hostclass(namespaces, name)
  end

  def find_definition(name)
    known_resource_types.find_definition(namespaces, name)
  end

  def findresource(string, name = nil)
    compiler.findresource(string, name)
  end

  # Initialize our new scope.  Defaults to having no parent.
  def initialize(hash = {})
    if hash.include?(:namespace)
      if n = hash[:namespace]
        @namespaces = [n]
      end
      hash.delete(:namespace)
    else
      @namespaces = [""]
    end
    hash.each { |name, val|
      method = name.to_s + "="
      if self.respond_to? method
        self.send(method, val)
      else
        raise Puppet::DevError, "Invalid scope argument #{name}"
      end
    }

    extend_with_functions_module

    @tags = []

    # The symbol table for this scope.  This is where we store variables.
    @symtable = {}

    # the ephemeral symbol tables
    # those should not persist long, and are used for the moment only
    # for $0..$xy capture variables of regexes
    # this is actually implemented as a stack, with each ephemeral scope
    # shadowing the previous one
    @ephemeral = [ Ephemeral.new ]

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
    return parent.class_set(name,scope) if parent
    @class_scopes[name] = scope
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
  # This is a different type of lookup because it's additive --
  # it collects all of the defaults, with defaults in closer scopes
  # overriding those in later scopes.
  def lookupdefaults(type)
    values = {}

    # first collect the values from the parents
    unless parent.nil?
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

    #Puppet.debug "Got defaults for %s: %s" %
    #    [type,values.inspect]
    values
  end

  # Look up a defined type.
  def lookuptype(name)
    find_definition(name) || find_hostclass(name)
  end

  def undef_as(x,v)
    (v == :undefined) ? x : (v == :undef) ? x : v
  end

  def qualified_scope(classname)
    raise "class #{classname} could not be found"     unless klass = find_hostclass(classname)
    raise "class #{classname} has not been evaluated" unless kscope = class_scope(klass)
    kscope
  end

  private :qualified_scope

  # Look up a variable.  The simplest value search we do.
  def lookupvar(name, options = {})
    table = ephemeral?(name) ? @ephemeral.last : @symtable
    # If the variable is qualified, then find the specified scope and look the variable up there instead.
    if name =~ /^(.*)::(.+)$/
      begin
        qualified_scope($1).lookupvar($2,options)
      rescue RuntimeError => e
        location = (options[:file] && options[:line]) ? " at #{options[:file]}:#{options[:line]}" : ''
        warning "Could not look up qualified variable '#{name}'; #{e.message}#{location}"
        :undefined
      end
    elsif ephemeral_include?(name) or table.include?(name)
      # We can't use "if table[name]" here because the value might be false
      if options[:dynamic] and self != compiler.topscope
        location = (options[:file] && options[:line]) ? " at #{options[:file]}:#{options[:line]}" : ''
        Puppet.deprecation_warning "Dynamic lookup of $#{name}#{location} is deprecated.  Support will be removed in Puppet 2.8.  Use a fully-qualified variable name (e.g., $classname::variable) or parameterized classes."
      end
      table[name]
    elsif parent
      parent.lookupvar(name,options.merge(:dynamic => (dynamic || options[:dynamic])))
    else
      :undefined
    end
  end

  # Return a hash containing our variables and their values, optionally (and
  # by default) including the values defined in our parent.  Local values
  # shadow parent values.
  def to_hash(recursive = true)
    target = parent.to_hash(recursive) if recursive and parent
    target ||= Hash.new
    @symtable.keys.each { |name|
      value = @symtable[name]
      if value == :undef
        target.delete(name)
      else
        target[name] = value
      end
    }
    target
  end

  def namespaces
    @namespaces.dup
  end

  # Create a new scope and set these options.
  def newscope(options = {})
    compiler.newscope(self, options)
  end

  def parent_module_name
    return nil unless @parent
    return nil unless @parent.source
    @parent.source.module_name
  end

  # Return the list of scopes up to the top scope, ordered with our own first.
  # This is used for looking up variables and defaults.
  def scope_path
    if parent
      [self, parent.scope_path].flatten.compact
    else
      [self]
    end
  end

  # Set defaults for a type.  The typename should already be downcased,
  # so that the syntax is isolated.  We don't do any kind of type-checking
  # here; instead we let the resource do it when the defaults are used.
  def setdefaults(type, params)
    table = @defaults[type]

    # if we got a single param, it'll be in its own array
    params = [params] unless params.is_a?(Array)

    params.each { |param|
      #Puppet.debug "Default for %s is %s => %s" %
      #    [type,ary[0].inspect,ary[1].inspect]
      if table.include?(param.name)
        raise Puppet::ParseError.new("Default already defined for #{type} { #{param.name} }; cannot redefine", param.line, param.file)
      end
      table[param.name] = param
    }
  end

  # Set a variable in the current scope.  This will override settings
  # in scopes above, but will not allow variables in the current scope
  # to be reassigned.
  def setvar(name,value, options = {})
    table = options[:ephemeral] ? @ephemeral.last : @symtable
    if table.include?(name)
      unless options[:append]
        error = Puppet::ParseError.new("Cannot reassign variable #{name}")
      else
        error = Puppet::ParseError.new("Cannot append, variable #{name} is defined in this scope")
      end
      error.file = options[:file] if options[:file]
      error.line = options[:line] if options[:line]
      raise error
    end

    unless options[:append]
      table[name] = value
    else # append case
      # lookup the value in the scope if it exists and insert the var
      table[name] = undef_as('',lookupvar(name))
      # concatenate if string, append if array, nothing for other types
      case value
      when Array
        table[name] += value
      when Hash
        raise ArgumentError, "Trying to append to a hash with something which is not a hash is unsupported" unless value.is_a?(Hash)
        table[name].merge!(value)
      else
        table[name] << value
      end
    end
  end

  # Return the tags associated with this scope.  It's basically
  # just our parents' tags, plus our type.  We don't cache this value
  # because our parent tags might change between calls.
  def tags
    resource.tags
  end

  # Used mainly for logging
  def to_s
    "Scope(#{@resource})"
  end

  # Undefine a variable; only used for testing.
  def unsetvar(var)
    table = ephemeral?(var) ? @ephemeral.last : @symtable
    table.delete(var) if table.include?(var)
  end

  # remove ephemeral scope up to level
  def unset_ephemeral_var(level=:all)
    if level == :all
      @ephemeral = [ Ephemeral.new ]
    else
      (@ephemeral.size - level).times do
        @ephemeral.pop
      end
    end
  end

  # check if name exists in one of the ephemeral scope.
  def ephemeral_include?(name)
    @ephemeral.reverse.each do |eph|
      return true if eph.include?(name)
    end
    false
  end

  # is name an ephemeral variable?
  def ephemeral?(name)
    name =~ /^\d+$/
  end

  def ephemeral_level
    @ephemeral.size
  end

  def new_ephemeral
    @ephemeral.push(Ephemeral.new(@ephemeral.last))
  end

  def ephemeral_from(match, file = nil, line = nil)
    raise(ArgumentError,"Invalid regex match data") unless match.is_a?(MatchData)

    new_ephemeral

    setvar("0", match[0], :file => file, :line => line, :ephemeral => true)
    match.captures.each_with_index do |m,i|
      setvar("#{i+1}", m, :file => file, :line => line, :ephemeral => true)
    end
  end

  def find_resource_type(type)
    # It still works fine without the type == 'class' short-cut, but it is a lot slower.
    return nil if ["class", "node"].include? type.to_s.downcase
    find_builtin_resource_type(type) || find_defined_resource_type(type)
  end

  def find_builtin_resource_type(type)
    Puppet::Type.type(type.to_s.downcase.to_sym)
  end

  def find_defined_resource_type(type)
    environment.known_resource_types.find_definition(namespaces, type.to_s.downcase)
  end

  def method_missing(method, *args, &block)
    method.to_s =~ /^function_(.*)$/
    super unless $1
    super unless Puppet::Parser::Functions.function($1)

    # Calling .function(name) adds "function_#{name}" as a callable method on
    # self if it's found, so now we can just send it
    send(method, *args)
  end

  def resolve_type_and_titles(type, titles)
    raise ArgumentError, "titles must be an array" unless titles.is_a?(Array)

    case type.downcase
    when "class"
      # resolve the titles
      titles = titles.collect do |a_title|
        hostclass = find_hostclass(a_title)
        hostclass ?  hostclass.name : a_title
      end
    when "node"
      # no-op
    else
      # resolve the type
      resource_type = find_resource_type(type)
      type = resource_type.name if resource_type
    end

    return [type, titles]
  end

  private

  def extend_with_functions_module
    extend Puppet::Parser::Functions.environment_module(Puppet::Node::Environment.root)
    extend Puppet::Parser::Functions.environment_module(environment)
  end
end
