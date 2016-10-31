# Make iteration break as if there were no more values to process
#
# @since 4.7.0
#
Puppet::Functions.create_function(:break) do
  dispatch :break_impl do
  end

  def break_impl()
    stacktrace = Puppet::Pops::PuppetStack.stacktrace()
    if stacktrace.size > 0
      file, line = stacktrace[0]
    else
      file = nil
      line = nil
    end
    # PuppetStopIteration contains file and line and is a StopIteration exception
    # so it can break a Ruby Kernel#loop or enumeration
    #
    raise Puppet::Pops::Evaluator::PuppetStopIteration.new(file, line)
  end
end
