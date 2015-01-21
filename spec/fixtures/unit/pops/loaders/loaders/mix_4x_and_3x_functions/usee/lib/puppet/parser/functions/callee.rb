module Puppet::Parser::Functions
  newfunction(:callee, :type => :rvalue, :doc => <<-EOS
    A function using the 3x API
  EOS
  ) do |arguments|
    "usee::callee() got '#{arguments[0]}'"
  end
end
