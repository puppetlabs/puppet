Puppet::Parser::Functions::newfunction(
  :match,
  :arity => 2,
  :doc => <<-DOC
Matches a regular expression against a string and returns an array containing the match
and any matched capturing groups.

The first argument is a string or array of strings. The second argument is either a
regular expression, regular expression represented as a string, or Regex or Pattern
data type that the function matches against the first argument.

The returned array contains the entire match at index 0, and each captured group at
subsequent index values. If the value or expression being matched is an array, the
function returns an array with mapped match results.

If the function doesn't find a match, it returns 'undef'.

**Example**: Matching a regular expression in a string

~~~ ruby
$matches = "abc123".match(/[a-z]+[1-9]+/)
# $matches contains [abc123]
~~~

**Example**: Matching a regular expressions with grouping captures in a string

~~~ ruby
$matches = "abc123".match(/([a-z]+)([1-9]+)/)
# $matches contains [abc123, abc, 123]
~~~

**Example**: Matching a regular expression with grouping captures in an array of strings

~~~ ruby
$matches = ["abc123","def456"].match(/([a-z]+)([1-9]+)/)
# $matches contains [[abc123, abc, 123], [def456, def, 456]]
~~~

- Since 4.0.0
DOC
) do |args|
  Puppet::Parser::Functions::Error.is4x('match')
end
