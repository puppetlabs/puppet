# Applies a parameterized block to each element in a sequence of entries from the first
# argument and returns an array or hash (same type as left operand for array/hash, and array for
# other enumerable types) with the entries for which the block evaluates to `true`.
#
# This function takes two mandatory arguments: the first should be an Array, a Hash, or an
# Enumerable object (integer, Integer range, or String),
# and the second a parameterized block as produced by the puppet syntax:
#
#       $a.filter |$x| { ... }
#       filter($a) |$x| { ... }
#
# When the first argument is something other than a Hash, the block is called with each entry in turn.
# When the first argument is a Hash the entry is an array with `[key, value]`.
#
# @example Using filter with one parameter
#
#       # selects all that end with berry
#       $a = ["raspberry", "blueberry", "orange"]
#       $a.filter |$x| { $x =~ /berry$/ }          # rasberry, blueberry
#
# If the block defines two parameters, they will be set to `index, value` (with index starting at 0) for all
# enumerables except Hash, and to `key, value` for a Hash.
#
# @example Using filter with two parameters
#
#      # selects all that end with 'berry' at an even numbered index
#      $a = ["raspberry", "blueberry", "orange"]
#      $a.filter |$index, $x| { $index % 2 == 0 and $x =~ /berry$/ } # raspberry
#
#      # selects all that end with 'berry' and value >= 1
#      $a = {"raspberry"=>0, "blueberry"=>1, "orange"=>1}
#      $a.filter |$key, $x| { $x =~ /berry$/ and $x >= 1 } # blueberry
#
# @since 3.4 for Array and Hash
# @since 3.5 for other enumerables
# @note requires `parser = future`
#
Puppet::Functions.create_function(:filter) do
  dispatch :filter_Hash_2 do
    param 'Hash[Any, Any]', :hash
    required_block_param 'Callable[2,2]', :block
  end

  dispatch :filter_Hash_1 do
    param 'Hash[Any, Any]', :hash
    required_block_param 'Callable[1,1]', :block
  end

  dispatch :filter_Enumerable_2 do
    param 'Any', :enumerable
    required_block_param 'Callable[2,2]', :block
  end

  dispatch :filter_Enumerable_1 do
    param 'Any', :enumerable
    required_block_param 'Callable[1,1]', :block
  end

  def filter_Hash_1(hash, pblock)
    result = hash.select {|x, y| pblock.call(self, [x, y]) }
    # Ruby 1.8.7 returns Array
    result = Hash[result] unless result.is_a? Hash
    result
  end

  def filter_Hash_2(hash, pblock)
    result = hash.select {|x, y| pblock.call(self, x, y) }
    # Ruby 1.8.7 returns Array
    result = Hash[result] unless result.is_a? Hash
    result
  end

  def filter_Enumerable_1(enumerable, pblock)
    result = []
    index = 0
    enum = asserted_enumerable(enumerable)
    begin
      loop do
        it = enum.next
        if pblock.call(nil, it) == true
          result << it
        end
      end
    rescue StopIteration
    end
    result
  end

  def filter_Enumerable_2(enumerable, pblock)
    result = []
    index = 0
    enum = asserted_enumerable(enumerable)
    begin
      loop do
        it = enum.next
        if pblock.call(nil, index, it) == true
          result << it
        end
        index += 1
      end
    rescue StopIteration
    end
    result
  end

  def asserted_enumerable(obj)
    unless enum = Puppet::Pops::Types::Enumeration.enumerator(obj)
      raise ArgumentError, ("#{self.class.name}(): wrong argument type (#{obj.class}; must be something enumerable.")
    end
    enum
  end

end
