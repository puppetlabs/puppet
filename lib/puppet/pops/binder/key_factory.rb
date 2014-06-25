# The KeyFactory is responsible for creating keys used for lookup of bindings.
# @api public
#
class Puppet::Pops::Binder::KeyFactory

  attr_reader :type_calculator
  # @api public
  def initialize(type_calculator = Puppet::Pops::Types::TypeCalculator.new())
    @type_calculator = type_calculator
  end

  # @api public
  def binding_key(binding)
    named_key(binding.type, binding.name)
  end

  # @api public
  def named_key(type, name)
    [(@type_calculator.assignable?(@type_calculator.data, type) ? @type_calculator.data : type), name]
  end

  # @api public
  def data_key(name)
    [@type_calculator.data, name]
  end

  # @api public
  def is_contributions_key?(s)
    return false unless s.is_a?(String)
    s.start_with?('mc_')
  end

  # @api public
  def multibind_contributions(multibind_id)
    "mc_#{multibind_id}"
  end

  # @api public
  def multibind_contribution_key_to_id(contributions_key)
    # removes the leading "mc_" from the key to get the multibind_id
    contributions_key[3..-1]
  end

  # @api public
  def is_named?(key)
    key.is_a?(Array) && key[1] && !key[1].empty?
  end

  # @api public
  def is_data?(key)
    return false unless key.is_a?(Array) && key[0].is_a?(Puppet::Pops::Types::PAnyType)
    type_calculator.assignable?(type_calculator.data(), key[0])
  end

  # @api public
  def is_ruby?(key)
    key.is_a?(Array) && key[0].is_a?(Puppet::Pops::Types::PRuntimeType) && key[0].runtime == :ruby
  end

  # Returns the type of the key
  # @api public
  #
  def get_type(key)
    return nil unless key.is_a?(Array)
    key[0]
  end
end
