module Puppet::Pops
module Binder
# The KeyFactory is responsible for creating keys used for lookup of bindings.
# @api public
#
class KeyFactory

  # @api public
  def binding_key(binding)
    named_key(binding.type, binding.name)
  end

  # @api public
  def named_key(type, name)
    [(Types::PDataType::DEFAULT.assignable?(type) ? Types::PDataType::DEFAULT : type), name]
  end

  # @api public
  def data_key(name)
    [Types::PDataType::DEFAULT, name]
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
    return false unless key.is_a?(Array) && key[0].is_a?(Types::PAnyType)
    Types::PDataType::DEFAULT.assignable?(key[0])
  end

  # @api public
  def is_ruby?(key)
    key.is_a?(Array) && key[0].is_a?(Types::PRuntimeType) && key[0].runtime == :ruby
  end

  # Returns the type of the key
  # @api public
  #
  def get_type(key)
    return nil unless key.is_a?(Array)
    key[0]
  end
end
end
end
