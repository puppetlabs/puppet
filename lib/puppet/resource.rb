# frozen_string_literal: true

require_relative '../puppet'
require_relative '../puppet/util/tagging'
require_relative '../puppet/parameter'

# The simplest resource class.  Eventually it will function as the
# base class for all resource-like behaviour.
#
# @api public
class Puppet::Resource
  include Puppet::Util::Tagging
  include Puppet::Util::PsychSupport

  include Enumerable
  attr_accessor :file, :line, :catalog, :exported, :virtual, :strict, :kind
  attr_reader :type, :title, :parameters

  # @!attribute [rw] sensitive_parameters
  #   @api private
  #   @return [Array<Symbol>] A list of parameters to be treated as sensitive
  attr_accessor :sensitive_parameters

  # @deprecated
  attr_accessor :validate_parameters

  require_relative '../puppet/indirector'
  extend Puppet::Indirector
  indirects :resource, :terminus_class => :ral

  EMPTY_ARRAY = [].freeze
  EMPTY_HASH = {}.freeze

  ATTRIBUTES = [:file, :line, :exported, :kind].freeze
  TYPE_CLASS = 'Class'
  TYPE_NODE  = 'Node'

  CLASS_STRING = 'class'
  DEFINED_TYPE_STRING = 'defined_type'
  COMPILABLE_TYPE_STRING = 'compilable_type'
  UNKNOWN_TYPE_STRING = 'unknown'

  PCORE_TYPE_KEY = '__ptype'
  VALUE_KEY = 'value'

  def self.from_data_hash(data)
    resource = self.allocate
    resource.initialize_from_hash(data)
    resource
  end

  def initialize_from_hash(data)
    type = data['type']
    raise ArgumentError, _('No resource type provided in serialized data') unless type

    title = data['title']
    raise ArgumentError, _('No resource title provided in serialized data') unless title

    @type, @title = self.class.type_and_title(type, title)

    params = data['parameters']
    if params
      params = Puppet::Pops::Serialization::FromDataConverter.convert(params)
      @parameters = {}
      params.each { |param, value| self[param] = value }
    else
      @parameters = EMPTY_HASH
    end

    sensitives = data['sensitive_parameters']
    if sensitives
      @sensitive_parameters = sensitives.map(&:to_sym)
    else
      @sensitive_parameters = EMPTY_ARRAY
    end

    tags = data['tags']
    if tags
      tag(*tags)
    end

    ATTRIBUTES.each do |a|
      value = data[a.to_s]
      send("#{a}=", value) unless value.nil?
    end
  end

  def inspect
    "#{@type}[#{@title}]#{to_hash.inspect}"
  end

  # Produces a Data compliant hash of the resource.
  # The result depends on the --rich_data setting, and the context value
  # for Puppet.lookup(:stringify_rich), that if it is `true` will use the
  # ToStringifiedConverter to produce the value per parameter.
  # (Note that the ToStringifiedConverter output is lossy and should not
  # be used when producing a catalog serialization).
  #
  def to_data_hash
    data = {
      'type' => type,
      'title' => title.to_s,
      'tags' => tags.to_data_hash
    }
    ATTRIBUTES.each do |param|
      value = send(param)
      data[param.to_s] = value unless value.nil?
    end

    data['exported'] ||= false

    # To get stringified parameter values the flag :stringify_rich can be set
    # in the puppet context.
    #
    stringify = Puppet.lookup(:stringify_rich) { false }
    converter = stringify ? Puppet::Pops::Serialization::ToStringifiedConverter.new : nil

    params = {}
    self.to_hash.each_pair do |param, value|
      # Don't duplicate the title as the namevar
      unless param == namevar && value == title
        if stringify
          params[param.to_s] = converter.convert(value)
        else
          params[param.to_s] = Puppet::Resource.value_to_json_data(value)
        end
      end
    end

    unless params.empty?
      data['parameters'] =
        Puppet::Pops::Serialization::ToDataConverter
        .convert(params,
                 {
                   :rich_data => Puppet.lookup(:rich_data),
                   :symbol_as_string => true,
                   :local_reference => false,
                   :type_by_reference => true,
                   :message_prefix => ref,
                   :semantic => self
                 })
    end

    data['sensitive_parameters'] = sensitive_parameters.map(&:to_s) unless sensitive_parameters.empty?
    data
  end

  def self.value_to_json_data(value)
    if value.is_a?(Array)
      value.map { |v| value_to_json_data(v) }
    elsif value.is_a?(Hash)
      result = {}
      value.each_pair { |k, v| result[value_to_json_data(k)] = value_to_json_data(v) }
      result
    elsif value.is_a?(Puppet::Resource)
      value.to_s
    elsif value.is_a?(Symbol) && value == :undef
      nil
    else
      value
    end
  end

  def yaml_property_munge(x)
    self.value.to_json_data(x)
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
    # TODO: should be deprecated (was only used in one place in puppet codebase)
    builtin_type?
  end

  # Is this a builtin resource type?
  def builtin_type?
    # Note - old implementation only checked if the resource_type was a Class
    resource_type.is_a?(Puppet::CompilableResourceType)
  end

  def self.to_kind(resource_type)
    if resource_type == CLASS_STRING
      CLASS_STRING
    elsif resource_type.is_a?(Puppet::Resource::Type) && resource_type.type == :definition
      DEFINED_TYPE_STRING
    elsif resource_type.is_a?(Puppet::CompilableResourceType)
      COMPILABLE_TYPE_STRING
    else
      UNKNOWN_TYPE_STRING
    end
  end

  # Iterate over each param/value pair, as required for Enumerable.
  def each
    parameters.each { |p, v| yield p, v }
  end

  def include?(parameter)
    super || parameters.keys.include?(parameter_name(parameter))
  end

  %w{exported virtual strict}.each do |m|
    define_method(m + "?") do
      self.send(m)
    end
  end

  def class?
    @is_class ||= @type == TYPE_CLASS
  end

  def stage?
    @is_stage ||= @type.to_s.casecmp("stage").zero?
  end

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
  def initialize(type, title = nil, attributes = EMPTY_HASH)
    @parameters = {}
    @sensitive_parameters = []
    if type.is_a?(Puppet::Resource)
      # Copy constructor. Let's avoid munging, extracting, tagging, etc
      src = type
      self.file = src.file
      self.line = src.line
      self.kind = src.kind
      self.exported = src.exported
      self.virtual = src.virtual
      self.set_tags(src)
      self.environment = src.environment
      @rstype = src.resource_type
      @type = src.type
      @title = src.title

      src.to_hash.each do |p, v|
        case v
        when Puppet::Resource
          v = v.copy_as_resource
        when Array
          # flatten resource references arrays
          v = v.flatten if v.flatten.find { |av| av.is_a?(Puppet::Resource) }
          v = v.collect do |av|
            av = av.copy_as_resource if av.is_a?(Puppet::Resource)
            av
          end
        end

        self[p] = v
      end
      @sensitive_parameters.replace(type.sensitive_parameters)
    else
      if type.is_a?(Hash)
        # TRANSLATORS 'Puppet::Resource.new' should not be translated
        raise ArgumentError, _("Puppet::Resource.new does not take a hash as the first argument.") + ' ' +
                             _("Did you mean (%{type}, %{title}) ?") %
                             { type: (type[:type] || type["type"]).inspect, title: (type[:title] || type["title"]).inspect }
      end

      # In order to avoid an expensive search of 'known_resource_types" and
      # to obey/preserve the implementation of the resource's type - if the
      # given type is a resource type implementation (one of):
      #   * a "classic" 3.x ruby plugin
      #   * a compatible implementation (e.g. loading from pcore metadata)
      #   * a resolved user defined type
      #
      # ...then, modify the parameters to the "old" (agent side compatible) way
      # of describing the type/title with string/symbols.
      #
      # TODO: Further optimizations should be possible as the "type juggling" is
      # not needed when the type implementation is known.
      #
      if type.is_a?(Puppet::CompilableResourceType) || type.is_a?(Puppet::Resource::Type)
        # set the resource type implementation
        self.resource_type = type
        # set the type name to the symbolic name
        type = type.name
      end
      @exported = false

      # Set things like environment, strictness first.
      attributes.each do |attr, value|
        next if attr == :parameters

        send(attr.to_s + "=", value)
      end

      if environment.is_a?(Puppet::Node::Environment) && environment != Puppet::Node::Environment::NONE
        self.file = environment.externalize_path(attributes[:file])
      end

      @type, @title = self.class.type_and_title(type, title)

      rt = resource_type

      self.kind = self.class.to_kind(rt) unless kind
      if strict? && rt.nil?
        if self.class?
          raise ArgumentError, _("Could not find declared class %{title}") % { title: title }
        else
          raise ArgumentError, _("Invalid resource type %{type}") % { type: type }
        end
      end

      params = attributes[:parameters]
      unless params.nil? || params.empty?
        extract_parameters(params)
        if rt && rt.respond_to?(:deprecate_params)
          rt.deprecate_params(title, params)
        end
      end

      tag(self.type)
      tag_if_valid(self.title)
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
    @rstype ||= self.class.resource_type(type, title, environment)
  end

  # The resource's type implementation
  # @return [Puppet::Type, Puppet::Resource::Type]
  # @api private
  def self.resource_type(type, title, environment)
    case type
    when TYPE_CLASS; environment.known_resource_types.hostclass(title == :main ? "" : title)
    when TYPE_NODE; environment.known_resource_types.node(title)
    else
      result = Puppet::Type.type(type)
      unless result
        krt = environment.known_resource_types
        result = krt.definition(type)
      end
      result
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

  # Produces a hash of attribute to value mappings where the title parsed into its components
  # acts as the default values overridden by any parameter values explicitly given as parameters.
  #
  def to_hash
    parse_title.merge parameters
  end

  def to_s
    "#{type}[#{title}]"
  end

  def uniqueness_key
    # Temporary kludge to deal with inconsistent use patterns; ensure we don't return nil for namevar/:name
    h = self.to_hash
    name = h[namevar] || h[:name] || self.name
    h[namevar] ||= name
    h[:name]   ||= name
    h.values_at(*key_attributes.sort_by { |k| k.to_s })
  end

  def key_attributes
    resource_type.respond_to?(:key_attributes) ? resource_type.key_attributes : [:name]
  end

  # Convert our resource to yaml for Hiera purposes.
  #
  # @deprecated Use {to_hiera_hash} instead.
  def to_hierayaml
    # Collect list of attributes to align => and move ensure first
    attr = parameters.keys
    attr_max = attr.inject(0) { |max, k| k.to_s.length > max ? k.to_s.length : max }

    attr.sort!
    if attr.first != :ensure && attr.include?(:ensure)
      attr.delete(:ensure)
      attr.unshift(:ensure)
    end

    # rubocop:disable Lint/FormatParameterMismatch
    attributes = attr.collect { |k|
      v = parameters[k]
      "    %-#{attr_max}s: %s\n" % [k, Puppet::Parameter.format_value_for_display(v)]
    }.join
    # rubocop:enable Lint/FormatParameterMismatch

    "  %s:\n%s" % [self.title, attributes]
  end

  # Convert our resource to a hiera hash suitable for serialization.
  def to_hiera_hash
    # to_data_hash converts to safe Data types, e.g. no symbols, unicode replacement character
    h = to_data_hash

    params = h['parameters'] || {}
    value = params.delete('ensure')

    res = {}
    res['ensure'] = value if value
    res.merge!(params.sort.to_h)

    return { h['title'] => res }
  end

  # Convert our resource to Puppet code.
  def to_manifest
    # Collect list of attributes to align => and move ensure first
    attr = parameters.keys
    attr_max = attr.inject(0) { |max, k| k.to_s.length > max ? k.to_s.length : max }

    attr.sort!
    if attr.first != :ensure && attr.include?(:ensure)
      attr.delete(:ensure)
      attr.unshift(:ensure)
    end

    # rubocop:disable Lint/FormatParameterMismatch
    attributes = attr.collect { |k|
      v = parameters[k]
      "  %-#{attr_max}s => %s,\n" % [k, Puppet::Parameter.format_value_for_display(v)]
    }.join
    # rubocop:enable Lint/FormatParameterMismatch

    escaped = self.title.gsub(/'/, "\\\\'")
    "%s { '%s':\n%s}" % [self.type.to_s.downcase, escaped, attributes]
  end

  def to_ref
    ref
  end

  # Convert our resource to a RAL resource instance. Creates component
  # instances for resource types that are not of a compilable_type kind. In case
  # the resource doesn’t exist and it’s compilable_type kind, raise an error.
  # There are certain cases where a resource won't be in a catalog, such as
  # when we create a resource directly by using Puppet::Resource.new(...), so we
  # must check its kind before deciding whether the catalog format is of an older
  # version or not.
  def to_ral
    if self.kind == COMPILABLE_TYPE_STRING
      typeklass = Puppet::Type.type(self.type)
    elsif self.catalog && self.catalog.catalog_format >= 2
      typeklass = Puppet::Type.type(:component)
    else
      typeklass = Puppet::Type.type(self.type) || Puppet::Type.type(:component)
    end

    raise(Puppet::Error, "Resource type '#{self.type}' was not found") unless typeklass

    typeklass.new(self)
  end

  def name
    # this is potential namespace conflict
    # between the notion of an "indirector name"
    # and a "resource name"
    [type, title].join('/')
  end

  def missing_arguments
    resource_type.arguments.select do |param, _default|
      the_param = parameters[param.to_sym]
      the_param.nil? || the_param.value.nil? || the_param.value == :undef
    end
  end
  private :missing_arguments

  def copy_as_resource
    Puppet::Resource.new(self)
  end

  def valid_parameter?(name)
    resource_type.valid_parameter?(name)
  end

  def validate_parameter(name)
    raise Puppet::ParseError.new(_("no parameter named '%{name}'") % { name: name }, file, line) unless valid_parameter?(name)
  end

  # This method, together with #file and #line, makes it possible for a Resource to be a 'source_pos' in a reported issue.
  # @return [Integer] Instances of this class will always return `nil`.
  def pos
    nil
  end

  def prune_parameters(options = EMPTY_HASH)
    properties = resource_type.properties.map(&:name)

    dup.collect do |attribute, value|
      if value.to_s.empty? or Array(value).empty?
        delete(attribute)
      elsif value.to_s == "absent" and attribute.to_s != "ensure"
        delete(attribute)
      end

      parameters_to_include = resource_type.parameters_to_include
      parameters_to_include += options[:parameters_to_include] || []

      delete(attribute) unless properties.include?(attribute) || parameters_to_include.include?(attribute)
    end
    self
  end

  # @api private
  def self.type_and_title(type, title)
    type, title = extract_type_and_title(type, title)
    type = munge_type_name(type)
    if type == TYPE_CLASS
      title = title == '' ? :main : munge_type_name(title)
    end
    [type, title]
  end

  def self.extract_type_and_title(argtype, argtitle)
    if (argtype.nil? || argtype == :component || argtype == :whit) &&
       argtitle =~ /^([^\[\]]+)\[(.+)\]$/m                  then [$1, $2]
    elsif argtitle.nil? && argtype.is_a?(String) &&
          argtype =~ /^([^\[\]]+)\[(.+)\]$/m                   then [$1,                 $2]
    elsif argtitle                                             then [argtype,            argtitle]
    elsif argtype.is_a?(Puppet::Type)                          then [argtype.class.name, argtype.title]
    else  raise ArgumentError, _("No title provided and %{type} is not a valid resource reference") % { type: argtype.inspect } # rubocop:disable Lint/ElseLayout
    end
  end
  private_class_method :extract_type_and_title

  def self.munge_type_name(value)
    return :main if value == :main
    return TYPE_CLASS if value == '' || value.nil? || value.to_s.casecmp('component') == 0

    Puppet::Pops::Types::TypeFormatter.singleton.capitalize_segments(value.to_s)
  end
  private_class_method :munge_type_name

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
    if builtin_type? && !(t = resource_type).nil? && t.key_attributes.length == 1
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

  # Produces a hash with { :key => part_of_title } for each entry in title_patterns
  # for the resource type. A typical result for a title of 'example' is {:name => 'example'}.
  # A resource type with a complex title to attribute mapping returns one entry in the hash
  # per part.
  #
  def parse_title
    h = {}
    type = resource_type
    if type.respond_to?(:title_patterns) && !type.title_patterns.nil?
      type.title_patterns.each do |regexp, symbols_and_lambdas|
        captures = regexp.match(title.to_s)
        next unless captures

        symbols_and_lambdas.zip(captures[1..]).each do |symbol_and_lambda, capture|
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
      # If we've gotten this far, then none of the provided title patterns
      # matched. Since there's no way to determine the title then the
      # resource should fail here.
      raise Puppet::Error, _("No set of title patterns matched the title \"%{title}\".") % { title: title }
    else
      return { :name => title.to_s }
    end
  end
end
