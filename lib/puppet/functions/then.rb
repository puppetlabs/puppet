# (Documented in 3.x stub)
# @since 4.5.0
#
Puppet::Functions.create_function(:then) do
  dispatch :then do
    param 'Any', :arg
    block_param 'Callable[1,1]', :block
  end

  def then(arg)
    return nil if arg.nil?
    yield(arg)
  end
end
