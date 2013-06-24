require 'puppet/pops/types'

# The KeyFactory is responsible for creating keys used for lookup of bindings.
#
class Puppet::Pops::Binder::KeyFactory

  def initialize(type_calculator = Puppet::Pops::Binder::TypeCalculator.new())
    @tc = type_calculator
  end

  def binding_key(binding)
    named_key(binding.type, binding_name)
  end

  def named_key(type, name)
    [(@tc.assignable?(@tc.data, type) ? @tc.data : type), binding.name]
  end

  def data_key(name)
    [@tc.data, binding.name]
  end
end