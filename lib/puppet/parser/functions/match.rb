Puppet::Parser::Functions::newfunction(
  :match,
  :arity => 2,
  :doc => <<-DOC
Returns the match result of matching a String or Array[String] with one of:

* Regexp
* String - transformed to a Regexp
* Pattern type
* Regexp type

Returns An Array with the entire match at index 0, and each subsequent submatch at index 1-n.
If there was no match `undef` is returned. If the value to match is an Array, a array
with mapped match results is returned.

Example matching:

  "abc123".match(/([a-z]+)[1-9]+/)    # => ["abc"]
  "abc123".match(/([a-z]+)([1-9]+)/)  # => ["abc", "123"]

See the documentation for "The Puppet Type System" for more information about types.

- since 3.7.0
- note requires future parser
DOC
) do |args|
  function_fail(["match() is only available when parser/evaluator future is in effect"])
end
