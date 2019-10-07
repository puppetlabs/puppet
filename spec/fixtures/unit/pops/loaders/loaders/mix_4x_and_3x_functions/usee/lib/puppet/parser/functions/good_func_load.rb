module Puppet::Parser::Functions
  newfunction(:good_func_load, :type => :rvalue, :doc => <<-EOS
    A function using the 3x API
  EOS
  ) do |arguments|
    # This is not illegal
    Float("3.14")
  end
end
