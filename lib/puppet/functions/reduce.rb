# Applies a parameterized block to each element in a sequence of entries from the first
# argument (_the enumerable_) and returns the last result of the invocation of the parameterized block.
#
# This function takes two mandatory arguments: the first should be an Array, Hash, or something of
# enumerable type, and the last a parameterized block as produced by the puppet syntax:
#
#       $a.reduce |$memo, $x| { ... }
#       reduce($a) |$memo, $x| { ... }
#
# When the first argument is an Array or someting of an enumerable type, the block is called with each entry in turn.
# When the first argument is a hash each entry is converted to an array with `[key, value]` before being
# fed to the block. An optional 'start memo' value may be supplied as an argument between the array/hash
# and mandatory block.
#
#       $a.reduce(start) |$memo, $x| { ... }
#       reduce($a, start) |$memo, $x| { ... }
#
# If no 'start memo' is given, the first invocation of the parameterized block will be given the first and second
# elements of the enumeration, and if the enumerable has fewer than 2 elements, the first
# element is produced as the result of the reduction without invocation of the block.
#
# On each subsequent invocation, the produced value of the invoked parameterized block is given as the memo in the
# next invocation.
#
# @example Using reduce
#
#       # Reduce an array
#       $a = [1,2,3]
#       $a.reduce |$memo, $entry| { $memo + $entry }
#       #=> 6
#
#       # Reduce hash values
#       $a = {a => 1, b => 2, c => 3}
#       $a.reduce |$memo, $entry| { [sum, $memo[1]+$entry[1]] }
#       #=> [sum, 6]
#
#       # reverse a string
#       "abc".reduce |$memo, $char| { "$char$memo" }
#       #=>"cbe"
#
# It is possible to provide a starting 'memo' as an argument.
#
# @example Using reduce with given start 'memo'
#
#       # Reduce an array
#       $a = [1,2,3]
#       $a.reduce(4) |$memo, $entry| { $memo + $entry }
#       #=> 10
#
#       # Reduce hash values
#       $a = {a => 1, b => 2, c => 3}
#       $a.reduce([na, 4]) |$memo, $entry| { [sum, $memo[1]+$entry[1]] }
#       #=> [sum, 10]
#
# @example Using reduce with an Integer range
#
#       Integer[1,4].reduce |$memo, $x| { $memo + $x }
#       #=> 10
#
# @since 3.2 for Array and Hash
# @since 3.5 for additional enumerable types
# @note requires `parser = future`.
#
Puppet::Functions.create_function(:reduce) do

  dispatch :reduce_without_memo do
    param 'Any', :enumerable
    required_block_param 'Callable[2,2]', :block
  end

  dispatch :reduce_with_memo do
    param 'Any', :enumerable
    param 'Any', :memo
    required_block_param 'Callable[2,2]', :block
  end

  def reduce_without_memo(enumerable, pblock)
    enum = asserted_enumerable(enumerable)
    enum.reduce {|memo, x| pblock.call(nil, memo, x) }
  end

  def reduce_with_memo(enumerable, given_memo, pblock)
    enum = asserted_enumerable(enumerable)
    enum.reduce(given_memo) {|memo, x| pblock.call(nil, memo, x) }
  end

  def asserted_enumerable(obj)
    unless enum = Puppet::Pops::Types::Enumeration.enumerator(obj)
      raise ArgumentError, ("#{self.class.name}(): wrong argument type (#{obj.class}; must be something enumerable.")
    end
    enum
  end

end
