# Makes iteration continue with the next value, optionally with a given value for this iteration.
# If a value is not given it defaults to `undef`
#
# @since 4.7.0
#
Puppet::Functions.create_function(:return, Puppet::Functions::InternalFunction) do
  dispatch :return_impl do
    optional_param 'Any', :value
  end

  def return_impl(value = nil)
    stacktrace = Puppet::Pops::PuppetStack.stacktrace()
    if stacktrace.size > 0
      file, line = stacktrace[0]
    else
      file = nil
      line = nil
    end

    raise Puppet::Pops::Evaluator::Return.new(value, file, line)
  end
end
