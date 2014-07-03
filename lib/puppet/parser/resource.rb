require 'puppet/resource'

# The primary difference between this class and its
# parent is that this class has rules on who can set
# parameters
class Puppet::Parser::Resource < Puppet::Resource
  require 'puppet/parser/resource/param'
  require 'puppet/util/tagging'
  require 'puppet/parser/yaml_trimmer'
  require 'puppet/resource/type_collection_helper'

  include Puppet::Resource::TypeCollectionHelper

  include Puppet::Util
  include Puppet::Util::MethodHelper
  include Puppet::Util::Errors
  include Puppet::Util::Logging
  include Puppet::Parser::YamlTrimmer

  attr_accessor :source, :scope, :collector_id
  attr_accessor :virtual, :override, :translated, :catalog, :evaluated
  attr_accessor :file, :line

  attr_reader :exported, :parameters

  # Determine whether the provided parameter name is a relationship parameter.
  def self.relationship_parameter?(name)
    @relationship_names ||= Puppet::Type.relationship_params.collect { |p| p.name }
    @relationship_names.include?(name)
  end

  # Set up some boolean test methods
  def translated?; !!@translated; end
  def override?;   !!@override;   end
  def evaluated?;  !!@evaluated;  end

  def [](param)
    param = param.intern
    if param == :title
      return self.title
    end
    if @parameters.has_key?(param)
      @parameters[param].value
    else
      nil
    end
  end

  def eachparam
    @parameters.each do |name, param|
      yield param
    end
  end

  def environment
    scope.environment
  end

  # Process the  stage metaparameter for a class.   A containment edge
  # is drawn from  the class to the stage.   The stage for containment
  # defaults to main, if none is specified.
  def add_edge_to_stage
    return unless self.class?

    unless stage = catalog.resource(:stage, self[:stage] || (scope && scope.resource && scope.resource[:stage]) || :main)
      raise ArgumentError, "Could not find stage #{self[:stage] || :main} specified by #{self}"
    end

    self[:stage] ||= stage.title unless stage.title == :main
    catalog.add_edge(stage, self)
  end

  # Retrieve the associated definition and evaluate it.
  def evaluate
    return if evaluated?
    @evaluated = true
    if klass = resource_type and ! builtin_type?
      finish
      evaluated_code = klass.evaluate_code(self)

      return evaluated_code
    elsif builtin?
      devfail "Cannot evaluate a builtin type (#{type})"
    else
      self.fail "Cannot find definition #{type}"
    end
  end

  # Mark this resource as both exported and virtual,
  # or remove the exported mark.
  def exported=(value)
    if value
      @virtual = true
      @exported = value
    else
      @exported = value
    end
  end

  # Do any finishing work on this object, called before evaluation or
  # before storage/translation.
  def finish
    return if finished?
    @finished = true
    add_defaults
    add_scope_tags
    validate
  end

  # Has this resource already been finished?
  def finished?
    @finished
  end

  def initialize(*args)
    raise ArgumentError, "Resources require a hash as last argument" unless args.last.is_a? Hash
    raise ArgumentError, "Resources require a scope" unless args.last[:scope]
    super

    @source ||= scope.source
  end

  # Is this resource modeling an isomorphic resource type?
  def isomorphic?
    if builtin_type?
      return resource_type.isomorphic?
    else
      return true
    end
  end

  # Merge an override resource in.  This will throw exceptions if
  # any overrides aren't allowed.
  def merge(resource)
    # Test the resource scope, to make sure the resource is even allowed
    # to override.
    unless self.source.object_id == resource.source.object_id || resource.source.child_of?(self.source)
      raise Puppet::ParseError.new("Only subclasses can override parameters", resource.line, resource.file)
    end
    # Some of these might fail, but they'll fail in the way we want.
    resource.parameters.each do |name, param|
      override_parameter(param)
    end
  end

  # This only mattered for clients < 0.25, which we don't support any longer.
  # ...but, since this hasn't been deprecated, and at least some functions
  # used it, deprecate now rather than just eliminate. --daniel 2012-07-15
  def metaparam_compatibility_mode?
    Puppet.deprecation_warning "metaparam_compatibility_mode? is obsolete since < 0.25 clients are really, really not supported any more"
    false
  end

  def name
    self[:name] || self.title
  end

  # A temporary occasion, until I get paths in the scopes figured out.
  alias path to_s

  # Define a parameter in our resource.
  # if we ever receive a parameter named 'tag', set
  # the resource tags with its value.
  def set_parameter(param, value = nil)
    if ! value.nil?
      param = Puppet::Parser::Resource::Param.new(
        :name => param, :value => value, :source => self.source
      )
    elsif ! param.is_a?(Puppet::Parser::Resource::Param)
      raise ArgumentError, "Received incomplete information - no value provided for parameter #{param}"
    end

    tag(*param.value) if param.name == :tag

    # And store it in our parameter hash.
    @parameters[param.name] = param
  end
  alias []= set_parameter

  def to_hash
    @parameters.inject({}) do |hash, ary|
      param = ary[1]
      # Skip "undef" and nil values.
      hash[param.name] = param.value if param.value != :undef && !param.value.nil?
      hash
    end
  end

  # Convert this resource to a RAL resource.
  def to_ral
    copy_as_resource.to_ral
  end

  # Is the receiver tagged with the given tags?
  # This match takes into account the tags that a resource will inherit from its container
  # but have not been set yet.
  # It does *not* take tags set via resource defaults as these will *never* be set on
  # the resource itself since all resources always have tags that are automatically
  # assigned.
  #
  def tagged?(*tags)
    super || ((scope_resource = scope.resource) && scope_resource != self && scope_resource.tagged?(tags))
  end

  private

  # Add default values from our definition.
  def add_defaults
    scope.lookupdefaults(self.type).each do |name, param|
      unless @parameters.include?(name)
        self.debug "Adding default for #{name}"

        @parameters[name] = param.dup
      end
    end
  end

  def add_scope_tags
    if scope_resource = scope.resource
      tag(*scope_resource.tags)
    end
  end

  # Accept a parameter from an override.
  def override_parameter(param)
    # This can happen if the override is defining a new parameter, rather
    # than replacing an existing one.
    (set_parameter(param) and return) unless current = @parameters[param.name]

    # The parameter is already set.  Fail if they're not allowed to override it.
    unless param.source.child_of?(current.source)
      msg = "Parameter '#{param.name}' is already set on #{self}"
      msg += " by #{current.source}" if current.source.to_s != ""
      if current.file or current.line
        fields = []
        fields << current.file if current.file
        fields << current.line.to_s if current.line
        msg += " at #{fields.join(":")}"
      end
      msg += "; cannot redefine"
      raise Puppet::ParseError.new(msg, param.line, param.file)
    end

    # If we've gotten this far, we're allowed to override.

    # Merge with previous value, if the parameter was generated with the +>
    # syntax.  It's important that we use a copy of the new param instance
    # here, not the old one, and not the original new one, so that the source
    # is registered correctly for later overrides but the values aren't
    # implcitly shared when multiple resources are overrriden at once (see
    # ticket #3556).
    if param.add
      param = param.dup
      param.value = [current.value, param.value].flatten
    end

    set_parameter(param)
  end

  # Make sure the resource's parameters are all valid for the type.
  def validate
    @parameters.each do |name, param|
      validate_parameter(name)
    end
  rescue => detail
    self.fail Puppet::ParseError, detail.to_s + " on #{self}", detail
  end

  def extract_parameters(params)
    params.each do |param|
      # Don't set the same parameter twice
      self.fail Puppet::ParseError, "Duplicate parameter '#{param.name}' for on #{self}" if @parameters[param.name]

      set_parameter(param)
    end
  end
end
