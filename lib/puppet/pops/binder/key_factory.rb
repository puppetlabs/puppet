# The KeyFactory is responsible for creating keys used for lookup of bindings.
#
class Puppet::Pops::Binder::KeyFactory

  attr_reader :type_calculator
  def initialize(type_calculator = Puppet::Pops::Types::TypeCalculator.new())
    @type_calculator = type_calculator
  end

  def binding_key(binding)
    named_key(binding.type, binding.name)
  end

  def named_key(type, name)
    [(@type_calculator.assignable?(@type_calculator.data, type) ? @type_calculator.data : type), name]
  end

  def data_key(name)
    [@type_calculator.data, name]
  end

  def is_contributions_key?(s)
    return false unless s.is_a?(String)
    s.start_with?('mc_')
  end

  def multibind_contributions(multibind_id)
    "mc_#{multibind_id}"
  end

  def is_named?(key)
    key.is_a?(Array) && key[1] && !key[1].empty?
  end

  def is_data?(key)
    return false unless key.is_a?(Array) && key[0].is_a?(Puppet::Pops::Types::PObjectType)
    type_calculator.assignable?(type_calculator.data(), key[0])
  end

  def is_ruby?(key)
    return key.is_a?(Array) && key[0].is_a?(Puppet::Pops::Types::PRubyType)
  end

  # Returns the type of the key
  def get_type(key)
    return nil unless key.is_a?(Array)
    key[0]
  end
end