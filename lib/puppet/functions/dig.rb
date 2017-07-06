# Digs into a data structure.
# (Documented in 3.x stub)
#
# @since 4.5.0
#
Puppet::Functions.create_function(:dig) do
  dispatch :dig do
    param 'Optional[Collection]', :data
    repeated_param 'Any', :arg
  end

  def dig(data, *args)
    walked_path = []
    args.reduce(data) do | d, k |
      return nil if d.nil? || k.nil?
      if !(d.is_a?(Array) || d.is_a?(Hash))
        raise ArgumentError, "The given data does not contain a Collection at #{walked_path}, got '#{d.class}'"
      end
      walked_path << k
      d[k]
    end
  end
end
