require 'puppet/parser/ast/lambda'

Puppet::Parser::Functions::newfunction(
:filter,
:type => :rvalue,
:arity => 2,
:doc => <<-'ENDHEREDOC') do |args|
  Applies a parameterized block to each element in a sequence of entries from the first
  argument and returns an array or hash (same type as left operand for array/hash, and array for
  other enumerable types) with the entries for which the block evaluates to `true`.

  This function takes two mandatory arguments: the first should be an Array, a Hash, or an
  Enumerable object (integer, Integer range, or String),
  and the second a parameterized block as produced by the puppet syntax:

        $a.filter |$x| { ... }
        filter($a) |$x| { ... }

  When the first argument is something other than a Hash, the block is called with each entry in turn.
  When the first argument is a Hash the entry is an array with `[key, value]`.

  *Examples*

        # selects all that end with berry
        $a = ["raspberry", "blueberry", "orange"]
        $a.filter |$x| { $x =~ /berry$/ }          # rasberry, blueberry

  If the block defines two parameters, they will be set to `index, value` (with index starting at 0) for all
  enumerables except Hash, and to `key, value` for a Hash.

  *Examples*

        # selects all that end with 'berry' at an even numbered index
        $a = ["raspberry", "blueberry", "orange"]
        $a.filter |$index, $x| { $index % 2 == 0 and $x =~ /berry$/ } # raspberry

        # selects all that end with 'berry' and value >= 1
        $a = {"raspberry"=>0, "blueberry"=>1, "orange"=>1}
        $a.filter |$key, $x| { $x =~ /berry$/ and $x >= 1 } # blueberry

  - Since 3.4 for Array and Hash
  - Since 3.5 for other enumerables
  - requires `parser = future`
  ENDHEREDOC

  def filter_Enumerator(enumerator, scope, pblock, serving_size)
    result = []
    index = 0
    if serving_size == 1
      begin
        loop { pblock.call(scope, it = enumerator.next) == true ? result << it : nil }
      rescue StopIteration
      end
    else
      begin
        loop do
          pblock.call(scope, index, it = enumerator.next) == true ? result << it : nil
          index = index +1
        end
      rescue StopIteration
      end
    end
    result
  end

  receiver = args[0]
  pblock = args[1]

  raise ArgumentError, ("filter(): wrong argument type (#{pblock.class}; must be a parameterized block.") unless pblock.respond_to?(:puppet_lambda)
  serving_size = pblock.parameter_count
  if serving_size == 0
    raise ArgumentError, "filter(): block must define at least one parameter; value. Block has 0."
  end

  case receiver
  when Hash
    if serving_size > 2
      raise ArgumentError, "filter(): block must define at most two parameters; key, value. Block has #{serving_size}; "+
      pblock.parameter_names.join(', ')
    end
    if serving_size == 1
      result = receiver.select {|x, y| pblock.call(self, [x, y]) }
    else
      result = receiver.select {|x, y| pblock.call(self, x, y) }
    end
    # Ruby 1.8.7 returns Array
    result = Hash[result] unless result.is_a? Hash
    result
  else
    if serving_size > 2
      raise ArgumentError, "filter(): block must define at most two parameters; index, value. Block has #{serving_size}; "+
      pblock.parameter_names.join(', ')
    end
    enum = Puppet::Pops::Types::Enumeration.enumerator(receiver)
    unless enum
      raise ArgumentError, ("filter(): wrong argument type (#{receiver.class}; must be something enumerable.")
    end
    filter_Enumerator(enum, self, pblock, serving_size)
  end
end
