x = module Puppet::Parser::Functions
  newfunction(:bad_func_load5, :type => :rvalue, :doc => <<-EOS
    A function using the 3x API
  EOS
  ) do |arguments|
    "some return value"
  end
end
def self.bad_func_load5_illegal_method
end
# Attempt to get around problem of not returning what newfunction returns
x
