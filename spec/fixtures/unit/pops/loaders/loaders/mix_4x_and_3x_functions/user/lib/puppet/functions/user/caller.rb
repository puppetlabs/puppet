Puppet::Functions.create_function(:'user::caller') do
  def caller()
    call_function('callee', 'first') + ' - ' + call_function('callee', 'second')
  end
end
