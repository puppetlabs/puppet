require 'puppet/parser/ast/lambda'

Puppet::Parser::Functions::newfunction(
:filter,
:type => :rvalue,
:arity => 2,
:doc => <<-'ENDHEREDOC') do |args|
  Applies a parameterized block to each element in a sequence of entries from the first
  argument and returns an array or hash (same type as left operand)
  with the entries for which the block evaluates to true.

  This function takes two mandatory arguments: the first should be an Array or a Hash, and the second
  a parameterized block as produced by the puppet syntax:

        $a.filter |$x| { ... }

  When the first argument is an Array, the block is called with each entry in turn. When the first argument
  is a Hash the entry is an array with `[key, value]`.

  The returned filtered object is of the same type as the receiver.

  *Examples*

        # selects all that end with berry
        $a = ["raspberry", "blueberry", "orange"]
        $a.filter |$x| { $x =~ /berry$/ }

  - Since 3.4
  - requires `parser = future`.
  ENDHEREDOC

  receiver = args[0]
  pblock = args[1]

  raise ArgumentError, ("filter(): wrong argument type (#{pblock.class}; must be a parameterized block.") unless pblock.is_a? Puppet::Parser::AST::Lambda

  case receiver
  when Array
    receiver.select {|x| pblock.call(self, x) }
  when Hash
    result = receiver.select {|x, y| pblock.call(self, [x, y]) }
    # Ruby 1.8.7 returns Array
    result = Hash[result] unless result.is_a? Hash
    result
  else
    raise ArgumentError, ("filter(): wrong argument type (#{receiver.class}; must be an Array or a Hash.")
  end
end
