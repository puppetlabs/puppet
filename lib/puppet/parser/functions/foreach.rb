Puppet::Parser::Functions::newfunction(
:foreach,
:type => :rvalue,
:arity => 2,
:doc => <<-'ENDHEREDOC') do |args|
  Applies a parameterized block to each element in a sequence of selected entries from the first
  argument and returns the first argument.

  This function takes two mandatory arguments: the first should be an Array or a Hash, and the second
  a parameterized block as produced by the puppet syntax:

        $a.foreach {|$x| ... }

  When the first argument is an Array, the parameterized block should define one or two block parameters.
  For each application of the block, the next element from the array is selected, and it is passed to
  the block if the block has one parameter. If the block has two parameters, the first is the elements
  index, and the second the value. The index starts from 0.

        $a.foreach {|$index, $value| ... }

  When the first argument is a Hash, the parameterized block should define one or two parameters.
  When one parameter is defined, the iteration is performed with each entry as an array of `[key, value]`,
  and when two parameters are defined the iteration is performed with key and value.

        $a.foreach {|$entry|       ..."key ${$entry[0]}, value ${$entry[1]}" }
        $a.foreach {|$key, $value| ..."key ${key}, value ${value}" }

  - Since 3.2
  - requires `parser = future`.
  ENDHEREDOC
  require 'puppet/parser/ast/lambda'

  def foreach_Array(o, scope, pblock)
    return nil unless pblock

    serving_size = pblock.parameter_count
    if serving_size == 0
      raise ArgumentError, "Block must define at least one parameter; value."
    end
    if serving_size > 2
      raise ArgumentError, "Block must define at most two parameters; index, value"
    end
    enumerator = o.each
    index = 0
    if serving_size == 1
      (o.size).times do
        pblock.call(scope, enumerator.next)
      end
    else
      (o.size).times do
        pblock.call(scope, index, enumerator.next)
        index = index +1
      end
    end
    o
  end

  def foreach_Hash(o, scope, pblock)
    return nil unless pblock
    serving_size = pblock.parameter_count
    case serving_size
    when 0
      raise ArgumentError, "Block must define at least one parameter (for hash entry key)."
    when 1
    when 2
    else
      raise ArgumentError, "Block must define at most two parameters (for hash entry key and value)."
    end
    enumerator = o.each_pair
    if serving_size == 1
      (o.size).times do
        pblock.call(scope, enumerator.next)
      end
    else
      (o.size).times do
        pblock.call(scope, *enumerator.next)
      end
    end
    o
  end

  raise ArgumentError, ("foreach(): wrong number of arguments (#{args.length}; must be 2)") if args.length != 2
  receiver = args[0]
  pblock = args[1]
  raise ArgumentError, ("foreach(): wrong argument type (#{args[1].class}; must be a parameterized block.") unless pblock.is_a? Puppet::Parser::AST::Lambda

  case receiver
  when Array
    foreach_Array(receiver, self, pblock)
  when Hash
    foreach_Hash(receiver, self, pblock)
  else
    raise ArgumentError, ("foreach(): wrong argument type (#{args[0].class}; must be an Array or a Hash.")
  end
end
