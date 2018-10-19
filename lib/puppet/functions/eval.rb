# Evaluates a string containing Puppet Language source.
# The primary intended use case is to combine eval with
# Deferred to enable evaluating arbitrary code on the agent side
# when applying a catalog.
#
# @example Using `eval`
#
# ```puppet
# eval("\$x + \$y", { 'x' => 10, 'y' => 20}) # produces 30
# ```
#
# Note the escaped `$` characters since interpolation is unwanted.
#
# ```puppet
# Deferred('eval' ["$x + $y", { 'x' => 10, 'y' => 20})] # produces 30 on the agent
# ```
#
# This function can be used when there is the need to format or transform deferred
# values since doing that with only deferred values can be difficult to construct
# or impossible to achieve when a lambda is needed.
#
# @example Evaluating logic on agent requiring use of "filter"
#
# ```puppet
# Deferred('eval', "local_lookup('key').filter |\$x| { \$x =~ Integer }")
# ```
#
# To assert the return type - this is simply done by calling `assert_type`
# as part of the string to evaluate.
#
# @example
# ```puppet
# eval("assert_type(Integer, \$x + \$y))", { 'x' => 10, 'y' => 20})
# ```
# @since 6.1.0
#
Puppet::Functions.create_function(:eval, Puppet::Functions::InternalFunction) do
  dispatch :eval_puppet do
    compiler_param
    param 'String', :code
    optional_param 'Hash[String, Any]', :variables
  end

  def eval_puppet(compiler, code, variables = {})
    compiler.in_local_scope(variables) { compiler.evaluate_string(code) }
  end
end
