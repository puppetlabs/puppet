# frozen_string_literal: true

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
    args.reduce(data) do |d, k|
      return nil if d.nil? || k.nil?

      unless (d.is_a?(Array) || d.is_a?(Hash))
        t = Puppet::Pops::Types::TypeCalculator.infer(d)
        msg = _("The given data does not contain a Collection at %{walked_path}, got '%{type}'") % { walked_path: walked_path, type: t }
        error_data = Puppet::DataTypes::Error.new(
          msg,
          'SLICE_ERROR',
          { 'walked_path' => walked_path, 'value_type' => t },
          'EXPECTED_COLLECTION'
        )
        raise Puppet::ErrorWithData.new(error_data, msg)
      end

      walked_path << k
      if d.is_a?(Array) && !k.is_a?(Integer)
        t = Puppet::Pops::Types::TypeCalculator.infer(k)
        msg = _("The given data requires an Integer index at %{walked_path}, got '%{type}'") % { walked_path: walked_path, type: t }
        error_data = Puppet::DataTypes::Error.new(
          msg,
          'SLICE_ERROR',
          { 'walked_path' => walked_path, 'index_type' => t },
          'EXPECTED_INTEGER_INDEX'
        )
        raise Puppet::ErrorWithData.new(error_data, msg)
      end
      d[k]
    end
  end
end
