Puppet::Parser::Functions::newfunction(
:reduce,
:type => :rvalue,
:arity => -2,
:doc => <<-'ENDHEREDOC') do |args|
  Applies a parameterized block to each element in a sequence of entries from the first
  argument (_the enumerable_) and returns the last result of the invocation of the parameterized block.

  This function takes two mandatory arguments: the first should be an Array, Hash, or something of
  enumerable type, and the last a parameterized block as produced by the puppet syntax:

        $a.reduce |$memo, $x| { ... }
        reduce($a) |$memo, $x| { ... }

  When the first argument is an Array or someting of an enumerable type, the block is called with each entry in turn.
  When the first argument is a hash each entry is converted to an array with `[key, value]` before being
  fed to the block. An optional 'start memo' value may be supplied as an argument between the array/hash
  and mandatory block.

        $a.reduce(start) |$memo, $x| { ... }
        reduce($a, start) |$memo, $x| { ... }

  If no 'start memo' is given, the first invocation of the parameterized block will be given the first and second
  elements of the enumeration, and if the enumerable has fewer than 2 elements, the first
  element is produced as the result of the reduction without invocation of the block.

  On each subsequent invocation, the produced value of the invoked parameterized block is given as the memo in the
  next invocation.

  *Examples*

        # Reduce an array
        $a = [1,2,3]
        $a.reduce |$memo, $entry| { $memo + $entry }
        #=> 6

        # Reduce hash values
        $a = {a => 1, b => 2, c => 3}
        $a.reduce |$memo, $entry| { [sum, $memo[1]+$entry[1]] }
        #=> [sum, 6]

        # reverse a string
        "abc".reduce |$memo, $char| { "$char$memo" }
        #=>"cbe"

  It is possible to provide a starting 'memo' as an argument.

  *Examples*

        # Reduce an array
        $a = [1,2,3]
        $a.reduce(4) |$memo, $entry| { $memo + $entry }
        #=> 10

        # Reduce hash values
        $a = {a => 1, b => 2, c => 3}
        $a.reduce([na, 4]) |$memo, $entry| { [sum, $memo[1]+$entry[1]] }
        #=> [sum, 10]

  *Examples*

        Integer[1,4].reduce |$memo, $x| { $memo + $x }
        #=> 10

  - Since 3.2 for Array and Hash
  - Since 3.5 for additional enumerable types
  - requires `parser = future`.
  ENDHEREDOC

  require 'puppet/parser/ast/lambda'

  case args.length
  when 2
    pblock = args[1]
  when 3
    pblock = args[2]
  else
    raise ArgumentError, ("reduce(): wrong number of arguments (#{args.length}; expected 2 or 3, got #{args.length})")
  end
  unless pblock.respond_to?(:puppet_lambda)
    raise ArgumentError, ("reduce(): wrong argument type (#{pblock.class}; must be a parameterized block.")
  end
  receiver = args[0]
  enum = Puppet::Pops::Types::Enumeration.enumerator(receiver)
  unless enum
    raise ArgumentError, ("reduce(): wrong argument type (#{receiver.class}; must be something enumerable.")
  end

  serving_size = pblock.parameter_count
  if serving_size != 2
    raise ArgumentError, "reduce(): block must define 2 parameters; memo, value. Block has #{serving_size}; "+
    pblock.parameter_names.join(', ')
  end

  if args.length == 3
    enum.reduce(args[1]) {|memo, x| pblock.call(self, memo, x) }
  else
    enum.reduce {|memo, x| pblock.call(self, memo, x) }
  end
end
