# Produces a unique set of values from an `Iterable` argument.
#
# * If the argument is a `String`, the unique set of characters are returned as a new `String`.
# * If the argument is a `Hash`, the resulting hash associates a set of keys with a set of unique values.
# * For all other types of `Iterable` (`Array`, `Iterator`) the result is an `Array` with
#   a unique set of entries.
# * Comparison of all `String` values are case sensitive.
# * An optional code block can be given - if present it is given each candidate value and its return is used instead of the given value. This
#   enables transformation of the value before comparison. The result of the lambda is only used for comparison.
# * The optional code block when used with a hash is given each value (not the keys).
#
# @example Using unique with a String
#
# ```puppet
# # will produce 'abc'
# "abcaabb".unique
# ```
#
# @example Using unique with an Array
#
# ```puppet
# # will produce ['a', 'b', 'c']
# ['a', 'b', 'c', 'a', 'a', 'b'].unique
# ```
#
# @example Using unique with a Hash
#
# ```puppet
# # will produce { ['a', 'b'] => [10], ['c'] => [20]}
# {'a' => 10, 'b' => 10, 'c' => 20}.unique
#
# # will produce { 'a' => 10, 'c' => 20 } (use first key with first value)
# Hash.new({'a' => 10, 'b' => 10, 'c' => 20}.unique.map |$k, $v| { [ $k[0] , $v[0]] })
#
# # will produce { 'b' => 10, 'c' => 20 } (use last key with first value)
# Hash.new({'a' => 10, 'b' => 10, 'c' => 20}.unique.map |$k, $v| { [ $k[-1] , $v[0]] })
# ```
#
# @example Using unique with an Iterable
#
# ```
# # will produce [3, 2, 1]
# [1,2,2,3,3].reverse_each.unique
# ```
#
# @example Using unique with a lambda
#
# ```puppet
# # will produce [['sam', 'smith'], ['sue', 'smith']]
# [['sam', 'smith'], ['sam', 'brown'], ['sue', 'smith']].unique |$x| { $x[0] }
#
# # will produce [['sam', 'smith'], ['sam', 'brown']]
# [['sam', 'smith'], ['sam', 'brown'], ['sue', 'smith']].unique |$x| { $x[1] }
#
# # will produce ['aBc', 'bbb'] (using a lambda to make comparison using downcased (%d) strings)
# ['aBc', 'AbC', 'bbb'].unique |$x| { String($x,'%d') }
#
# # will produce {[a] => [10], [b, c, d, e] => [11, 12, 100]}
# {a => 10, b => 11, c => 12, d => 100, e => 11}.unique |$v| { if $v > 10 { big } else { $v } } 
# ```
#
# Note that for `Hash` the result is slightly different than for the other data types. For those the result contains the
# *first-found* unique value, but for `Hash` it contains associations from a set of keys to the set of values clustered by the
# equality lambda (or the default value equality if no lambda was given). This makes the `unique` function more versatile for hashes
# in general, while requiring that the simple computation of "hash's unique set of values" is performed as `$hsh.map |$k, $v| { $v }.unique`.
# (A unique set of hash keys is in general meaningless (since they are unique by definition) - although if processed with a different
# lambda for equality that would be different. First map the hash to an array of its keys if such a unique computation is wanted). 
# If the more advanced clustering is wanted for one of the other data types, simply transform it into a `Hash` as shown in the
# following example.
#
# @example turning a string or array into a hash with index keys
#
# ```puppet
# # Array ['a', 'b', 'c'] to Hash with index results in
# # {0 => 'a', 1 => 'b', 2 => 'c'}
# Hash(['a', 'b', 'c'].map |$i, $v| { [$i, $v]})
#
# # String "abc" to Hash with index results in
# # {0 => 'a', 1 => 'b', 2 => 'c'}
# Hash(Array("abc").map |$i,$v| { [$i, $v]})
# "abc".to(Array).map |$i,$v| { [$i, $v]}.to(Hash)
# ```
#
# @since Puppet 5.0.0
#
Puppet::Functions.create_function(:unique) do
  dispatch :unique_string do
    param 'String', :string
    optional_block_param 'Callable[String]', :block
  end

  dispatch :unique_hash do
    param 'Hash', :hash
    optional_block_param 'Callable[Any]', :block
  end

  dispatch :unique_array do
    param 'Array', :array
    optional_block_param 'Callable[Any]', :block
  end

  dispatch :unique_iterable do
    param 'Iterable', :iterable
    optional_block_param 'Callable[Any]', :block
  end

  def unique_string(string, &block)
    string.split('').uniq(&block).join('')
  end

  def unique_hash(hash, &block)
    block = lambda {|v| v } unless block_given?
    result = Hash.new {|h, k| h[k] = {:keys =>[], :values =>[]} }
    hash.each_pair do |k,v|
      rc = result[ block.call(v) ]
      rc[:keys] << k
      rc[:values] << v
    end
    # reduce the set of possibly duplicated value entries
    inverted = {}
    result.each_pair {|k,v| inverted[v[:keys]] = v[:values].uniq }
    inverted
  end

  def unique_array(array,&block)
    array.uniq(&block)
  end

  def unique_iterable(iterable, &block)
    Puppet::Pops::Types::Iterable.on(iterable).uniq(&block)
  end
end
