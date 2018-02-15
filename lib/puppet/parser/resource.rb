require 'puppet/resource'

# The primary difference between this class and its
# parent is that this class has rules on who can set
# parameters
class Puppet::Parser::Resource < Puppet::Resource
  require 'puppet/parser/resource/param'
  require 'puppet/util/tagging'

  include Puppet::Util
  include Puppet::Util::MethodHelper
  include Puppet::Util::Errors
  include Puppet::Util::Logging

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
      raise ArgumentError, _("Could not find stage %{stage} specified by %{resource}") % { stage: self[:stage] || :main, resource: self }
    end

    self[:stage] ||= stage.title unless stage.title == :main
    catalog.add_edge(stage, self)
  end

  # Retrieve the associated definition and evaluate it.
  def evaluate
    return if evaluated?
    Puppet::Util::Profiler.profile(_("Evaluated resource %{res}") % { res: self }, [:compiler, :evaluate_resource, self]) do
      @evaluated = true
      if builtin_type?
        devfail "Cannot evaluate a builtin type (#{type})"
      elsif resource_type.nil?
        self.fail "Cannot find definition #{type}"
      else
        finish_evaluation() # do not finish completely (as that destroys Sensitive data)
        resource_type.evaluate_code(self)
      end
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

  # Finish the evaluation by assigning defaults and scope tags
  # @api private
  #
  def finish_evaluation
    return if @evaluation_finished
    add_scope_tags
    @evaluation_finished = true
  end

  # Do any finishing work on this object, called before
  # storage/translation. The method does nothing the second time
  # it is called on the same resource.
  #
  # @param do_validate [Boolean] true if validation should be performed
  #
  # @api private
  def finish(do_validate = true)
    return if finished?
    @finished = true
    finish_evaluation
    replace_sensitive_data
    validate if do_validate
  end

  # Has this resource already been finished?
  def finished?
    @finished
  end

  def initialize(type, title, attributes, with_defaults = true)
    raise ArgumentError, _('Resources require a hash as last argument') unless attributes.is_a? Hash
    raise ArgumentError, _('Resources require a scope') unless attributes[:scope]
    super(type, title, attributes)

    @source ||= scope.source

    if with_defaults
      scope.lookupdefaults(self.type).each_pair do |name, param|
        unless @parameters.include?(name)
          self.debug "Adding default for #{name}"

          param = param.dup
          @parameters[name] = param
          tag(*param.value) if param.name == :tag
        end
      end
    end
  end

  # Is this resource modeling an isomorphic resource type?
  def isomorphic?
    if builtin_type?
      return resource_type.isomorphic?
    else
      return true
    end
  end

  def is_unevaluated_consumer?
    # We don't declare a new variable here just to test. Saves memory
    instance_variable_defined?(:@unevaluated_consumer)
  end

  def mark_unevaluated_consumer
    @unevaluated_consumer = true
  end

  # Merge an override resource in.  This will throw exceptions if
  # any overrides aren't allowed.
  def merge(resource)
    # Test the resource scope, to make sure the resource is even allowed
    # to override.
    unless self.source.object_id == resource.source.object_id || resource.source.child_of?(self.source)
      raise Puppet::ParseError.new(_("Only subclasses can override parameters"), resource.file, resource.line)
    end

    if evaluated?
      error_location_str = Puppet::Util::Errors.error_location(file, line)
      msg = if error_location_str.empty?
              _('Attempt to override an already evaluated resource with new values')
            else
              _('Attempt to override an already evaluated resource, defined at %{error_location}, with new values') % { error_location: error_location_str }
            end
      strict = Puppet[:strict]
      unless strict == :off
        if strict == :error
          raise Puppet::ParseError.new(msg, resource.file, resource.line)
        else
          msg += Puppet::Util::Errors.error_location_with_space(resource.file, resource.line)
          Puppet.warning(msg)
        end
      end
    end

    # Some of these might fail, but they'll fail in the way we want.
    resource.parameters.each do |name, param|
      override_parameter(param)
    end
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
    if ! param.is_a?(Puppet::Parser::Resource::Param)
      param = param.name if param.is_a?(Puppet::Pops::Resource::Param)
      param = Puppet::Parser::Resource::Param.new(
        :name => param, :value => value, :source => self.source
      )
    end

    tag(*param.value) if param.name == :tag

    # And store it in our parameter hash.
    @parameters[param.name] = param
  end
  alias []= set_parameter

  def to_hash
    parse_title.merge(@parameters.reduce({}) do |result, (_, param)|
      value = param.value
      value = (:undef == value) ? nil : value

      unless value.nil?
        case param.name
        when :before, :subscribe, :notify, :require
          if value.is_a?(Array)
            value = value.flatten.reject {|v| v.nil? || :undef == v }
          end
          result[param.name] = value
        else
          result[param.name] = value
        end
      end
      result
    end)
  end

  # Convert this resource to a RAL resource.
  def to_ral
    copy_as_resource.to_ral
  end

  # Answers if this resource is tagged with at least one of the tags given in downcased string form.
  #
  # The method is a faster variant of the tagged? method that does no conversion of its
  # arguments.
  #
  # The match takes into account the tags that a resource will inherit from its container
  # but have not been set yet.
  # It does *not* take tags set via resource defaults as these will *never* be set on
  # the resource itself since all resources always have tags that are automatically
  # assigned.
  #
  # @param tag_array [Array[String]] list tags to look for
  # @return [Boolean] true if this instance is tagged with at least one of the provided tags
  #
  def raw_tagged?(tag_array)
    super || ((scope_resource = scope.resource) && !scope_resource.equal?(self) && scope_resource.raw_tagged?(tag_array))
  end

  # Fills resource params from a capability
  #
  # This backs 'consumes => Sql[one]'
  # @api private
  def add_parameters_from_consume
    return if self[:consume].nil?

    map = {}
    [ self[:consume] ].flatten.map do |ref|
      # Assert that the ref really is a resource reference
      raise Puppet::Error, _("Invalid consume in %{value0}: %{ref} is not a resource") % { value0: self.ref, ref: ref } unless ref.is_a?(Puppet::Resource)

      # Resolve references
      t = ref.type
      t = Puppet::Pops::Evaluator::Runtime3ResourceSupport.find_resource_type(scope, t) unless t == 'class' || t == 'node'
      cap = catalog.resource(t, ref.title)
      if cap.nil?
        raise Puppet::Error, _("Resource %{ref} could not be found; it might not have been produced yet") % { ref: ref }
      end

      # Ensure that the found resource is a capability resource
      raise Puppet::Error, _("Invalid consume in %{ref}: %{cap} is not a capability resource") % { ref: ref, cap: cap } unless cap.resource_type.is_capability?
      cap
    end.each do |cns|
      # Establish mappings
      blueprint = resource_type.consumes.find do |bp|
        bp[:capability] == cns.type
      end
      # @todo lutter 2015-08-03: catch this earlier, can we do this during
      # static analysis ?
      raise _("Resource %{res} tries to consume %{cns} but no 'consumes' mapping exists for %{resource_type} and %{cns_type}") % { res: self, cns: cns, resource_type: self.resource_type, cns_type: cns.type } unless blueprint

      # setup scope that has, for each attr of cns, a binding to cns[attr]
      scope.with_global_scope do |global_scope|
        cns_scope = global_scope.newscope(:source => self, :resource => self)
        cns.to_hash.each { |name, value| cns_scope[name.to_s] = value }

        # evaluate mappings in that scope
        resource_type.arguments.keys.each do |name|
          if expr = blueprint[:mappings][name]
            # Explicit mapping
            value = expr.safeevaluate(cns_scope)
          else
            value = cns[name]
          end
          unless value.nil?
            # @todo lutter 2015-07-01: this should be caught by the checker
            # much earlier. We consume several capres, at least two of which
            # want to map to the same parameter (PUP-5080)
            raise _("Attempt to reassign attribute '%{name}' in '%{resource}' caused by multiple consumed mappings to the same attribute") % { name: name, resource: self } if map[name]
            map[name] = value
          end
        end
      end
    end

    map.each { |name, value| self[name] = value if self[name].nil? }
  end

  def offset
    nil
  end

  def pos
    nil
  end

  private

  def add_scope_tags
    scope_resource = scope.resource
    unless scope_resource.nil? || scope_resource.equal?(self)
      merge_tags_from(scope_resource)
    end
  end

  def replace_sensitive_data
    parameters.each_pair do |name, param|
      if param.value.is_a?(Puppet::Pops::Types::PSensitiveType::Sensitive)
        @sensitive_parameters << name
        param.value = param.value.unwrap
      end
    end
  end

  # Accept a parameter from an override.
  def override_parameter(param)
    # This can happen if the override is defining a new parameter, rather
    # than replacing an existing one.
    (set_parameter(param) and return) unless current = @parameters[param.name]

    # Parameter is already set - if overriding with a default - simply ignore the setting of the default value
    return if scope.is_default?(type, param.name, param.value)

    # The parameter is already set.  Fail if they're not allowed to override it.
    unless param.source.child_of?(current.source) || param.source.equal?(current.source) && scope.is_default?(type, param.name, current.value)
      error_location_str = Puppet::Util::Errors.error_location(current.file, current.line)
      msg = if current.source.to_s == ''
              if error_location_str.empty?
                _("Parameter '%{name}' is already set on %{resource}; cannot redefine") %
                    { name: param.name, resource: ref }
              else
                _("Parameter '%{name}' is already set on %{resource} at %{error_location}; cannot redefine") %
                    { name: param.name, resource: ref, error_location: error_location_str }
              end
            else
              if error_location_str.empty?
                _("Parameter '%{name}' is already set on %{resource} by %{source}; cannot redefine") %
                    { name: param.name, resource: ref, source: current.source.to_s }
              else
                _("Parameter '%{name}' is already set on %{resource} by %{source} at %{error_location}; cannot redefine") %
                    { name: param.name, resource: ref, source: current.source.to_s, error_location: error_location_str }
              end
            end
      raise Puppet::ParseError.new(msg, param.file, param.line)
    end

    # If we've gotten this far, we're allowed to override.

    # Merge with previous value, if the parameter was generated with the +>
    # syntax.  It's important that we use a copy of the new param instance
    # here, not the old one, and not the original new one, so that the source
    # is registered correctly for later overrides but the values aren't
    # implicitly shared when multiple resources are overridden at once (see
    # ticket #3556).
    if param.add
      param = param.dup
      param.value = [current.value, param.value].flatten
    end

    set_parameter(param)
  end

  # Make sure the resource's parameters are all valid for the type.
  def validate
    if builtin_type?
      begin
        @parameters.each { |name, value| validate_parameter(name) }
      rescue => detail
        self.fail Puppet::ParseError, detail.to_s + " on #{self}", detail
      end
    else
      resource_type.validate_resource(self)
    end
  end

  def extract_parameters(params)
    params.each do |param|
      # Don't set the same parameter twice
      self.fail Puppet::ParseError, _("Duplicate parameter '%{param}' for on %{resource}") % { param: param.name, resource: self } if @parameters[param.name]

      set_parameter(param)
    end
  end
end
