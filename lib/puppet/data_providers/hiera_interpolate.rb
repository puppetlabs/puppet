# TODO: API 5.0, remove this module
# @deprecated Moved to Puppet::Pops::Lookup::Interpolation
module Puppet::DataProviders::HieraInterpolate
  include Puppet::Pops::Lookup::Interpolation

  # For backward compatibility
  # @api private
  # @deprecated
  def qualified_lookup(segments, value)
    if Puppet[:strict] != :off
      msg = 'Puppet::DataProviders::HieraInterpolate#qualified_lookup is deprecated, use Puppet::Pops::Lookup::SubLookup#sub_lookup'
      case Puppet[:strict]
      when :error
        raise Puppet::DataBinding::LookupError.new(msg)
      when :warning
        Puppet.warn_once(:deprecation, 'HieraInterpolate#qualified_lookup', msg)
      end
    end
    sub_lookup('<unknown key>', Puppet::Pops::Lookup::Invocation.current, segments, value)
  end
end
