Puppet::Parser::Functions::newfunction(
  :type,
  :type => :rvalue,
  :arity => -1,
  :doc => <<-DOC
Returns the data type of a given value with a given degree of generality.

```puppet
type InferenceFidelity = Enum[generalized, reduced, detailed]

function type(Any $value, InferenceFidelity $fidelity = 'detailed') # returns Type
```

 **Example:** Using `type`

 ``` puppet
 notice type(42) =~ Type[Integer]
 ```

 Would notice `true`.

 By default, the best possible inference is made where all details are retained.
 This is good when the type is used for further type calculations but is overwhelmingly
 rich in information if it is used in a error message.

 The optional argument `$fidelity` may be given as (from lowest to highest fidelity):

 * `generalized` - reduces to common type and drops size constraints
 * `reduced` - reduces to common type in collections
 * `detailed` - (default) all details about inferred types is retained

 **Example:** Using `type()` with different inference fidelity:

 ``` puppet
 notice type([3.14, 42], 'generalized')
 notice type([3.14, 42], 'reduced'')
 notice type([3.14, 42], 'detailed')
 notice type([3.14, 42])
 ```

 Would notice the four values:

 1. 'Array[Numeric]'
 2. 'Array[Numeric, 2, 2]'
 3. 'Tuple[Float[3.14], Integer[42,42]]]'
 4. 'Tuple[Float[3.14], Integer[42,42]]]'

 * Since 4.4.0

DOC
) do |args|
  function_fail(["type() is only available when parser/evaluator future is in effect"])
end
