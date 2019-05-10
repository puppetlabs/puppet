module Puppet::Parser::Functions
  newfunction(:func_with_syntax_error, :type => :rvalue, :doc => <<-EOS
    A function using the 3x API having a syntax error
  EOS
  ) do |arguments|
    # this syntax error is here on purpose!
    1+ + + +
  end
end
