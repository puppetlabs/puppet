Puppet::Functions.create_function(:'user::caller') do
  def caller()
    call_function('callee', 'passed first') + " + I am user::caller()"
    call_function('callee', 'passed value') + " + I am user::caller()"
  end
end
