Puppet::Parser::Functions::newfunction(
:reduce,
:type => :rvalue,
:arity => -2,
:doc => <<-'ENDHEREDOC') do |args|
  Applies a parameterized block to each element in a sequence of entries from the first
  argument (_the collection_) and returns the last result of the invocation of the parameterized block.

  This function takes two mandatory arguments: the first should be an Array, Hash, or enumerable type, and
  the last a parameterized block as produced by the puppet syntax:

        $a.reduce |$memo, $x| { ... }

  When the first argument is an Array or an enumerable type, the block is called with each entry in turn.
  When the first argument is a hash each entry is converted to an array with `[key, value]` before being
  fed to the block. An optional 'start memo' value may be supplied as an argument between the array/hash
  and mandatory block.

  If no 'start memo' is given, the first invocation of the parameterized block will be given the first and second
  elements of the collection, and if the collection has fewer than 2 elements, the first
  element is produced as the result of the reduction without invocation of the block.

  On each subsequent invocations, the produced value of the invoked parameterized block is given as the memo in the
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

  - Since 3.2
  - requires `parser = future`.
  ENDHEREDOC

  require 'puppet/parser/ast/lambda'

  def enumerable_Type(o)
    tc = Puppet::Pops::Types::TypeCalculator.new()
    enumerable = tc.enumerable(o)
    if enumerable.nil?
      raise ArgumentError, ("reduce(): given type '#{tc.string(o)}' is not enumerable")
    end
    enumerable.each
  end

  case args.length
  when 2
    pblock = args[1]
  when 3
    pblock = args[2]
  else
    raise ArgumentError, ("reduce(): wrong number of arguments (#{args.length}; must be 2 or 3)")
  end
  unless pblock.respond_to?(:puppet_lambda)
    raise ArgumentError, ("reduce(): wrong argument type (#{pblock.class}; must be a parameterized block.")
  end
  receiver = args[0]
  case receiver
  when Array, Hash
  when Puppet::Pops::Types::PAbstractType
    receiver = enumerable_Type(receiver)
  else
    raise ArgumentError, ("reduce(): wrong argument type (#{args[0].class}; must be an Array, Hash, or enumerable type.")
  end
  if args.length == 3
    receiver.reduce(args[1]) {|memo, x| pblock.call(self, memo, x) }
  else
    receiver.reduce {|memo, x| pblock.call(self, memo, x) }
  end
end
