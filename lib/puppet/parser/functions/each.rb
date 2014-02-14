Puppet::Parser::Functions::newfunction(
:each,
:type => :rvalue,
:arity => 2,
:doc => <<-'ENDHEREDOC') do |args|
  Applies a parameterized block to each element in a sequence of selected entries from the first
  argument and returns the first argument.

  This function takes two mandatory arguments: the first should be an Array or a Hash or something that is
  of enumerable type (integer, Integer range, or String), and the second
  a parameterized block as produced by the puppet syntax:

        $a.each |$x| { ... }
        each($a) |$x| { ... }

  When the first argument is an Array (or of enumerable type other than Hash), the parameterized block
  should define one or two block parameters.
  For each application of the block, the next element from the array is selected, and it is passed to
  the block if the block has one parameter. If the block has two parameters, the first is the elements
  index, and the second the value. The index starts from 0.

        $a.each |$index, $value| { ... }
        each($a) |$index, $value| { ... }

  When the first argument is a Hash, the parameterized block should define one or two parameters.
  When one parameter is defined, the iteration is performed with each entry as an array of `[key, value]`,
  and when two parameters are defined the iteration is performed with key and value.

        $a.each |$entry|       { ..."key ${$entry[0]}, value ${$entry[1]}" }
        $a.each |$key, $value| { ..."key ${key}, value ${value}" }

  *Examples*

        [1,2,3].each |$val| { ... }                       # 1, 2, 3
        [5,6,7].each |$index, $val| { ... }               # (0, 5), (1, 6), (2, 7)
        {a=>1, b=>2, c=>3}].each |$val| { ... }           # ['a', 1], ['b', 2], ['c', 3]
        {a=>1, b=>2, c=>3}.each |$key, $val| { ... }      # ('a', 1), ('b', 2), ('c', 3)
        Integer[ 10, 20 ].each |$index, $value| { ... }   # (0, 10), (1, 11) ...
        "hello".each |$char| { ... }                      # 'h', 'e', 'l', 'l', 'o'
        3.each |$number| { ... }                          # 0, 1, 2

  - Since 3.2 for Array and Hash
  - Since 3.5 for other enumerables
  - requires `parser = future`.
  ENDHEREDOC
  require 'puppet/parser/ast/lambda'

  def foreach_Hash(o, scope, pblock, serving_size)
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
  end

  def foreach_Enumerator(enumerator, scope, pblock, serving_size)
    index = 0
    if serving_size == 1
      begin
        loop { pblock.call(scope, enumerator.next) }
      rescue StopIteration
      end
    else
      begin
        loop do
          pblock.call(scope, index, enumerator.next)
          index = index +1
        end
      rescue StopIteration
      end
    end
  end

  raise ArgumentError, ("each(): wrong number of arguments (#{args.length}; expected 2, got #{args.length})") if args.length != 2
  receiver = args[0]
  pblock = args[1]
  raise ArgumentError, ("each(): wrong argument type (#{args[1].class}; must be a parameterized block.") unless pblock.respond_to?(:puppet_lambda)

  serving_size = pblock.parameter_count
  if serving_size == 0
    raise ArgumentError, "each(): block must define at least one parameter; value. Block has 0."
  end

  case receiver
  when Hash
    if serving_size > 2
      raise ArgumentError, "each(): block must define at most two parameters; key, value. Block has #{serving_size}; "+
      pblock.parameter_names.join(', ')
    end
    foreach_Hash(receiver, self, pblock, serving_size)
  else
    if serving_size > 2
      raise ArgumentError, "each(): block must define at most two parameters; index, value. Block has #{serving_size}; "+
        pblock.parameter_names.join(', ')
    end
    enum = Puppet::Pops::Types::Enumeration.enumerator(receiver)
    unless enum
      raise ArgumentError, ("each(): wrong argument type (#{receiver.class}; must be something enumerable.")
    end
    foreach_Enumerator(enum, self, pblock, serving_size)
  end
  # each always produces the receiver
  receiver
end
