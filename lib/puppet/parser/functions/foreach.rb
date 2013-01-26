Puppet::Parser::Functions::newfunction(
  :foreach,
  :type => :rvalue, 
  :arity => 2, 
  :doc => <<-'ENDHEREDOC') do |args|
  Applies a parameterized block to each element in a sequence of selected entries from the first
  argument and returns the result returned by the last application.
  
  This function takes two mandatory arguments: the first should be an Array or a Hash, and the second
  a parameterized block as produced by the puppet syntax:
  
    $a.foreach {|$x| ... }
      
  When the first argument is an Array, the parameterized block should define one or more block parameters.
  For each application of the block, a corresponding number of elements from the array are selected. Thus,
  to iterate over an array of pairs, (or triplets) do like this:
  
    $a.foreach {|$x, $y| ... }
    $a.foreach {|$x, $y, $z| ... }
      
  When the first argument is a Hash, the parameterized block should define one or two parameters.
  When one parameter is defined, the iteration is performed with each key, and when two parameters are
  defined the iteration is performed with key and value.
  
    $a.foreach {|$key| ...args } 
    $a.foreach {|$key, $value| ...args }

  Since 3.2       
  ENDHEREDOC
  require 'puppet/parser/ast/lambda'

  def foreach_Array(o, scope, pblock)
    return nil unless pblock
    
    serving_size = pblock.parameter_count
    if serving_size == 0
      raise ArgumentError, "Block must define at least one parameter."
    end
    unless o.size % serving_size == 0 
      raise ArgumentError, "Array size #{o.size} is not an even multiple of the block's parameter count #{serving_size}."
    end
    enumerator = o.each_slice(serving_size)
    result = nil
    (o.size/serving_size).times do
      result = pblock.call(scope, *enumerator.next)
    end
    result
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
    enumerator = serving_size == 1 ? o.each_key : o.each_pair
    result = nil
    (o.size).times do
      result = pblock.call(scope, *enumerator.next)
    end
    result
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