module Puppet::Parser::Functions

  newfunction(
  :split, :type => :rvalue,
  :arity => 2,

    :doc => "\
Split a string variable into an array using the specified split regexp.

*Example:*

    $string     = 'v1.v2:v3.v4'
    $array_var1 = split($string, ':')
    $array_var2 = split($string, '[.]')
    $array_var3 = split($string, Regexp['[.:]'])

`$array_var1` now holds the result `['v1.v2', 'v3.v4']`,
while `$array_var2` holds `['v1', 'v2:v3', 'v4']`, and
`$array_var3` holds `['v1', 'v2', 'v3', 'v4']`.

Note that in the second example, we split on a literal string that contains
a regexp meta-character (.), which must be escaped.  A simple
way to do that for a single character is to enclose it in square
brackets; a backslash will also escape a single character.") do |args|

    Error.is4x('split')
  end
end
