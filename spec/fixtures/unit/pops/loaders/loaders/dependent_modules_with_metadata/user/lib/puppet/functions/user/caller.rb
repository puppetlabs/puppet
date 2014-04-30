Puppet::Functions.create_function(:'user::caller') do
  def caller()
    call_function('usee::callee', 'passed value') + " + I am user::caller()"
  end
end
