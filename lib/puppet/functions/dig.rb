# Returns a value for a sequence of given keys/indexes into a structure, such as
# an array or hash.
# This function is used to "dig into" a complex data structure by
# using a sequence of keys or indexes to access a value, from which
# the next key or index is accessed recursively.
#
# The first encountered `undef` value or key stops the "dig" and returns `undef`.
#
# The function raises an error if it attempts to "dig" into
# something other than an `Array`, a `Hash`, or an `undef` value.
#
# @example Using `dig`
#
# ``` puppet
# $data = {a => { b => [{x => 10, y => 20}, {x => 100, y => 200}]}}
# notice $data.dig('a', 'b', 1, 'x')
# ```
#
# This example produces the notice `100`.
#
# This is similar to `$data['a']['b'][1]['x']`. However, a standard
# index returns an error and causes catalog compilation failure if any parent
# of the final key (`'x'`) is `undef`. The `dig` function will return `undef`
# rather than failing catalog compilation, which allows you to check if data
# exists in a structure without mandating that it must always exist.
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
        raise ArgumentError, _("The given data does not contain a Collection at %{walked_path}, got '%{klass}'") % { walked_path: walked_path, klass: d.class }
      end
      walked_path << k
      d[k]
    end
  end
end
