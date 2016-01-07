Puppet::Functions.create_function(:'user::caller2') do
  def caller2()
    call_function('usee2::callee', 'passed value') + " + I am user::caller2()"
  end
end
