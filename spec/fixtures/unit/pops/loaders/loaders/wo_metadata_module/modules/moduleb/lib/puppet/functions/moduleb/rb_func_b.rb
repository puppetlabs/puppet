Puppet::Functions.create_function(:'moduleb::rb_func_b') do
  def rb_func_b()
    # Should be able to call modulea::rb_func_a()
    call_function('modulea::rb_func_a') + " + I am moduleb::rb_func_b()"
  end
end