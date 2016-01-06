Puppet::Functions.create_function(:'user::ruby_calling_puppet_init') do
  def ruby_calling_puppet_init()
     call_function('usee_puppet_init')
  end
end
