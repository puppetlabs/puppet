module Puppet::Parser::Functions
  newfunction(:bad_func_load, :type => :rvalue, :doc => <<-EOS
    A function using the 3x API
  EOS
  ) do |arguments|
    "the returned value"
  end

  def method_here_is_illegal()
  end
end
