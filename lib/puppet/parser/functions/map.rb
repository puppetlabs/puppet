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

  - Since 3.4 for Array and Hash
  - Since 3.5 for other enumerables
  - requires `parser = future`
  ENDHEREDOC

  receiver = args[0]
  pblock = args[1]

  raise ArgumentError, ("map(): wrong argument type (#{pblock.class}; must be a parameterized block.") unless pblock.respond_to?(:puppet_lambda)

  enum = Puppet::Pops::Types::Enumeration.enumerator(receiver)
  unless enum
    raise ArgumentError, ("map(): wrong argument type (#{receiver.class}; must be something enumerable.")
  end
  enum.map {|x| pblock.call(self, x) }
end
