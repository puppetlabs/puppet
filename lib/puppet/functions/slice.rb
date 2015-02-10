# Applies a parameterized block to each _slice_ of elements in a sequence of selected entries from the first
# argument and returns the first argument, or if no block is given returns a new array with a concatenation of
# the slices.
#
# This function takes two mandatory arguments: the first, `$a`, should be an Array, Hash, or something of
# enumerable type (integer, Integer range, or String), and the second, `$n`, the number of elements to include
# in each slice. The optional third argument should be a a parameterized block as produced by the puppet syntax:
#
#     $a.slice($n) |$x| { ... }
#     slice($a) |$x| { ... }
#
# The parameterized block should have either one parameter (receiving an array with the slice), or the same number
# of parameters as specified by the slice size (each parameter receiving its part of the slice).
# In case there are fewer remaining elements than the slice size for the last slice it will contain the remaining
# elements. When the block has multiple parameters, excess parameters are set to undef for an array or
# enumerable type, and to empty arrays for a Hash.
#
#     $a.slice(2) |$first, $second| { ... }
#
# When the first argument is a Hash, each `key,value` entry is counted as one, e.g, a slice size of 2 will produce
# an array of two arrays with key, and value.
#
# @example Using slice with Hash
#
#     $a.slice(2) |$entry|          { notice "first ${$entry[0]}, second ${$entry[1]}" }
#     $a.slice(2) |$first, $second| { notice "first ${first}, second ${second}" }
#
# When called without a block, the function produces a concatenated result of the slices.
#
# @example Using slice without a block
#
#     slice([1,2,3,4,5,6], 2) # produces [[1,2], [3,4], [5,6]]
#     slice(Integer[1,6], 2)  # produces [[1,2], [3,4], [5,6]]
#     slice(4,2)              # produces [[0,1], [2,3]]
#     slice('hello',2)        # produces [[h, e], [l, l], [o]]
#
# @since 3.2 for Array and Hash
# @since 3.5 for additional enumerable types
# @note requires `parser = future`.
#
Puppet::Functions.create_function(:slice) do
  dispatch :slice_Hash do
    param 'Hash[Any, Any]', :hash
    param 'Integer[1, default]', :slize_size
    optional_block_param
  end

  dispatch :slice_Enumerable do
    param 'Any', :enumerable
    param 'Integer[1, default]', :slize_size
    optional_block_param
  end

  def slice_Hash(hash, slice_size, &pblock)
    result = slice_Common(hash, slice_size, [], block_given? ? pblock : nil)
    block_given? ? hash : result
  end

  def slice_Enumerable(enumerable, slice_size, &pblock)
    enum = asserted_enumerable(enumerable)
    result = slice_Common(enum, slice_size, nil, block_given? ? pblock : nil)
    block_given? ? enumerable : result
  end

  def slice_Common(o, slice_size, filler, pblock)
    serving_size = asserted_slice_serving_size(pblock, slice_size)

    enumerator = o.each_slice(slice_size)
    result = []
    if serving_size == 1
      begin
        if pblock
          loop do
            pblock.call(enumerator.next)
          end
        else
          loop do
            result << enumerator.next
          end
        end
      rescue StopIteration
      end
    else
      begin
        loop do
          a = enumerator.next
          if a.size < serving_size
            a = a.dup.fill(filler, a.length...serving_size)
          end
          pblock.call(*a)
        end
      rescue StopIteration
      end
    end
    if pblock
      o
    else
      result
    end
  end

  def asserted_slice_serving_size(pblock, slice_size)
    if pblock
      arity = pblock.arity
      serving_size = arity < 0 ? slice_size : arity
    else
      serving_size = 1
    end
    if serving_size == 0
      raise ArgumentError, "slice(): block must define at least one parameter. Block has 0."
    end
    unless serving_size == 1 || serving_size == slice_size
      raise ArgumentError, "slice(): block must define one parameter, or " +
        "the same number of parameters as the given size of the slice (#{slice_size}). Block has #{serving_size}; "+
      pblock.parameter_names.join(', ')
    end
    serving_size
  end

  def asserted_enumerable(obj)
    unless enum = Puppet::Pops::Types::Enumeration.enumerator(obj)
      raise ArgumentError, ("#{self.class.name}(): wrong argument type (#{obj.class}; must be something enumerable.")
    end
    enum
  end

end
