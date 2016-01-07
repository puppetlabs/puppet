Puppet::Functions.create_function(:'user::ruby_calling_puppet') do
  def ruby_calling_puppet()
     call_function('usee::usee_puppet')
  end
end
