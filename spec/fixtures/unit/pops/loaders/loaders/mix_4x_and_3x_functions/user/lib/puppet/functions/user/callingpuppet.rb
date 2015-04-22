Puppet::Functions.create_function(:'user::callingpuppet') do
  def callingpuppet()
    call_function('user::puppetcalled', 'me')
  end
end
