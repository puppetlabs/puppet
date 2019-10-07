# Calls an arbitrary Puppet function by name.
#
# This function takes one mandatory argument and one or more optional arguments:
#
# 1. A string corresponding to a function name.
# 2. Any number of arguments to be passed to the called function.
# 3. An optional lambda, if the function being called supports it.
#
# This function can also be used to resolve a `Deferred` given as
# the only argument to the function (does not accept arguments nor
# a block).
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
# When used with `Deferred` values, the deferred value can either describe
# a function call, or a dig into a variable.
#
# @example Resolving a deferred function call
#
# ```puppet
# $d = Deferred('join', [[1,2,3], ':']) # A future call to join that joins the arguments 1,2,3 with ':'
# notice($d.call())
# ```
#
# Would notice the string "1:2:3".
#
# @example Resolving a deferred variable value with optional dig into its structure
#
# ```puppet
# $d = Deferred('$facts', ['processors', 'count'])
# notice($d.call())
# ```
#
# Would notice the value of `$facts['processors']['count']` at the time when the `call` is made.
#
# * Deferred values supported since Puppet 5.6.0
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

  dispatch :call_deferred do
    scope_param
    param 'Deferred', :deferred
  end

  def call_impl_block(scope, function_name, *args, &block)
    # The call function must be able to call functions loaded by any loader visible from the calling scope.
    Puppet::Pops::Parser::EvaluatingParser.new.evaluator.external_call_function(function_name, args, scope, &block)
  end

  def call_deferred(scope, deferred)
    Puppet::Pops::Evaluator::DeferredResolver.resolve(deferred, scope.compiler)
  end

end
