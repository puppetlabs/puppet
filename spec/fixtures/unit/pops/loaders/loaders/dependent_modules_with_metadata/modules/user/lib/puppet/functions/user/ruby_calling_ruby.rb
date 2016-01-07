Puppet::Functions.create_function(:'user::ruby_calling_ruby') do
  def ruby_calling_ruby()
    call_function('usee::usee_ruby')
  end
end
