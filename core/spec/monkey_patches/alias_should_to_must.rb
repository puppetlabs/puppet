require 'rspec'

# This is necessary because the RAL has a 'should' method.
class Object
  alias :must :should
  alias :must_not :should_not
end

# ...and this is because we want to make sure we don't ignore that change
# above.  Gotta love overwriting functions, but the performance cost at
# runtime is pretty terrible if we don't.
require 'puppet/type'
class Puppet::Type
  alias :should_native :should
  def should(value)
    unless value.is_a? String or value.is_a? Symbol
      raise "you need to call .must rather than .should on Puppet::Type instances"
    end
    should_native(value)
  end
end
