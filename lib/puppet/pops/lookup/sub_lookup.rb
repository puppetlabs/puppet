module Puppet::Pops
module Lookup
module SubLookup
  SPECIAL = /['"\.]/

  # Split key into segments. A segment may be a quoted string (both single and double quotes can
  # be used) and the segment separator is the '.' character. Whitespace will be trimmed off on
  # both sides of each segment. Whitespace within quotes are not trimmed.
  #
  # If the key cannot be parsed, this method will yield a string describing the problem to a one
  # parameter block. The block must return an exception instance.
  #
  # @param key [String] the string to split
  # @return [Array<String>] the array of segments
  # @yieldparam problem [String] the problem, i.e. 'Syntax error'
  # @yieldreturn [Exception] the exception to raise
  #
  # @api public
  def split_key(key)
    return [key] if key.match(SPECIAL).nil?
    segments = key.split(/(\s*"[^"]+"\s*|\s*'[^']+'\s*|[^'".]+)/)
    if segments.empty?
      # Only happens if the original key was an empty string
      raise yield('Syntax error')
    elsif segments.shift == ''
      count = segments.size
      raise yield('Syntax error') unless count > 0

      segments.keep_if { |seg| seg != '.' }
      raise yield('Syntax error') unless segments.size * 2 == count + 1
      segments.map! do |segment|
        segment.strip!
        if segment.start_with?('"') || segment.start_with?("'")
          segment[1..-2]
        elsif segment =~ /^(:?[+-]?[0-9]+)$/
          segment.to_i
        else
          segment
        end
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
  # @param context [Context] The current lookup context
  # @param segments [Array<String>] the segments to use for lookup
  # @param value [Object] the value to access using the segments
  # @return [Object] the value obtained when accessing the value
  #
  # @api public
  def sub_lookup(key, context, segments, value)
    lookup_invocation = context.is_a?(Invocation) ? context : context.invocation
    lookup_invocation.with(:sub_lookup, segments) do
      segments.each do |segment|
        lookup_invocation.with(:segment, segment) do
          if value.nil?
            lookup_invocation.report_not_found(segment)
            throw :no_such_key
          end
          if segment.is_a?(Integer) && value.instance_of?(Array)
            unless segment >= 0 && segment < value.size
              lookup_invocation.report_not_found(segment)
              throw :no_such_key
            end
          else
            unless value.respond_to?(:'[]') && !(value.is_a?(Array) || value.instance_of?(String))
              raise Puppet::DataBinding::LookupError,
                _("Data Provider type mismatch: Got %{klass} when a hash-like object was expected to access value using '%{segment}' from key '%{key}'") %
                  { klass: value.class.name, segment: segment, key: key }
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
