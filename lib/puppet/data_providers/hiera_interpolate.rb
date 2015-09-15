require_relative 'hiera_config'

# Add support for Hiera-like interpolation expressions. The expressions may contain keys that uses dot-notation
# to further navigate into hashes and arrays
#
module Puppet::DataProviders::HieraInterpolate
  def interpolate(subject, lookup_invocation, allow_methods)
    return subject unless subject.is_a?(String)

    subject.gsub(/%\{([^\}]+)\}/) do |match|
      method_key, key = get_method_and_data($1, allow_methods)
      is_alias = method_key == 'alias'

      # Alias is only permitted if the entire string is equal to the interpolate expression
      raise Puppet::DataBinding::LookupError, "'alias' interpolation is only permitted if the expression is equal to the entire string" if is_alias && subject != match

      segments = key.split('.')
      value = interpolate_method(method_key).call(segments[0], lookup_invocation)
      value = qualified_lookup(segments.drop(1), value) if segments.size > 1
      value = lookup_invocation.check(key) { interpolate(value, lookup_invocation, allow_methods) } if value.is_a?(String)

      # break gsub and return value immediately if this was an alias substitution. The value might be something other than a String
      return value if is_alias

      value || ''
    end
  end

  private

  def interpolate_method(method_key)
    @@interpolate_methods ||= begin
      global_lookup = lambda { |key, lookup_invocation| Puppet::Pops::Lookup.lookup(key, nil, '', true, nil, lookup_invocation) }
      scope_lookup = lambda do |key, lookup_invocation|
        ovr = lookup_invocation.override_values
        if ovr.include?(key)
          ovr[key]
        else
          scope = lookup_invocation.scope
          if scope.include?(key)
            scope[key]
          else
            lookup_invocation.default_values[key]
          end
        end
      end

      {
        'lookup' => global_lookup,
        'hiera' => global_lookup, # this is just an alias for 'lookup'
        'alias' => global_lookup, # same as 'lookup' but expression must be entire string. The result that is not subject to string substitution
        'scope' => scope_lookup,
        'literal' => lambda { |key, _| key }
      }
    end
    interpolate_method = @@interpolate_methods[method_key]
    raise Puppet::DataBinding::LookupError, "Unknown interpolation method '#{method_key}'" unless interpolate_method
    interpolate_method
  end

  def qualified_lookup(segments, value)
    segments.each do |segment|
      throw :no_such_key if value.nil?
      if segment =~ /^[0-9]+$/
        segment = segment.to_i
        raise Puppet::DataBinding::LookupError, "Data provider type mismatch: Got #{value.class.name} when Array was expected to enable lookup using key '#{segment}'" unless value.instance_of?(Array)
        throw :no_such_key unless segment < value.size
      else
        raise Puppet::DataBinding::LookupError, "Data provider type mismatch: Got #{value.class.name} when a non Array object that responds to '[]' was expected to enable lookup using key '#{segment}'" unless value.respond_to?(:'[]') && !value.instance_of?(Array)
        throw :no_such_key unless value.include?(segment)
      end
      value = value[segment]
    end
    value
  end

  def get_method_and_data(data, allow_methods)
    if match = data.match(/^(\w+)\((?:["]([^"]+)["]|[']([^']+)['])\)$/)
      raise Puppet::DataBinding::LoookupError, 'Interpolation using method syntax is not allowed in this context' unless allow_methods
      key = match[1]
      data = match[2] || match[3] # double or single qouted
    else
      key = 'scope'
    end
    [key, data]
  end
end
