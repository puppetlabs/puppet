require 'puppet/parser/ast/lambda'

Puppet::Parser::Functions::newfunction(
:map,
:type => :rvalue,
:arity => 2,
:doc => <<-'ENDHEREDOC') do |args|
  Applies a parameterized block to each element in a sequence of entries from the first
  argument and returns an array with the result of each invocation of the parameterized block.

  This function takes two mandatory arguments: the first should be an Array, Hash, or of Enumerable type
  (integer, Integer range, or String), and the second a parameterized block as produced by the puppet syntax:

        $a.map |$x| { ... }
        map($a) |$x| { ... }

  When the first argument `$a` is an Array or of enumerable type, the block is called with each entry in turn.
  When the first argument is a hash the entry is an array with `[key, value]`.

  *Examples*

        # Turns hash into array of values
        $a.map |$x|{ $x[1] }

        # Turns hash into array of keys
        $a.map |$x| { $x[0] }

  When using a block with 2 parameters, the element's index (starting from 0) for an array, and the key for a hash
  is given to the block's first parameter, and the value is given to the block's second parameter.args.

  *Examples*

        # Turns hash into array of values
        $a.map |$key,$val|{ $val }

        # Turns hash into array of keys
        $a.map |$key,$val|{ $key }

  - Since 3.4 for Array and Hash
  - Since 3.5 for other enumerables, and support for blocks with 2 parameters
  - requires `parser = future`
  ENDHEREDOC

  def map_Enumerator(enumerator, scope, pblock, serving_size)
    result = []
    index = 0
    if serving_size == 1
      begin
        loop { result << pblock.call(scope, enumerator.next) }
      rescue StopIteration
      end
    else
      begin
        loop do
          result << pblock.call(scope, index, enumerator.next)
          index = index +1
        end
      rescue StopIteration
      end
    end
    result
  end

  receiver = args[0]
  pblock = args[1]

  raise ArgumentError, ("map(): wrong argument type (#{pblock.class}; must be a parameterized block.") unless pblock.respond_to?(:puppet_lambda)
  serving_size = pblock.parameter_count
  if serving_size == 0
    raise ArgumentError, "map(): block must define at least one parameter; value. Block has 0."
  end
  case receiver
  when Hash
    if serving_size > 2
      raise ArgumentError, "map(): block must define at most two parameters; key, value.args Block has #{serving_size}; "+
      pblock.parameter_names.join(', ')
    end
    if serving_size == 1
      result = receiver.map {|x, y| pblock.call(self, [x, y]) }
    else
      result = receiver.map {|x, y| pblock.call(self, x, y) }
    end
  else
    if serving_size > 2
      raise ArgumentError, "map(): block must define at most two parameters; index, value. Block has #{serving_size}; "+
      pblock.parameter_names.join(', ')
    end

    enum = Puppet::Pops::Types::Enumeration.enumerator(receiver)
    unless enum
      raise ArgumentError, ("map(): wrong argument type (#{receiver.class}; must be something enumerable.")
    end
    result = map_Enumerator(enum, self, pblock, serving_size)
  end
  result
end
