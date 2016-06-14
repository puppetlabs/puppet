Puppet::Parser::Functions::newfunction(
  :new,
  :type => :rvalue,
  :arity => -1,
  :doc => <<-DOC
Creates a new instance/object of a given data type.

This function makes it possible to create new instances of
concrete data types. If a block is given it is called with the
just created instance as an argument.

Calling this function is equivalent to directly
calling the data type:

**Example:** `new` and calling type directly are equivalent

```puppet
$a = Integer.new("42")
$b = Integer("42")
```

These would both convert the string `"42"` to the decimal value `42`.

**Example:** arguments by position or by name

```puppet
$a = Integer.new("42", 8)
$b = Integer({from => "42", radix => 8})
```

This would convert the octal (radix 8) number `"42"` in string form
to the decimal value `34`.

The new function supports two ways of giving the arguments:

* by name (using a hash with property to value mapping)
* by position (as regular arguments)

Note that it is not possible to create new instances of
some abstract data types (for example `Variant`). The data type `Optional[T]` is an
exception as it will create an instance of `T` or `undef` if the
value to convert is `undef`.

The arguments that can be given is determined by the data type.

> An assertion is always made that the produced value complies with the given type constraints.

**Example:** data type constraints are checked

```puppet
Integer[0].new("-100")
```

Would fail with an assertion error (since value is less than 0).

The following sections show the arguments and conversion rules
per data type built into the Puppet Type System.

Conversion to Optional[T] and NotUndef[T]
-----------------------------------------

Conversion to these data types is the same as a conversion to the type argument `T`.
In the case of `Optional[T]` it is accepted that the argument to convert may be `undef`.
It is however not acceptable to give other arguments (than `undef`) that cannot be
converted to `T`.

Conversion to Integer
---------------------

A new `Integer` can be created from `Integer`, `Float`, `Boolean`, and `String` values.
For conversion from `String` it is possible to specify the radix (base).

```puppet
type Radix = Variant[Default, Integer[2,2], Integer[8,8], Integer[10,10], Integer[16,16]]

function Integer.new(
  String $value,
  Radix $radix = 10
)

function Integer.new(
  Variant[Numeric, Boolean] $value
)
```

* When converting from `String` the default radix is 10.
* If radix is not specified an attempt is made to detect the radix from the start of the string:
  * `0b` or `0B` is taken as radix 2.
  * `0x` or `0X` is taken as radix 16.
  * `0` as radix 8.
  * All others are decimal.
* Conversion from `String` accepts an optional sign in the string.
* For hexadecimal (radix 16) conversion an optional leading "0x", or "0X" is accepted.
* For octal (radix 8) an optional leading "0" is accepted.
* For binary (radix 2) an optional leading "0b" or "0B" is accepted.
* When `radix` is set to `default`, the conversion is based on the leading.
  characters in the string. A leading "0" for radix 8, a leading "0x", or "0X" for
  radix 16, and leading "0b" or "0B" for binary.
* Conversion from `Boolean` results in 0 for `false` and 1 for `true`.
* Conversion from `Integer`, `Float`, and `Boolean` ignores the radix.
* `Float` value fractions are truncated (no rounding).

Examples - Converting to Integer:

```puppet
$a_number = Integer("0xFF", 16)  # results in 255
$a_number = Numeric("010")       # results in 8
$a_number = Numeric("010", 10)   # results in 10
$a_number = Integer(true)        # results in 1
```

Conversion to Float
-------------------

A new `Float` can be created from `Integer`, `Float`, `Boolean`, and `String` values.
For conversion from `String` both float and integer formats are supported.

```puppet
function Float.new(
  Variant[Numeric, Boolean, String] $value
)
```


* For an integer, the floating point fraction of `.0` is added to the value.
* A `Boolean` `true` is converted to 1.0, and a `false` to 0.0
* In `String` format, integer prefixes for hex and binary are understood (but not octal since
  floating point in string format may start with a '0'). 

Conversion to Numeric
---------------------

A new `Integer` or `Float` can be created from `Integer`, `Float`, `Boolean` and
`String` values.

```puppet
function Numeric.new(
  Variant[Numeric, Boolean, String] $value
)
```

* If the value has a decimal period, or if given in scientific notation
  (e/E), the result is a `Float`, otherwise the value is an `Integer`. The
  conversion from `String` always uses a radix based on the prefix of the string.
* Conversion from `Boolean` results in 0 for `false` and 1 for `true`.

Examples - Converting to Numeric

```puppet
$a_number = Numeric(true)    # results in 1
$a_number = Numeric("0xFF")  # results in 255
$a_number = Numeric("010")   # results in 8
$a_number = Numeric("3.14")  # results in 3.14 (a float)
```

Conversion to String
--------------------

Conversion to `String` is the most comprehensive conversion as there are many
use cases where a string representation is wanted. The defaults for the many options
have been chosen with care to be the most basic "value in textual form" representation.
The more advanced forms of formatting are intended to enable writing special purposes formatting
functions in the Puppet language.

A new string can be created from all other data types. The process is performed in
several steps - first the data type of the given value is inferred, then the resulting data type
is used to find the most significant format specified for that data type. And finally,
the found format is used to convert the given value.

The mapping from data type to format is referred to as the *format map*. This map
allows different formatting depending on type.

**Example:** Positive Integers in Hexadecimal prefixed with '0x', negative in Decimal

```puppet
$format_map = {
  Integer[default, 0] => "%d",
  Integer[1, default] => "%#x"
}
String("-1", $format_map)  # produces '-1'
String("10", $format_map)  # produces '0xa'
```

A format is specified on the form:

```
%[Flags][Width][.Precision]Format
```

`Width` is the number of characters into which the value should be fitted. This allocated space is
padded if value is shorter. By default it is space padded, and the flag `0` will cause padding with `0`
for numerical formats.

`Precision` is the number of fractional digits to show for floating point, and the maximum characters
included in a string format.

Note that all data type supports the formats `s` and `p` with the meaning "default string representation" and
"default programmatic string representation" (which for example means that a String is quoted in 'p' format).

### Signatures of String conversion

```puppet
type Format = Pattern[/^%([\s\+\-#0\[\{<\(\|]*)([1-9][0-9]*)?(?:\.([0-9]+))?([a-zA-Z])/]
type ContainerFormat = Struct[{
  format         => Optional[String],
  separator      => Optional[String],
  separator2     => Optional[String],
  string_formats => Hash[Type, Format]
  }]
type TypeMap = Hash[Type, Variant[Format, ContainerFormat]]
type Formats = Variant[Default, String[1], TypeMap]

function String.new(
  Any $value,
  Formats $string_formats
)
```

Where:

* `separator` is the string used to separate entries in an array, or hash (extra space should not be included at
  the end), defaults to `","`
* `separator2` is the separator between key and value in a hash entry (space padding should be included as
  wanted), defaults to `" => "`.
* `string_formats` is a data type to format map for values contained in arrays and hashes - defaults to `{Any => "%p"}`. Note that
  these nested formats are not applicable to data types that are containers; they are always formatted as per the top level
  format specification.

**Example:** Simple Conversion to String (using defaults)

```puppet
$str = String(10)      # produces '10'
$str = String([10])    # produces '["10"]'
```

**Example:** Simple Conversion to String specifying the format for the given value directly

```puppet
$str = String(10, "%#x")    # produces '0x10'
$str = String([10], "%(a")  # produces '("10")'
```

**Example:** Specifying type for values contained in an array

```puppet
$formats = { 
  Array => {
    format => '%(a',
    string_formats => { Integer => '%#x' }
  }
}
$str = String([1,2,3], $formats) # produces '(0x1, 0x2, 0x3)'
```

The given formats are merged with the default formats, and matching of values to convert against format is based on
the specificity of the mapped type; for example, different formats can be used for short and long arrays.

### Integer to String

| Format  | Integer Formats
| ------  | ---------------
| d       | Decimal, negative values produces leading '-'.
| x X     | Hexadecimal in lower or upper case. Uses ..f/..F for negative values unless + is also used. A `#` adds prefix 0x/0X.
| o       | Octal. Uses ..0 for negative values unless `+` is also used. A `#` adds prefix 0.
| b B     | Binary with prefix 'b' or 'B'. Uses ..1/..1 for negative values unless `+` is also used.
| c       | Numeric value representing a Unicode value, result is a one unicode character string, quoted if alternative flag # is used
| s       | Same as d, or d in quotes if alternative flag # is used.
| p       | Same as d.
| eEfgGaA | Converts integer to float and formats using the floating point rules.

Defaults to `d`.

### Float to String

| Format  | Float formats
| ------  | -------------
| f       | Floating point in non exponential notation.
| e E     | Exponential notation with 'e' or 'E'.
| g G     | Conditional exponential with 'e' or 'E' if exponent < -4 or >= the precision.
| a A     | Hexadecimal exponential form, using 'x'/'X' as prefix and 'p'/'P' before exponent.
| s       | Converted to string using format p, then applying string formatting rule, alternate form # quotes result.
| p       | Same as f format with minimum significant number of fractional digits, prec has no effect.
| dxXobBc | Converts float to integer and formats using the integer rules.

Defaults to `p`.

### String to String

| Format | String
| ------ | ------
| s      | Unquoted string, verbatim output of control chars.
| p      | Programmatic representation - strings are quoted, interior quotes and control chars are escaped.
| C      | Each `::` name segment capitalized, quoted if alternative flag `#` is used.
| c      | Capitalized string, quoted if alternative flag `#` is used.
| d      | Downcased string, quoted if alternative flag `#` is used.
| u      | Upcased string, quoted if alternative flag `#` is used.
| t      | Trims leading and trailing whitespace from the string, quoted if alternative flag `#` is used.

Defaults to `s` at top level and `p` inside array or hash.

### Boolean to String

| Format    | Boolean Formats
| ----      | -------------------   
| t T       | String 'true'/'false' or 'True'/'False', first char if alternate form is used (i.e. 't'/'f' or 'T'/'F').
| y Y       | String 'yes'/'no', 'Yes'/'No', 'y'/'n' or 'Y'/'N' if alternative flag `#` is used.
| dxXobB    | Numeric value 0/1 in accordance with the given format which must be valid integer format.
| eEfgGaA   | Numeric value 0.0/1.0 in accordance with the given float format and flags.
| s         | String 'true' / 'false'.
| p         | String 'true' / 'false'.

### Regexp to String

| Format    | Regexp Formats
| ----      | --------------
| s         | Delimiters `/ /`, alternate flag `#` replaces `/` delimiters with quotes.
| p         | Delimiters `/ /`.

### Undef to String

| Format    | Undef formats
| ------    | -------------
| s         | Empty string, or quoted empty string if alternative flag `#` is used.
| p         | String 'undef', or quoted '"undef"' if alternative flag `#` is used.
| n         | String 'nil', or 'null' if alternative flag `#` is used.
| dxXobB    | String 'NaN'.
| eEfgGaA   | String 'NaN'.
| v         | String 'n/a'.
| V         | String 'N/A'.
| u         | String 'undef', or 'undefined' if alternative `#` flag is used.

### Default value to String

| Format    | Default formats
| ------    | ---------------
| d D       | String 'default' or 'Default', alternative form `#` causes value to be quoted.
| s         | Same as d.
| p         | Same as d.

### Array & Tuple to String

| Format    | Array/Tuple Formats
| ------    | -------------
| a         | Formats with `[ ]` delimiters and `,`, alternate form `#` indents nested arrays/hashes.
| s         | Same as a.
| p         | Same as a.

See "Flags" `<[({\|` for formatting of delimiters, and "Additional parameters for containers; Array and Hash" for
more information about options.

The alternate form flag `#` will cause indentation of nested array or hash containers. If width is also set
it is taken as the maximum allowed length of a sequence of elements (not including delimiters). If this max length
is exceeded, each element will be indented.

### Hash & Struct to String

| Format    | Hash/Struct Formats
| ------    | -------------
| h         | Formats with `{ }` delimiters, `,` element separator and ` => ` inner element separator unless overridden by flags.
| s         | Same as h.
| p         | Same as h.
| a         | Converts the hash to an array of [k,v] tuples and formats it using array rule(s).

See "Flags" `<[({\|` for formatting of delimiters, and "Additional parameters for containers; Array and Hash" for
more information about options.

The alternate form flag `#` will format each hash key/value entry indented on a separate line.

### Type to String

| Format    | Array/Tuple Formats
| ------    | -------------
| s         | The same as `p`, quoted if alternative flag `#` is used.
| p         | Outputs the type in string form as specified by the Puppet Language.

### Flags

| Flag     | Effect 
| ------   | ------
| (space)  | A space instead of `+` for numeric output (`-` is shown), for containers skips delimiters.
| #        | Alternate format; prefix 0x/0x, 0 (octal) and 0b/0B for binary, Floats force decimal '.'. For g/G keep trailing 0.
| +        | Show sign +/- depending on value's sign, changes x, X, o, b, B format to not use 2's complement form.
| -        | Left justify the value in the given width.
| 0        | Pad with 0 instead of space for widths larger than value.
| <[({\|   | Defines an enclosing pair <> [] () {} or \| \| when used with a container type.

Conversion to Boolean
---

Accepts a single value as argument:

* Float 0.0 is `false`, all other float values are `true`
* Integer 0 is `false`, all other integer values are `true`
* Strings
  * `true` if 'true', 'yes', 'y' (case independent compare)
  * `false` if 'false', 'no', 'n' (case independent compare)
* Boolean is already boolean and is simply returned

Conversion to Array and Tuple
---

When given a single value as argument:

* A non empty `Hash` is converted to an array matching `Array[Tuple[Any,Any], 1]`.
* An empty `Hash` becomes an empty array.
* An `Array` is simply returned.
* An `Iterable[T]` is turned into an array of `T` instances.

When given a second Boolean argument:

* if `true`, a value that is not already an array is returned as a one element array.
* if `false`, (the default), converts the first argument as shown above.

**Example:** Ensuring value is an array

```puppet
$arr = Array($value, true)
```

Conversion to a `Tuple` works exactly as conversion to an `Array`, only that the constructed array is
asserted against the given tuple type.

Conversion to Hash and Struct
---

Accepts a single value as argument:

* An empty `Array` becomes an empty `Hash`
* An `Array` matching `Array[Tuple[Any,Any], 1]` is converted to a hash where each tuple describes a key/value entry
* An `Array` with an even number of entries is interpreted as `[key1, val1, key2, val2, ...]`
* An `Iterable` is turned into an `Array` and then converted to hash as per the array rules
* A `Hash` is simply returned

Conversion to a `Struct` works exactly as conversion to a `Hash`, only that the constructed hash is
asserted against the given struct type.

Creating a SemVer
---

A SemVer object represents a single [Semantic Version](http://semver.org/).
It can be created from a String, individual values for its parts, or a hash specifying the value per part.
See the specification at [semver.org](http://semver.org/) for the meaning of the SemVer's parts.

The signatures are:

```puppet
type PositiveInteger = Integer[0,default]
type SemVerQualifier = Pattern[/\A(?<part>[0-9A-Za-z-]+)(?:\.\g<part>)*\Z/]
type SemVerString = String[1]
type SemVerHash =Struct[{
  major                => PositiveInteger,
  minor                => PositiveInteger,
  patch                => PositiveInteger,
  Optional[prerelease] => SemVerQualifier,
  Optional[build]      => SemVerQualifier
}]

function SemVer.new(SemVerString $str)

function SemVer.new(
        PositiveInteger           $major
        PositiveInteger           $minor
        PositiveInteger           $patch
        Optional[SemVerQualifier] $prerelease = undef
        Optional[SemVerQualifier] $build = undef
        )

function SemVer.new(SemVerHash $hash_args)
```

**Examples:** SemVer and SemVerRange usage

```puppet
# As a type, SemVer can describe disjunct ranges which versions can be
# matched against - here the type is constructed with two
# SemVerRange objects.
#
$t = SemVer[
  SemVerRange('>=1.0.0 <2.0.0'), 
  SemVerRange('>=3.0.0 <4.0.0')
]
notice(SemVer('1.2.3') =~ $t) # true
notice(SemVer('2.3.4') =~ $t) # false
notice(SemVer('3.4.5') =~ $t) # true
```

Creating a SemVerRange
---

A `SemVerRange` object represents a range of `SemVer`. It can be created from
a `String`, or from two `SemVer` instances, where either end can be given as
a literal `default` to indicate infinity. The string format of a `SemVerRange` is specified by
the [Semantic Version Range Grammar](https://github.com/npm/node-semver#ranges).

> Use of the comparator sets described in the grammar (joining with `||`) is not supported.

The signatures are:

```puppet
type SemVerRangeString = String[1]
type SemVerRangeHash = Struct[{
  min                   => Variant[default, SemVer],
  Optional[max]         => Variant[default, SemVer],
  Optional[exclude_max] => Boolean
}]

function SemVerRange.new(
  SemVerRangeString $semver_range_string
)

function SemVerRange.new(
  Variant[default,SemVer] $min
  Variant[default,SemVer] $max
  Optional[Boolean]       $exclude_max = undef
)

function SemVerRange.new(
  SemVerRangeHash $semver_range_hash
)
```

For examples of `SemVerRange` use see "Creating a SemVer"

* Since 4.5.0

DOC
) do |args|
  function_fail(["new() is only available when parser/evaluator future is in effect"])
end

