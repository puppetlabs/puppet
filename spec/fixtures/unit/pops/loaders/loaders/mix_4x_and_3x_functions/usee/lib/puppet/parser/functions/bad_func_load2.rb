module Puppet::Parser::Functions
  x = newfunction(:bad_func_load2, :type => :rvalue, :doc => <<-EOS
    A function using the 3x API
  EOS
  ) do |arguments|
    "some return value"
  end
end
def illegal_method_here
end
x
