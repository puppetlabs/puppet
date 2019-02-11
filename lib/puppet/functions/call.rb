# Calls an arbitrary Puppet function by name.
#
# This function takes one mandatory argument and one or more optional arguments:
#
# 1. A string corresponding to a function name.
# 2. Any number of arguments to be passed to the called function.
# 3. An optional lambda, if the function being called supports it.
#
# @example Using the `call` function
#
# ```puppet
# $a = 'notice'
# call($a, 'message')
# ```
#
# @example Using the `call` function with a lambda
#
# ```puppet
# $a = 'each'
# $b = [1,2,3]
# call($a, $b) |$item| {
#  notify { $item: }
# }
# ```
#
# The `call` function can be used to call either Ruby functions or Puppet language
# functions.
#
# @since 5.0.0
#
Puppet::Functions.create_function(:call, Puppet::Functions::InternalFunction) do
  dispatch :call_impl_block do
    scope_param
    param 'String', :function_name
    repeated_param 'Any', :arguments
    optional_block_param
  end

  def call_impl_block(scope, function_name, *args, &block)
    # The call function must be able to call functions loaded by any loader visible from the calling scope.
    Puppet::Pops::Parser::EvaluatingParser.new.evaluator.external_call_function(function_name, args, scope, &block)
  end
end
