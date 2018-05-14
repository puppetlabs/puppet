# Breaks an innermost iteration as if it encountered an end of input.
# This function does not return to the caller.
#
# The signal produced to stop the iteration bubbles up through
# the call stack until either terminating the innermost iteration or
# raising an error if the end of the call stack is reached.
#
# The break() function does not accept an argument.
#
# @example Using `break`
#
# ```puppet
# $data = [1,2,3]
# notice $data.map |$x| { if $x == 3 { break() } $x*10 }
# ```
#
# Would notice the value `[10, 20]`
#
# @example Using a nested `break`
#
# ```puppet
# function break_if_even($x) {
#   if $x % 2 == 0 { break() }
# }
# $data = [1,2,3]
# notice $data.map |$x| { break_if_even($x); $x*10 }
#```
# Would notice the value `[10]`
#
# * Also see functions `next` and `return`
#
# @since 4.8.0
#
Puppet::Functions.create_function(:break) do
  dispatch :break_impl do
  end

  def break_impl()
    # get file, line if available, else they are set to nil
    file, line = Puppet::Pops::PuppetStack.top_of_stack

    # PuppetStopIteration contains file and line and is a StopIteration exception
    # so it can break a Ruby Kernel#loop or enumeration
    #
    raise Puppet::Pops::Evaluator::PuppetStopIteration.new(file, line)
  end
end
