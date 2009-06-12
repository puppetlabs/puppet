module Puppet::Parser::Functions
    newfunction(:split, :type => :rvalue,
      :doc => "\
Split a string variable into an array using the specified split regexp.

  Usage::

    $string     = 'v1.v2:v3.v4'
    $array_var1 = split($string, ':')
    $array_var2 = split($string, '[.]')
    $array_var3 = split($string, '[.:]')

$array_var1 now holds the result ['v1.v2', 'v3.v4'],
while $array_var2 holds ['v1', 'v2:v3', 'v4'], and
$array_var3 holds ['v1', 'v2', 'v3', 'v4'].

Note that in the second example, we split on a string that contains
a regexp meta-character (.), and that needs protection.  A simple
way to do that for a single character is to enclose it in square
brackets.") do |args|

     if args.length != 2
         raise Puppet::ParseError, ("split(): wrong number of arguments" +
				   " (#{args.length}; must be 2)")
     end

     return args[0].split(Regexp.compile(args[1]))
    end
end
