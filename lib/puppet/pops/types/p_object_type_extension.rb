module Puppet::Pops
module Types

# Base class for Parameterized Object implementations. The wrapper impersonates the base
# object and extends it with methods to filter assignable types and instances based on parameter
# values.
#
# @api public
class PObjectTypeExtension < PAnyType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType',
      'base_type' => {
        KEY_TYPE => PTypeType::DEFAULT
      },
      'init_parameters' => {
        KEY_TYPE => PArrayType::DEFAULT
      }
    )
  end

  attr_reader :base_type, :parameters

  # @api private
  def self.create(base_type, init_parameters)
    impl_class = Loaders.implementation_registry.module_for_type("#{base_type.name}TypeExtension") || self
    impl_class.new(base_type, init_parameters)
  end

  # @api private
  def initialize(base_type, init_parameters)
    pts = base_type.type_parameters(true)
    raise Puppet::ParseError, _('The data type %{typename} cannot be parameterized using []') % { type_name: base_type.name } if pts.empty?
    @base_type = base_type

    named_args = false
    if init_parameters.is_a?(PuppetObject)
      init_parameters = parameters_from_instance(init_parameters, pts)
    else
      named_args = init_parameters.size == 1 && init_parameters[0].is_a?(Hash)
      if named_args
        # Catch case when first parameter is a Hash and remaining parameters are optional
        if pts.size >= 1 && pts.values[1..-1].all? { |type_param| type_param.value? }
          type_param = pts.values[0]
          v = init_parameters[0]
          v = type_param.value if v == :default && type_param.value?
          named_args = !type_param.type.instance?(v)
        end
      end
    end

    by_name = {}
    if named_args
      hash = init_parameters[0]
      hash.each_key do |pn|
        unless pts.include?(pn)
          raise Puppet::ParseError, _("'%{pn}' is not a known type parameter for %{type_name}") % { pn: pn, type_name: base_type.name }
        end
      end
      pts.each_pair { |pn, tp| by_name[pn] = check_param(tp, hash.include?(pn) ? hash[pn] : :default) }
    else
      pts.values.each_with_index { |tp, idx| by_name[tp.name] = check_param(tp, idx < init_parameters.size ? init_parameters[idx] : :default) }
    end
    @parameters = by_name
  end

  def check_param(type_param, v)
    if v == :default
      raise Puppet::ParseError, _('No value provided for required %{label}') % { label: type_param.label } unless type_param.value?
      v = type_param.value
    end
    TypeAsserter.assert_instance_of(nil, type_param.type, v) { type_param.label }
  end

  # Return the parameter values as positional arguments with values that represent `default` as :default. The
  # array is stripped from trailing :default values
  # @return [Array] the parameter values
  # @api private
  def init_parameters
    result = @base_type.type_parameters(true).values.map do |tp|
      v = @parameters[tp.name]
      tp.value? && tp.value == v ? :default : v
    end
    # Remove trailing defaults but avoid empty result. At least one parameter must
    # be present, even it is :default
    result.pop while result.size > 1 && result.last == :default
    result
  end

  # @api private
  def eql?(o)
    super(o) && @base_type.eql?(o.base_type) && @parameters.eql?(o.parameters)
  end

  # @api private
  def generalize
    @base_type
  end

  # @api private
  def hash
    @base_type.hash ^ @parameters.hash
  end

  # @api private
  def loader
    @base_type.loader
  end

  # @api private
  def check_self_recursion(originator)
    @base_type.check_self_recursion(originator)
  end

  # @api private
  def create(*args)
    @base_type.create(*args)
  end

  # @api private
  def instance?(o, guard = nil)
    @base_type.instance?(o, guard) && test_instance?(o, guard)
  end

  # @api private
  def new_function
    @base_type.new_function
  end

  # @api private
  def simple_name
    @base_type.simple_name
  end

  protected

  # Creates an array of type parameters from the attributes that matches the
  # type parameters by name. Type parameters for which there is no matching attribute
  # will have `nil` in their corresponding position on the array.
  #
  # @return [Array] array of values from instance that maps to type parameters
  def parameters_from_instance(instance, type_parameters)
    attrs = @base_type.attributes(true)
    type_parameters.keys.map do |pn|
      attr = attrs[pn]
      attr.nil? ? nil : instance.send(pn)
    end
  end

  # Checks that the given `param_values` hash contains all keys present in the `parameters` of
  # this instance and that each keyed value is a match for the given parameter. The match is done
  # using case expression semantics.
  #
  # This method is only called when a given type is found to be assignable to the base type of
  # this extension.
  #
  # @param param_values[Hash] the parameter values of the assignable type
  # @param guard[RecursionGuard] guard against endless recursion
  # @return [Boolean] true or false to indicate assignability
  # @api public
  def test_assignable?(param_values, guard)
    # Default implementation performs case expression style matching of all parameter values
    # provided that the value exist (this should always be the case, since all defaults have
    # been assigned at this point)
    eval = Parser::EvaluatingParser.singleton.evaluator
    @parameters.keys.all? do |pn|
      if param_values.include?(pn)
        eval.match?(param_values[pn], @parameters[pn])
      else
        false
      end
    end
  end

  # Checks that the given instance `o` has one attribute for each key present in the `parameters` of
  # this instance and that each attribute value is a match for the given parameter. The match is done
  # using case expression semantics.
  #
  # This method is only called when the given value is found to be an instance of the base type of
  # this extension.
  #
  # @param o [Object] the instance to test
  # @param guard[RecursionGuard] guard against endless recursion
  # @return [Boolean] true or false to indicate if the value is an instance or not
  # @api public
  def test_instance?(o, guard)
    eval = Parser::EvaluatingParser.singleton.evaluator
    @parameters.keys.all? do |pn|
      ov = nil
      begin
        m = o.public_method(pn)
        m.arity == 0 ? eval.match?(m.call, @parameters[pn]) : false
      rescue NameError
        false
      end
    end
  end

  # @api private
  def _assignable?(o, guard = nil)
    if o.is_a?(PObjectTypeExtension)
      @base_type.assignable?(o.base_type, guard) && test_assignable?(o.parameters, guard)
    else
      @base_type.assignable?(o, guard) && test_assignable?(EMPTY_HASH, guard)
    end
  end
end
end
end
