Puppet::Parser::Functions::newfunction(:call, :type => :rvalue, :doc => <<-EOS
Call other parser functions with given array as arguments. The first argument
is the function name and must be a string. The second is the arguments to pass 
to the function as an array. 

Example:

define ... (
  $a = undef,
  $b = []
){
  $first_not_undef = call('pick', flatten([ $a, $b ])
}
EOS
) do |args|
  name = args[0]
  arguments = args[1]

  unless name.kind_of?(String)
    raise Puppet::ParseError, "First argument must be the function name in form of a string. Given: #{name.inspect} (#{name.class})"
  end

  unless args.kind_of?(Array)
    raise Puppet::ParseError, "Second argument must be an array of arguments to pass to the function. Given: #{arguments.inspect} (#{arguments.class})"
  end


  send :"function_#{name}", arguments
end
