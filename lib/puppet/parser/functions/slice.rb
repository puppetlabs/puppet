Puppet::Parser::Functions::newfunction(
:slice,
:type => :rvalue,
:arity => -2,
:doc => <<-'ENDHEREDOC') do |args|
  Applies a parameterized block to each _slice_ of elements in a sequence of selected entries from the first
  argument and returns the first argument, or if no block is given returns a new array with a concatenation of
  the slices.

  This function takes two mandatory arguments: the first, `$a`, should be an Array, Hash, or something of
  enumerable type (integer, Integer range, or String), and the second, `$n`, the number of elements to include
  in each slice. The optional third argument should be a a parameterized block as produced by the puppet syntax:

      $a.slice($n) |$x| { ... }
      slice($a) |$x| { ... }

  The parameterized block should have either one parameter (receiving an array with the slice), or the same number
  of parameters as specified by the slice size (each parameter receiving its part of the slice).
  In case there are fewer remaining elements than the slice size for the last slice it will contain the remaining
  elements. When the block has multiple parameters, excess parameters are set to :undef for an array or
  enumerable type, and to empty arrays for a Hash.

      $a.slice(2) |$first, $second| { ... }

  When the first argument is a Hash, each `key,value` entry is counted as one, e.g, a slice size of 2 will produce
  an array of two arrays with key, and value.

      $a.slice(2) |$entry|          { notice "first ${$entry[0]}, second ${$entry[1]}" }
      $a.slice(2) |$first, $second| { notice "first ${first}, second ${second}" }

  When called without a block, the function produces a concatenated result of the slices.

      slice([1,2,3,4,5,6], 2) # produces [[1,2], [3,4], [5,6]]
      slice(Integer[1,6], 2)  # produces [[1,2], [3,4], [5,6]]
      slice(4,2)              # produces [[0,1], [2,3]]
      slice('hello',2)        # produces [[h, e], [l, l], [o]]

  - Since 3.2 for Array and Hash
  - Since 3.5 for additional enumerable types
  - requires `parser = future`.
  ENDHEREDOC
  require 'puppet/parser/ast/lambda'
  require 'puppet/parser/scope'

  def each_Common(o, slice_size, filler, scope, pblock)
    serving_size = pblock ? pblock.parameter_count : 1
    if serving_size == 0
      raise ArgumentError, "slice(): block must define at least one parameter. Block has 0."
    end
    unless serving_size == 1 || serving_size == slice_size
      raise ArgumentError, "slice(): block must define one parameter, or " +
        "the same number of parameters as the given size of the slice (#{slice_size}). Block has #{serving_size}; "+
      pblock.parameter_names.join(', ')
    end
    enumerator = o.each_slice(slice_size)
    result = []
    if serving_size == 1
      begin
        if pblock
          loop do
            pblock.call(scope, enumerator.next)
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
          pblock.call(scope, *a)
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

  raise ArgumentError, ("slice(): wrong number of arguments (#{args.length}; must be 2 or 3)") unless args.length == 2 || args.length == 3
  if args.length >= 2
    begin
      slice_size = Puppet::Parser::Scope.number?(args[1])
    rescue
      raise ArgumentError, ("slice(): wrong argument type (#{args[1]}; must be number.")
    end
  end
  raise ArgumentError, ("slice(): wrong argument type (#{args[1]}; must be number.") unless slice_size
  raise ArgumentError, ("slice(): wrong argument value: #{slice_size}; is not a positive integer number > 0") unless slice_size.is_a?(Fixnum) && slice_size > 0
  receiver = args[0]

  # the block is optional, ok if nil, function then produces an array
  pblock = args[2]
  raise ArgumentError, ("slice(): wrong argument type (#{args[2].class}; must be a parameterized block.") unless pblock.respond_to?(:puppet_lambda) || args.length == 2

  case receiver
  when Hash
    each_Common(receiver, slice_size, [], self, pblock)
  else
    enum = Puppet::Pops::Types::Enumeration.enumerator(receiver)
    if enum.nil?
      raise ArgumentError, ("slice(): given type '#{tc.string(receiver)}' is not enumerable")
    end
    result = each_Common(enum, slice_size, :undef, self, pblock)
    pblock ? receiver : result
  end
end
