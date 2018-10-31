module Puppet::Parser::Functions
  newfunction(:bad_func_load4, :type => :rvalue, :doc => <<-EOS
    A function using the 3x API
  EOS
  ) do |arguments|
    def self.bad_func_load4_illegal_method
      "some return value from illegal method"
    end
    "some return value"
  end
end
