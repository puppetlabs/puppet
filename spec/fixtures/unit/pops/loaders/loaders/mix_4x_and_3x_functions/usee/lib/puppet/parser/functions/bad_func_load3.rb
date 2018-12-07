module Puppet::Parser::Functions
  newfunction(:bad_func_load3, :type => :rvalue, :doc => <<-EOS
    A function using the 3x API
  EOS
  ) do |arguments|
    def bad_func_load3_illegal_method
      "some return value from illegal method"
    end
    "some return value"
  end
end
