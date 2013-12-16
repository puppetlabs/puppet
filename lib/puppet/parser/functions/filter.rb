require 'puppet/parser/ast/lambda'

Puppet::Parser::Functions::newfunction(
:filter,
:type => :rvalue,
:arity => 2,
:doc => <<-'ENDHEREDOC') do |args|
  Applies a parameterized block to each element in a sequence of entries from the first
  argument and returns an array or hash (same type as left operand for array/hash, and array for
  other enumerable types) with the entries for which the block evaluates to true.

  This function takes two mandatory arguments: the first should be an Array, a Hash, or Enumerable Type,
  and the second a parameterized block as produced by the puppet syntax:

        $a.filter |$x| { ... }

  When the first argument is an Array, the block is called with each entry in turn. When the first argument
  is a Hash the entry is an array with `[key, value]`.

  The returned filtered object is of the same type as the receiver.

  *Examples*

        # selects all that end with berry
        $a = ["raspberry", "blueberry", "orange"]
        $a.filter |$x| { $x =~ /berry$/ }

  If the first argument is a Type that is enumerable, the second should be a parameterized block on one
  of the two forms below.

  *Examples*

        Integer[1,10].filter |$x| { ... }
        Integer[1,10].filter |$index, $x| { ... }

  The first form will pass each element from the enumeration to the block, and the second will pass the index
  and value for each element. The index always starts from 0.

  - Since 3.4
  - requires `parser = future`
  ENDHEREDOC

  def filter_Type(o, scope, pblock)
    return nil unless pblock
    tc = Puppet::Pops::Types::TypeCalculator.new()
    enumerable = tc.enumerable(o)
    if enumerable.nil?
      raise ArgumentError, ("filter(): given type '#{tc.string(o)}' is not enumerable")
    end
    serving_size = pblock.parameter_count
    if serving_size == 0
      raise ArgumentError, "Block must define at least one parameter; value."
    end
    if serving_size > 2
      raise ArgumentError, "Block must define at most two parameters; index, value"
    end
    enumerator = enumerable.each
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

  raise ArgumentError, ("reject(): wrong argument type (#{pblock.class}; must be a parameterized block.") unless pblock.respond_to?(:puppet_lambda)

  case receiver
  when Array
    receiver.select {|x| pblock.call(self, x) }
  when Hash
    result = receiver.select {|x, y| pblock.call(self, [x, y]) }
    # Ruby 1.8.7 returns Array
    result = Hash[result] unless result.is_a? Hash
    result
  else
    if receiver.is_a?(Puppet::Pops::Types::PAbstractType)
      filter_Type(receiver, self, pblock)
    else
      raise ArgumentError, ("filter(): wrong argument type (#{receiver.class}; must be an Array or a Hash.")
    end
  end
end
