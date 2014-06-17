Puppet::Parser::Functions::newfunction(
  :with,
  :type => :rvalue,
  :arity => -1,
  :doc => <<-DOC
Call a lambda code block with the given arguments. Since the parameters of the lambda
are local to the lambda's scope, this can be used to create private sections
of logic in a class so that the variables are not visible outside of the
class.

Example:

     # notices the array [1, 2, 'foo']
     with(1, 2, 'foo') |$x, $y, $z| { notice [$x, $y, $z] }

- since 3.7.0
- note requires future parser
DOC
) do |args|
  function_fail(["with() is only available when parser/evaluator future is in effect"])
end
