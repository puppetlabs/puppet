module Puppet::Pops
module Lookup
module SubLookup
  # Split key into segments. A segment may be a quoted string (both single and double quotes can
  # be used) and the segment separator is the '.' character. Whitespace will be trimmed off on
  # both sides of each segment. Whitespace within quotes are not trimmed.
  #
  # If the key cannot be parsed, this method will yield a string describing the problem to a one
  # parameter block. The block must return an exception instance.
  #
  # @param key [String] the string to split
  # @return Array<String> the array of segments
  # @yieldparam problem [String] the problem, i.e. 'Syntax error'
  # @yieldreturn [Exception] the exception to raise
  #
  # @api public
  def split_key(key)
    segments = key.split(/(\s*"[^"]+"\s*|\s*'[^']+'\s*|[^'".]+)/)
    if segments.empty?
      # Only happens if the original key was an empty string
      ''
    elsif segments.shift == ''
      count = segments.size
      raise yield('Syntax error') unless count > 0

      segments.keep_if { |seg| seg != '.' }
      raise yield('Syntax error') unless segments.size * 2 == count + 1
      segments.map! do |segment|
        segment.strip!
        segment.start_with?('"') || segment.start_with?("'") ? segment[1..-2] : segment
      end
    else
      raise yield('Syntax error')
    end
  end

  # Perform a sub-lookup using the given _segments_ to access the given _value_. Each segment must be a string. A string
  # consisting entirely of digits will be treated as an indexed lookup which means that the value that it is applied to
  # must be an array. Other types of segments will expect that the given value is something other than a String that
  # implements the '#[]' method.
  #
  # @param key [String] the original key (only used for error messages)
  # @param lookup_invocation [Invocation] The current lookup invocation
  # @param segments [Array<String>] the segments to use for lookup
  # @param value [Object] the value to access using the segments
  # @return [Object] the value obtained when accessing the value
  #
  # @api public
  def sub_lookup(key, lookup_invocation, segments, value)
    lookup_invocation.with(:sub_lookup, segments) do
      segments.each do |segment|
        lookup_invocation.with(:segment, segment) do
          if value.nil?
            lookup_invocation.report_not_found(segment)
            throw :no_such_key
          end
          if segment =~ /^[0-9]+$/
            segment = segment.to_i
            unless value.instance_of?(Array)
              raise Puppet::DataBinding::LookupError,
                "Data Provider type mismatch: Got #{value.class.name} when Array was expected to access value using '#{segment}' from key '#{key}'"
            end
            unless segment < value.size
              lookup_invocation.report_not_found(segment)
              throw :no_such_key
            end
          else
            unless value.respond_to?(:'[]') && !(value.instance_of?(Array) || value.instance_of?(String))
              raise Puppet::DataBinding::LookupError,
                "Data Provider type mismatch: Got #{value.class.name} when a hash-like object was expected to access value using '#{segment}' from key '#{key}'"
            end
            unless value.include?(segment)
              lookup_invocation.report_not_found(segment)
              throw :no_such_key
            end
          end
          value = value[segment]
          lookup_invocation.report_found(segment, value)
        end
      end
      value
    end
  end
end
end
end
