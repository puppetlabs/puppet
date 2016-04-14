# @deprecated Moved to Puppet::Pops::Lookup::Interpolation
module Puppet::DataProviders::HieraInterpolate
  include Puppet::Pops::Lookup::Interpolation

  def qualified_lookup(segments, value)
    Puppet::deprecation_warning(
      'Puppet::DataProviders::HieraInterpolate#qualified_lookup is deprecated, use Puppet::Pops::Lookup::SubLookup#sub_lookup')
    sub_lookup('<unknown key>', segments, value)
  end
end
