# (Documented in 3.x stub)
# @since 4.5.0
#
Puppet::Functions.create_function(:lest) do
  dispatch :lest do
    param 'Any', :arg
    block_param 'Callable[0,0]', :block
  end

  def lest(arg)
    if arg.nil?
      yield()
    else
      arg
    end
  end
end
