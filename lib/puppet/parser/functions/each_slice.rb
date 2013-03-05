Puppet::Parser::Functions::newfunction(
  :each_slice,
  :type => :rvalue, 
  :arity => 3, 
  :doc => <<-'ENDHEREDOC') do |args|
  Applies a parameterized block to each slice of elements in a sequence of selected entries from the first
  argument and returns the result returned by the last application.
  
  This function takes three mandatory arguments: the first should be an Array or a Hash, and the second
  the number of elements to include in each slice, and the third
  a parameterized block as produced by the puppet syntax:
  
    $a.each_slice(2) {|$x| ... }
      
  The parameterized lock should have either one parameter (receiving an array with the slice), or the same number
  of parameters as specified by the slice size (each parameter receiving its part of the slice).
  In case there are fewer remaining elements than the slice size for the last slice it will contain the remaining
  elements. When the block has multiple parameters, excess parameters are set to :undef for an array, and to
  empty arrays for a Hash.
    
    $a.each_slice(2) {|$first, $second| ... }
      
  When the first argument is a Hash, each key,value entry is counted as one, e.g, a slice size of 2 will produce
  an array of two arrays with key, value.
  
    $a.each {|$entry|       ..."key ${$entry[0]}, value ${$entry[1]}" } 
    $a.each {|$key, $value| ..."key ${key}, value ${value}" }

  Since 3.2       
  ENDHEREDOC
  require 'puppet/parser/ast/lambda'
  require 'puppet/parser/scope'

  def each_Array(o, slice_size, scope, pblock)
    each_Common(o, slice_size, :undef, scope, pblock)
  end
  
  def each_Common(o, slice_size, filler, scope, pblock)
    return nil unless pblock
    
    serving_size = pblock.parameter_count
    if serving_size == 0
      raise ArgumentError, "Block must define at least one parameter."
    end
    unless serving_size == 1 || serving_size == slice_size  
      raise ArgumentError, "Block must define one parameter, or the same number of parameters as the given size of the slice (#{slice_size})."
    end
    enumerator = o.each_slice(slice_size)
    result = nil
    if serving_size == 1
      ((o.size.to_f / slice_size).ceil).times do
        result = pblock.call(scope, enumerator.next)
      end
    else
      ((o.size.to_f / slice_size).ceil).times do
        a = enumerator.next
        if a.size < serving_size
          a = a.dup.fill(filler, a.length...serving_size)
        end
        result = pblock.call(scope, *a)
      end
    end
    result
  end

  raise ArgumentError, ("each_slice(): wrong number of arguments (#{args.length}; must be 3)") if args.length != 3
  receiver = args[0]
  slice_size = Puppet::Parser::Scope.number?(args[1])
  pblock = args[2]

  raise ArgumentError, ("each_slice(): wrong argument type (#{args[1]}; must be number.") unless slice_size
  raise ArgumentError, ("each_slice(): wrong argument type #{slice_size}; is not an positive integer number") unless slice_size.is_a?(Fixnum) && slice_size > 0
  raise ArgumentError, ("each_slice(): wrong argument type (#{args[2].class}; must be a parameterized block.") unless pblock.is_a? Puppet::Parser::AST::Lambda
  
  case receiver
  when Array
    each_Common(receiver, slice_size, :undef, self, pblock)
  when Hash
    each_Common(receiver, slice_size, [], self, pblock)
  else
    raise ArgumentError, ("each_slice(): wrong argument type (#{args[0].class}; must be an Array or a Hash.")
  end
end