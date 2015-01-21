module Puppet::Parser::Functions
  newfunction(:callee_ws, :type => :rvalue, :doc => <<-EOS
    A function using the 3x API
  EOS
  ) do |arguments|
    "usee::callee_ws() got '#{self['passed_in_scope']}'"
  end
end