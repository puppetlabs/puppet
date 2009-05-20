module Puppet::Parser::Functions
  newfunction(:split, :type => :rvalue, 
      :doc => "Split a string variable into an array using the specified split character.

Usage::

    $string    = 'value1,value2'
    $array_var = split($string, ',')

$array_var holds the result ['value1', 'value2']") do |args|
    return args[0].split(args[1])
  end
end
