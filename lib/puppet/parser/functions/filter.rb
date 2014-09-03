Puppet::Parser::Functions::newfunction(
  :filter,
  :arity => -3,
  :doc => <<-DOC
 Applies a parameterized block to each element in a sequence of entries from the first
 argument and returns an array or hash (same type as left operand for array/hash, and array for
 other enumerable types) with the entries for which the block evaluates to `true`.

 This function takes two mandatory arguments: the first should be an Array, a Hash, or an
 Enumerable object (integer, Integer range, or String),
 and the second a parameterized block as produced by the puppet syntax:

       $a.filter |$x| { ... }
       filter($a) |$x| { ... }

 When the first argument is something other than a Hash, the block is called with each entry in turn.
 When the first argument is a Hash the entry is an array with `[key, value]`.

 Example Using filter with one parameter

       # selects all that end with berry
       $a = ["raspberry", "blueberry", "orange"]
       $a.filter |$x| { $x =~ /berry$/ }          # rasberry, blueberry

 If the block defines two parameters, they will be set to `index, value` (with index starting at 0) for all
 enumerables except Hash, and to `key, value` for a Hash.

Example Using filter with two parameters

     # selects all that end with 'berry' at an even numbered index
     $a = ["raspberry", "blueberry", "orange"]
     $a.filter |$index, $x| { $index % 2 == 0 and $x =~ /berry$/ } # raspberry

     # selects all that end with 'berry' and value >= 1
     $a = {"raspberry"=>0, "blueberry"=>1, "orange"=>1}
     $a.filter |$key, $x| { $x =~ /berry$/ and $x >= 1 } # blueberry

- since 3.4 for Array and Hash
- since 3.5 for other enumerables
- note requires `parser = future`
DOC
) do |args|
  function_fail(["filter() is only available when parser/evaluator future is in effect"])
end
