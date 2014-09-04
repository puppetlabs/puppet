require 'puppet'
require 'puppet/util/tagging'
require 'puppet/util/pson'
require 'puppet/parameter'

# The simplest resource class.  Eventually it will function as the
# base class for all resource-like behaviour.
#
# @api public
class Puppet::Resource
  # This stub class is only needed for serialization compatibility with 0.25.x.
  # Specifically, it exists to provide a compatibility API when using YAML
  # serialized objects loaded from StoreConfigs.
  Reference = Puppet::Resource

  include Puppet::Util::Tagging

  extend Puppet::Util::Pson
  include Enumerable
  attr_accessor :file, :line, :catalog, :exported, :virtual, :validate_parameters, :strict
  attr_reader :type, :title

  require 'puppet/indirector'
  extend Puppet::Indirector
  indirects :resource, :terminus_class => :ral

  ATTRIBUTES = [:file, :line, :exported]

  def self.from_data_hash(data)
    raise ArgumentError, "No resource type provided in serialized data" unless type = data['type']
    raise ArgumentError, "No resource title provided in serialized data" unless title = data['title']

    resource = new(type, title)

    if params = data['parameters']
      params.each { |param, value| resource[param] = value }
    end

    if tags = data['tags']
      tags.each { |tag| resource.tag(tag) }
    end

    ATTRIBUTES.each do |a|
      if value = data[a.to_s]
        resource.send(a.to_s + "=", value)
      end
    end

    resource
  end

  def self.from_pson(pson)
    Puppet.deprecation_warning("from_pson is being removed in favour of from_data_hash.")
    self.from_data_hash(pson)
  end

  def inspect
    "#{@type}[#{@title}]#{to_hash.inspect}"
  end

  def to_data_hash
    data = ([:type, :title, :tags] + ATTRIBUTES).inject({}) do |hash, param|
      next hash unless value = self.send(param)
      hash[param.to_s] = value
      hash
    end

    data["exported"] ||= false

    params = self.to_hash.inject({}) do |hash, ary|
      param, value = ary

      # Don't duplicate the title as the namevar
      next hash if param == namevar and value == title

      hash[param] = Puppet::Resource.value_to_pson_data(value)
      hash
    end

    data["parameters"] = params unless params.empty?

    data
  end

  # This doesn't include document type as it is part of a catalog
  def to_pson_data_hash
    to_data_hash
  end

  def self.value_to_pson_data(value)
    if value.is_a? Array
      value.map{|v| value_to_pson_data(v) }
    elsif value.is_a? Puppet::Resource
      value.to_s
    else
      value
    end
  end

  def yaml_property_munge(x)
    case x
    when Hash
      x.inject({}) { |h,kv|
        k,v = kv
        h[k] = self.class.value_to_pson_data(v)
        h
      }
    else self.class.value_to_pson_data(x)
    end
  end

  YAML_ATTRIBUTES = [:@file, :@line, :@exported, :@type, :@title, :@tags, :@parameters]

  # Explicitly list the instance variables that should be serialized when
  # converting to YAML.
  #
  # @api private
  # @return [Array<Symbol>] The intersection of our explicit variable list and
  #   all of the instance variables defined on this class.
  def to_yaml_properties
    YAML_ATTRIBUTES & super
  end

  def to_pson(*args)
    to_data_hash.to_pson(*args)
  end

  # Proxy these methods to the parameters hash.  It's likely they'll
  # be overridden at some point, but this works for now.
  %w{has_key? keys length delete empty? <<}.each do |method|
    define_method(method) do |*args|
      parameters.send(method, *args)
    end
  end

  # Set a given parameter.  Converts all passed names
  # to lower-case symbols.
  def []=(param, value)
    validate_parameter(param) if validate_parameters
    parameters[parameter_name(param)] = value
  end

  # Return a given parameter's value.  Converts all passed names
  # to lower-case symbols.
  def [](param)
    parameters[parameter_name(param)]
  end

  def ==(other)
    return false unless other.respond_to?(:title) and self.type == other.type and self.title == other.title

    return false unless to_hash == other.to_hash
    true
  end

  # Compatibility method.
  def builtin?
    builtin_type?
  end

  # Is this a builtin resource type?
  def builtin_type?
    resource_type.is_a?(Class)
  end

  # Iterate over each param/value pair, as required for Enumerable.
  def each
    parameters.each { |p,v| yield p, v }
  end

  def include?(parameter)
    super || parameters.keys.include?( parameter_name(parameter) )
  end

  %w{exported virtual strict}.each do |m|
    define_method(m+"?") do
      self.send(m)
    end
  end

  def class?
    @is_class ||= @type == "Class"
  end

  def stage?
    @is_stage ||= @type.to_s.downcase == "stage"
  end

  # Cache to reduce respond_to? lookups
  @@nondeprecating_type = {}

  # Construct a resource from data.
  #
  # Constructs a resource instance with the given `type` and `title`. Multiple
  # type signatures are possible for these arguments and most will result in an
  # expensive call to {Puppet::Node::Environment#known_resource_types} in order
  # to resolve `String` and `Symbol` Types to actual Ruby classes.
  #
  # @param type [Symbol, String] The name of the Puppet Type, as a string or
  #   symbol. The actual Type will be looked up using
  #   {Puppet::Node::Environment#known_resource_types}. This lookup is expensive.
  # @param type [String] The full resource name in the form of
  #   `"Type[Title]"`. This method of calling should only be used when
  #   `title` is `nil`.
  # @param type [nil] If a `nil` is passed, the title argument must be a string
  #   of the form `"Type[Title]"`.
  # @param type [Class] A class that inherits from `Puppet::Type`. This method
  #   of construction is much more efficient as it skips calls to
  #   {Puppet::Node::Environment#known_resource_types}.
  #
  # @param title [String, :main, nil] The title of the resource. If type is `nil`, may also
  #   be the full resource name in the form of `"Type[Title]"`.
  #
  # @api public
  def initialize(type, title = nil, attributes = {})
    @parameters = {}
    if type.is_a?(Class) && type < Puppet::Type
      # Set the resource type to avoid an expensive `known_resource_types`
      # lookup.
      self.resource_type = type
      # From this point on, the constructor behaves the same as if `type` had
      # been passed as a symbol.
      type = type.name
    end

    # Set things like strictness first.
    attributes.each do |attr, value|
      next if attr == :parameters
      send(attr.to_s + "=", value)
    end

    @type, @title = extract_type_and_title(type, title)

    @type = munge_type_name(@type)

    if self.class?
      @title = :main if @title == ""
      @title = munge_type_name(@title)
    end

    if params = attributes[:parameters]
      extract_parameters(params)
    end

    if resource_type and ! @@nondeprecating_type[resource_type]
      if resource_type.respond_to?(:deprecate_params)
        resource_type.deprecate_params(title, attributes[:parameters])
      else
        @@nondeprecating_type[resource_type] = true
      end
    end

    tag(self.type)
    tag(self.title) if valid_tag?(self.title)

    @reference = self # for serialization compatibility with 0.25.x
    if strict? and ! resource_type
      if self.class?
        raise ArgumentError, "Could not find declared class #{title}"
      else
        raise ArgumentError, "Invalid resource type #{type}"
      end
    end
  end

  def ref
    to_s
  end

  # Find our resource.
  def resolve
    catalog ? catalog.resource(to_s) : nil
  end

  # The resource's type implementation
  # @return [Puppet::Type, Puppet::Resource::Type]
  # @api private
  def resource_type
    @rstype ||= case type
    when "Class"; environment.known_resource_types.hostclass(title == :main ? "" : title)
    when "Node"; environment.known_resource_types.node(title)
    else
      Puppet::Type.type(type) || environment.known_resource_types.definition(type)
    end
  end

  # Set the resource's type implementation
  # @param type [Puppet::Type, Puppet::Resource::Type]
  # @api private
  def resource_type=(type)
    @rstype = type
  end

  def environment
    @environment ||= if catalog
                       catalog.environment_instance
                     else
                       Puppet.lookup(:current_environment) { Puppet::Node::Environment::NONE }
                     end
  end

  def environment=(environment)
    @environment = environment
  end

  # Produce a simple hash of our parameters.
  def to_hash
    parse_title.merge parameters
  end

  def to_s
    "#{type}[#{title}]"
  end

  def uniqueness_key
    # Temporary kludge to deal with inconsistant use patters
    h = self.to_hash
    h[namevar] ||= h[:name]
    h[:name]   ||= h[namevar]
    h.values_at(*key_attributes.sort_by { |k| k.to_s })
  end

  def key_attributes
    resource_type.respond_to?(:key_attributes) ? resource_type.key_attributes : [:name]
  end

  # Convert our resource to Puppet code.
  def to_manifest
    # Collect list of attributes to align => and move ensure first
    attr = parameters.keys
    attr_max = attr.inject(0) { |max,k| k.to_s.length > max ? k.to_s.length : max }

    attr.sort!
    if attr.first != :ensure  && attr.include?(:ensure)
      attr.delete(:ensure)
      attr.unshift(:ensure)
    end

    attributes = attr.collect { |k|
      v = parameters[k]
      "  %-#{attr_max}s => %s,\n" % [k, Puppet::Parameter.format_value_for_display(v)]
    }.join

    "%s { '%s':\n%s}" % [self.type.to_s.downcase, self.title, attributes]
  end

  def to_ref
    ref
  end

  # Convert our resource to a RAL resource instance.  Creates component
  # instances for resource types that don't exist.
  def to_ral
    typeklass = Puppet::Type.type(self.type) || Puppet::Type.type(:component)
    typeklass.new(self)
  end

  def name
    # this is potential namespace conflict
    # between the notion of an "indirector name"
    # and a "resource name"
    [ type, title ].join('/')
  end

  def missing_arguments
    resource_type.arguments.select do |param, default|
      param = param.to_sym
      parameters[param].nil? || parameters[param].value == :undef
    end
  end
  private :missing_arguments

  # Consult external data bindings for class parameter values which must be
  # namespaced in the backend.
  #
  # Example:
  #
  #   class foo($port=0){ ... }
  #
  # We make a request to the backend for the key 'foo::port' not 'foo'
  #
  def lookup_external_default_for(param, scope)
    # Only lookup parameters for host classes
    return nil unless resource_type.type == :hostclass

    name = "#{resource_type.name}::#{param}"
    lookup_with_databinding(name, scope)
  end

  private :lookup_external_default_for

  def lookup_with_databinding(name, scope)
    begin
      Puppet::DataBinding.indirection.find(
        name,
        :environment => scope.environment.to_s,
        :variables => scope)
    rescue Puppet::DataBinding::LookupError => e
      raise Puppet::Error.new("Error from DataBinding '#{Puppet[:data_binding_terminus]}' while looking up '#{name}': #{e.message}", e)
    end
  end

  private :lookup_with_databinding

  def set_default_parameters(scope)
    return [] unless resource_type and resource_type.respond_to?(:arguments)

    unless is_a?(Puppet::Parser::Resource)
      fail Puppet::DevError, "Cannot evaluate default parameters for #{self} - not a parser resource"
    end

    missing_arguments.collect do |param, default|
      external_value = lookup_external_default_for(param, scope)

      if external_value.nil? && default.nil?
        next
      elsif external_value.nil?
        value = default.safeevaluate(scope)
      else
        value = external_value
      end

      self[param.to_sym] = value
      param
    end.compact
  end

  def copy_as_resource
    result = Puppet::Resource.new(type, title)

    result.file = self.file
    result.line = self.line
    result.exported = self.exported
    result.virtual = self.virtual
    result.tag(*self.tags)
    result.environment = environment
    result.instance_variable_set(:@rstype, resource_type)

    to_hash.each do |p, v|
      if v.is_a?(Puppet::Resource)
        v = Puppet::Resource.new(v.type, v.title)
      elsif v.is_a?(Array)
        # flatten resource references arrays
        v = v.flatten if v.flatten.find { |av| av.is_a?(Puppet::Resource) }
        v = v.collect do |av|
          av = Puppet::Resource.new(av.type, av.title) if av.is_a?(Puppet::Resource)
          av
        end
      end

      if Puppet[:parser] == 'current'
        # If the value is an array with only one value, then
        # convert it to a single value.  This is largely so that
        # the database interaction doesn't have to worry about
        # whether it returns an array or a string.
        #
        # This behavior is not done in the future parser, but we can't issue a
        # deprecation warning either since there isn't anything that a user can
        # do about it.
        result[p] = if v.is_a?(Array) and v.length == 1
                      v[0]
                    else
                      v
                    end
      else
        result[p] = v
      end
    end

    result
  end

  def valid_parameter?(name)
    resource_type.valid_parameter?(name)
  end

  # Verify that all required arguments are either present or
  # have been provided with defaults.
  # Must be called after 'set_default_parameters'.  We can't join the methods
  # because Type#set_parameters needs specifically ordered behavior.
  def validate_complete
    return unless resource_type and resource_type.respond_to?(:arguments)

    resource_type.arguments.each do |param, default|
      param = param.to_sym
      fail Puppet::ParseError, "Must pass #{param} to #{self}" unless parameters.include?(param)
    end

    # Perform optional type checking
    if Puppet[:parser] == 'future'
      # Perform type checking
      arg_types = resource_type.argument_types
      # Parameters is a map from name, to parameter, and the parameter again has name and value
      parameters.each do |name, value|
        next unless t = arg_types[name.to_s]  # untyped, and parameters are symbols here (aargh, strings in the type)
        unless Puppet::Pops::Types::TypeCalculator.instance?(t, value.value)
          inferred_type = Puppet::Pops::Types::TypeCalculator.infer(value.value)
          actual = Puppet::Pops::Types::TypeCalculator.generalize!(inferred_type)
          fail Puppet::ParseError, "Expected parameter '#{name}' of '#{self}' to have type #{t.to_s}, got #{actual.to_s}"
        end
      end
    end
  end

  def validate_parameter(name)
    raise ArgumentError, "Invalid parameter #{name}" unless valid_parameter?(name)
  end

  def prune_parameters(options = {})
    properties = resource_type.properties.map(&:name)

    dup.collect do |attribute, value|
      if value.to_s.empty? or Array(value).empty?
        delete(attribute)
      elsif value.to_s == "absent" and attribute.to_s != "ensure"
        delete(attribute)
      end

      parameters_to_include = options[:parameters_to_include] || []
      delete(attribute) unless properties.include?(attribute) || parameters_to_include.include?(attribute)
    end
    self
  end

  private

  # Produce a canonical method name.
  def parameter_name(param)
    param = param.to_s.downcase.to_sym
    if param == :name and namevar
      param = namevar
    end
    param
  end

  # The namevar for our resource type. If the type doesn't exist,
  # always use :name.
  def namevar
    if builtin_type? and t = resource_type and t.key_attributes.length == 1
      t.key_attributes.first
    else
      :name
    end
  end

  def extract_parameters(params)
    params.each do |param, value|
      validate_parameter(param) if strict?
      self[param] = value
    end
  end

  def extract_type_and_title(argtype, argtitle)
    if    (argtype.nil? || argtype == :component || argtype == :whit) &&
           argtitle =~ /^([^\[\]]+)\[(.+)\]$/m                 then [ $1,                 $2            ]
    elsif argtitle.nil? && argtype =~ /^([^\[\]]+)\[(.+)\]$/m  then [ $1,                 $2            ]
    elsif argtitle                                             then [ argtype,            argtitle      ]
    elsif argtype.is_a?(Puppet::Type)                          then [ argtype.class.name, argtype.title ]
    elsif argtype.is_a?(Hash)                                  then
      raise ArgumentError, "Puppet::Resource.new does not take a hash as the first argument. "+
        "Did you mean (#{(argtype[:type] || argtype["type"]).inspect}, #{(argtype[:title] || argtype["title"]).inspect }) ?"
    else raise ArgumentError, "No title provided and #{argtype.inspect} is not a valid resource reference"
    end
  end

  def munge_type_name(value)
    return :main if value == :main
    return "Class" if value == "" or value.nil? or value.to_s.downcase == "component"

    value.to_s.split("::").collect { |s| s.capitalize }.join("::")
  end

  def parse_title
    h = {}
    type = resource_type
    if type.respond_to? :title_patterns
      type.title_patterns.each { |regexp, symbols_and_lambdas|
        if captures = regexp.match(title.to_s)
          symbols_and_lambdas.zip(captures[1..-1]).each do |symbol_and_lambda,capture|
            symbol, proc = symbol_and_lambda
            # Many types pass "identity" as the proc; we might as well give
            # them a shortcut to delivering that without the extra cost.
            #
            # Especially because the global type defines title_patterns and
            # uses the identity patterns.
            #
            # This was worth about 8MB of memory allocation saved in my
            # testing, so is worth the complexity for the API.
            if proc then
              h[symbol] = proc.call(capture)
            else
              h[symbol] = capture
            end
          end
          return h
        end
      }
      # If we've gotten this far, then none of the provided title patterns
      # matched. Since there's no way to determine the title then the
      # resource should fail here.
      raise Puppet::Error, "No set of title patterns matched the title \"#{title}\"."
    else
      return { :name => title.to_s }
    end
  end

  def parameters
    # @parameters could have been loaded from YAML, causing it to be nil (by
    # bypassing initialize).
    @parameters ||= {}
  end
end
