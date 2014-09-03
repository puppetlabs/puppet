Puppet::Parser::Functions::newfunction(
  :map,
  :type => :rvalue,
  :arity => -3,
  :doc => <<-DOC
Applies a parameterized block to each element in a sequence of entries from the first
argument and returns an array with the result of each invocation of the parameterized block.

This function takes two mandatory arguments: the first should be an Array, Hash, or of Enumerable type
(integer, Integer range, or String), and the second a parameterized block as produced by the puppet syntax:

      $a.map |$x| { ... }
      map($a) |$x| { ... }

When the first argument `$a` is an Array or of enumerable type, the block is called with each entry in turn.
When the first argument is a hash the entry is an array with `[key, value]`.

Example Using map with two arguments

     # Turns hash into array of values
     $a.map |$x|{ $x[1] }

     # Turns hash into array of keys
     $a.map |$x| { $x[0] }

When using a block with 2 parameters, the element's index (starting from 0) for an array, and the key for a hash
is given to the block's first parameter, and the value is given to the block's second parameter.args.

Example Using map with two arguments

     # Turns hash into array of values
     $a.map |$key,$val|{ $val }

     # Turns hash into array of keys
     $a.map |$key,$val|{ $key }

- since 3.4 for Array and Hash
- since 3.5 for other enumerables, and support for blocks with 2 parameters
- note requires `parser = future`
DOC
) do |args|
  function_fail(["map() is only available when parser/evaluator future is in effect"])
end
