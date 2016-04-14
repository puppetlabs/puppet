# @deprecated Moved to Puppet::Pops::Lookup::Interpolation
module Puppet::DataProviders::HieraInterpolate
  include Puppet::Pops::Lookup::Interpolation

  # For backward compatibility
  # @deprecated
  def qualified_lookup(segments, value)
    Puppet::deprecation_warning(
      'Puppet::DataProviders::HieraInterpolate#qualified_lookup is deprecated, use Puppet::Pops::Lookup::SubLookup#sub_lookup')
    sub_lookup('<unknown key>', Puppet::Pops::Lookup::Invocation.new(nil), segments, value)
  end
end
