require 'puppet/parser/ast/lambda'

Puppet::Parser::Functions::newfunction(
:collect,
:type => :rvalue,
:arity => 2,
:doc => <<-'ENDHEREDOC') do |args|
  Applies a parameterized block to each element in a sequence of entries from the first
  argument and returns an array with the result of each invocation of the parameterized block.

  This function takes two mandatory arguments: the first should be an Array or a Hash, and the second
  a parameterized block as produced by the puppet syntax:

        $a.collect |$x| { ... }

  When the first argument `$a` is an Array, the block is called with each entry in turn. When the first argument
  is a hash the entry is an array with `[key, value]`.

  *Examples*

        # Turns hash into array of values
        $a.collect |$x|{ $x[1] }

        # Turns hash into array of keys
        $a.collect |$x| { $x[0] }

  - Since 3.2
  - requires `parser = future`.
  ENDHEREDOC

  receiver = args[0]
  pblock = args[1]

  raise ArgumentError, ("collect(): wrong argument type (#{pblock.class}; must be a parameterized block.") unless pblock.is_a? Puppet::Parser::AST::Lambda

  case receiver
  when Array
  when Hash
  else
    raise ArgumentError, ("collect(): wrong argument type (#{receiver.class}; must be an Array or a Hash.")
  end

  receiver.to_a.collect {|x| pblock.call(self, x) }
end
