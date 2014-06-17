Puppet::Parser::Functions::newfunction(
  :reduce,
  :type => :rvalue,
  :arity => -3,
  :doc => <<-DOC
Applies a parameterized block to each element in a sequence of entries from the first
argument (_the enumerable_) and returns the last result of the invocation of the parameterized block.

This function takes two mandatory arguments: the first should be an Array, Hash, or something of
enumerable type, and the last a parameterized block as produced by the puppet syntax:

      $a.reduce |$memo, $x| { ... }
      reduce($a) |$memo, $x| { ... }

When the first argument is an Array or someting of an enumerable type, the block is called with each entry in turn.
When the first argument is a hash each entry is converted to an array with `[key, value]` before being
fed to the block. An optional 'start memo' value may be supplied as an argument between the array/hash
and mandatory block.

      $a.reduce(start) |$memo, $x| { ... }
      reduce($a, start) |$memo, $x| { ... }

If no 'start memo' is given, the first invocation of the parameterized block will be given the first and second
elements of the enumeration, and if the enumerable has fewer than 2 elements, the first
element is produced as the result of the reduction without invocation of the block.

On each subsequent invocation, the produced value of the invoked parameterized block is given as the memo in the
next invocation.

Example Using reduce

      # Reduce an array
      $a = [1,2,3]
      $a.reduce |$memo, $entry| { $memo + $entry }
      #=> 6

      # Reduce hash values
      $a = {a => 1, b => 2, c => 3}
      $a.reduce |$memo, $entry| { [sum, $memo[1]+$entry[1]] }
      #=> [sum, 6]

      # reverse a string
      "abc".reduce |$memo, $char| { "$char$memo" }
      #=>"cbe"

It is possible to provide a starting 'memo' as an argument.

Example Using reduce with given start 'memo'

      # Reduce an array
      $a = [1,2,3]
      $a.reduce(4) |$memo, $entry| { $memo + $entry }
      #=> 10

      # Reduce hash values
      $a = {a => 1, b => 2, c => 3}
      $a.reduce([na, 4]) |$memo, $entry| { [sum, $memo[1]+$entry[1]] }
      #=> [sum, 10]

Example Using reduce with an Integer range

      Integer[1,4].reduce |$memo, $x| { $memo + $x }
      #=> 10

- since 3.2 for Array and Hash
- since 3.5 for additional enumerable types
- note requires `parser = future`.
DOC
) do |args|
  function_fail(["reduce() is only available when parser/evaluator future is in effect"])
end
