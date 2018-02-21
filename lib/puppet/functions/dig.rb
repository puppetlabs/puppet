# Returns a value for a sequence of given keys/indexes into a structure, such as
# an array or hash.
#
# This function is used to "dig into" a complex data structure by
# using a sequence of keys / indexes to access a value from which
# the next key/index is accessed recursively.
#
# The first encountered `undef` value or key stops the "dig" and `undef` is returned.
#
# An error is raised if an attempt is made to "dig" into
# something other than an `undef` (which immediately returns `undef`), an `Array` or a `Hash`.
#
# @example Using `dig`
#
# ```puppet
# $data = {a => { b => [{x => 10, y => 20}, {x => 100, y => 200}]}}
# notice $data.dig('a', 'b', 1, 'x')
# ```
#
# Would notice the value 100.
#
# This is roughly equivalent to `$data['a']['b'][1]['x']`. However, a standard
# index will return an error and cause catalog compilation failure if any parent
# of the final key (`'x'`) is `undef`. The `dig` function will return `undef`,
# rather than failing catalog compilation. This allows you to check if data
# exists in a structure without mandating that it always exists.
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
