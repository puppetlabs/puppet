Puppet::Parser::Functions::newfunction(
  :slice,
  :type => :rvalue,
  :arity => -3,
  :doc => <<-DOC
This function takes two mandatory arguments: the first should be an array or hash, and the second specifies
the number of elements to include in each slice.

When the first argument is a hash, each key value pair is counted as one. For example, a slice size of 2 will produce
an array of two arrays with key, and value.

    $a.slice(2) |$entry|          { notice "first ${$entry[0]}, second ${$entry[1]}" }
    $a.slice(2) |$first, $second| { notice "first ${first}, second ${second}" }

The function produces a concatenated result of the slices.

    slice([1,2,3,4,5,6], 2) # produces [[1,2], [3,4], [5,6]]
    slice(Integer[1,6], 2)  # produces [[1,2], [3,4], [5,6]]
    slice(4,2)              # produces [[0,1], [2,3]]
    slice('hello',2)        # produces [[h, e], [l, l], [o]]

You can also optionally pass a lambda to slice.

    $a.slice($n) |$x| { ... }
    slice($a) |$x| { ... }

The lambda should have either one parameter (receiving an array with the slice), or the same number
of parameters as specified by the slice size (each parameter receiving its part of the slice).
If there are fewer remaining elements than the slice size for the last slice, it will contain the remaining
elements. If the lambda has multiple parameters, excess parameters are set to undef for an array, or
to empty arrays for a hash.

    $a.slice(2) |$first, $second| { ... }

- Since 4.0.0
DOC
) do |args|
  function_fail(["slice() is only available when parser/evaluator future is in effect"])
end
