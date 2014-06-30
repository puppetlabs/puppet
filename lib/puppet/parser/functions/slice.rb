Puppet::Parser::Functions::newfunction(
  :slice,
  :type => :rvalue,
  :arity => -3,
  :doc => <<-DOC
Applies a parameterized block to each _slice_ of elements in a sequence of selected entries from the first
argument and returns the first argument, or if no block is given returns a new array with a concatenation of
the slices.

This function takes two mandatory arguments: the first, `$a`, should be an Array, Hash, or something of
enumerable type (integer, Integer range, or String), and the second, `$n`, the number of elements to include
in each slice. The optional third argument should be a a parameterized block as produced by the puppet syntax:

    $a.slice($n) |$x| { ... }
    slice($a) |$x| { ... }

The parameterized block should have either one parameter (receiving an array with the slice), or the same number
of parameters as specified by the slice size (each parameter receiving its part of the slice).
In case there are fewer remaining elements than the slice size for the last slice it will contain the remaining
elements. When the block has multiple parameters, excess parameters are set to undef for an array or
enumerable type, and to empty arrays for a Hash.

    $a.slice(2) |$first, $second| { ... }

When the first argument is a Hash, each `key,value` entry is counted as one, e.g, a slice size of 2 will produce
an array of two arrays with key, and value.

Example Using slice with Hash

    $a.slice(2) |$entry|          { notice "first ${$entry[0]}, second ${$entry[1]}" }
    $a.slice(2) |$first, $second| { notice "first ${first}, second ${second}" }

When called without a block, the function produces a concatenated result of the slices.

Example Using slice without a block

    slice([1,2,3,4,5,6], 2) # produces [[1,2], [3,4], [5,6]]
    slice(Integer[1,6], 2)  # produces [[1,2], [3,4], [5,6]]
    slice(4,2)              # produces [[0,1], [2,3]]
    slice('hello',2)        # produces [[h, e], [l, l], [o]]

- since 3.2 for Array and Hash
- since 3.5 for additional enumerable types
- note requires `parser = future`.
DOC
) do |args|
  function_fail(["slice() is only available when parser/evaluator future is in effect"])
end
