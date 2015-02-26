#  Applies a parameterized block to each element in a sequence of selected entries from the first
#  argument and returns the first argument.
#
# This function takes two mandatory arguments: the first should be an Array or a Hash or something that is
# of enumerable type (integer, Integer range, or String), and the second
# a parameterized block as produced by the puppet syntax:
#
#       $a.each |$x| { ... }
#       each($a) |$x| { ... }
#
# When the first argument is an Array (or of enumerable type other than Hash), the parameterized block
# should define one or two block parameters.
# For each application of the block, the next element from the array is selected, and it is passed to
# the block if the block has one parameter. If the block has two parameters, the first is the elements
# index, and the second the value. The index starts from 0.
#
#       $a.each |$index, $value| { ... }
#       each($a) |$index, $value| { ... }
#
# When the first argument is a Hash, the parameterized block should define one or two parameters.
# When one parameter is defined, the iteration is performed with each entry as an array of `[key, value]`,
# and when two parameters are defined the iteration is performed with key and value.
#
#       $a.each |$entry|       { ..."key ${$entry[0]}, value ${$entry[1]}" }
#       $a.each |$key, $value| { ..."key ${key}, value ${value}" }
#
# @example using each
#
#       [1,2,3].each |$val| { ... }                       # 1, 2, 3
#       [5,6,7].each |$index, $val| { ... }               # (0, 5), (1, 6), (2, 7)
#       {a=>1, b=>2, c=>3}].each |$val| { ... }           # ['a', 1], ['b', 2], ['c', 3]
#       {a=>1, b=>2, c=>3}.each |$key, $val| { ... }      # ('a', 1), ('b', 2), ('c', 3)
#       Integer[ 10, 20 ].each |$index, $value| { ... }   # (0, 10), (1, 11) ...
#       "hello".each |$char| { ... }                      # 'h', 'e', 'l', 'l', 'o'
#       3.each |$number| { ... }                          # 0, 1, 2
#
# @since 3.2 for Array and Hash
# @since 3.5 for other enumerables
# @note requires `parser = future`
#
Puppet::Functions.create_function(:each) do
  dispatch :foreach_Hash_2 do
    param 'Hash[Any, Any]', :hash
    block_param 'Callable[2,2]', :block
  end

  dispatch :foreach_Hash_1 do
    param 'Hash[Any, Any]', :hash
    block_param 'Callable[1,1]', :block
  end

  dispatch :foreach_Enumerable_2 do
    param 'Any', :enumerable
    block_param 'Callable[2,2]', :block
  end

  dispatch :foreach_Enumerable_1 do
    param 'Any', :enumerable
    block_param 'Callable[1,1]', :block
  end

  def foreach_Hash_1(hash)
    enumerator = hash.each_pair
    hash.size.times do
      yield(enumerator.next)
    end
    # produces the receiver
    hash
  end

  def foreach_Hash_2(hash)
    enumerator = hash.each_pair
    hash.size.times do
      yield(*enumerator.next)
    end
    # produces the receiver
    hash
  end

  def foreach_Enumerable_1(enumerable)
    enum = asserted_enumerable(enumerable)
      begin
        loop { yield(enum.next) }
      rescue StopIteration
      end
    # produces the receiver
    enumerable
  end

  def foreach_Enumerable_2(enumerable)
    enum = asserted_enumerable(enumerable)
    index = 0
    begin
      loop do
        yield(index, enum.next)
        index += 1
      end
    rescue StopIteration
    end
    # produces the receiver
    enumerable
  end

  def asserted_enumerable(obj)
    unless enum = Puppet::Pops::Types::Enumeration.enumerator(obj)
      raise ArgumentError, ("#{self.class.name}(): wrong argument type (#{obj.class}; must be something enumerable.")
    end
    enum
  end

end
