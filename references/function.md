---
layout: default
built_from_commit: 8fcce5cb0d88b7330540e59817a7e6eae7adcdea
title: Built-in function reference
canonical: "/puppet/latest/function.html"
toc_levels: 2
toc: columns
---

# Built-in function reference

> **NOTE:** This page was generated from the Puppet source code on 2024-10-28 17:40:35 +0000



This page is a list of Puppet's built-in functions, with descriptions of what they do and how to use them.

Functions are plugins you can call during catalog compilation. A call to any function is an expression that resolves to a value. For more information on how to call functions, see [the language reference page about function calls.](lang_functions.dita) 

Many of these function descriptions include auto-detected _signatures,_ which are short reminders of the function's allowed arguments. These signatures aren't identical to the syntax you use to call the function; instead, they resemble a parameter list from a Puppet [class](lang_classes.dita), [defined resource type](lang_defined_types.dita), [function](lang_write_functions_in_puppet.dita), or [lambda](lang_lambdas.dita). The syntax of a signature is:

```
<FUNCTION NAME>(<DATA TYPE> <ARGUMENT NAME>, ...)
```

The `<DATA TYPE>` is a [Puppet data type value](lang_data_type.dita), like `String` or `Optional[Array[String]]`. The `<ARGUMENT NAME>` is a descriptive name chosen by the function's author to indicate what the argument is used for.

* Any arguments with an `Optional` data type can be omitted from the function call.
* Arguments that start with an asterisk (like `*$values`) can be repeated any number of times.
* Arguments that start with an ampersand (like `&$block`) aren't normal arguments; they represent a code block, provided with [Puppet's lambda syntax.](lang_lambdas.dita)

## `undef` values in Puppet 6

In Puppet 6, many Puppet types were moved out of the Puppet codebase, and into modules on the Puppet Forge. The new functions handle `undef` values more strictly than their stdlib counterparts. In Puppet 6, code that relies on `undef` values being implicitly treated as other types will return an evaluation error. For more information on which types were moved into modules, see the [Puppet 6 release notes](https://puppet.com/docs/puppet/6.0/release_notes_puppet.html#select-types-moved-to-modules).


## `abs`

Returns the absolute value of a Numeric value, for example -34.56 becomes
34.56. Takes a single `Integer` or `Float` value as an argument.

*Deprecated behavior*

For backwards compatibility reasons this function also works when given a
number in `String` format such that it first attempts to covert it to either a `Float` or
an `Integer` and then taking the absolute value of the result. Only strings representing
a number in decimal format is supported - an error is raised if
value is not decimal (using base 10). Leading 0 chars in the string
are ignored. A floating point value in string form can use some forms of
scientific notation but not all.

Callers should convert strings to `Numeric` before calling
this function to have full control over the conversion.

```puppet
abs(Numeric($str_val))
```

It is worth noting that `Numeric` can convert to absolute value
directly as in the following examples:

```puppet
Numeric($strval, true)     # Converts to absolute Integer or Float
Integer($strval, 10, true) # Converts to absolute Integer using base 10 (decimal)
Integer($strval, 16, true) # Converts to absolute Integer using base 16 (hex)
Float($strval, true)       # Converts to absolute Float
```


Signature 1

`abs(Numeric $val)`

Signature 2

`abs(String $val)`

## `alert`

Logs a message on the server at level `alert`.


`alert(Any *$values)`

### Parameters


* `*values` --- The values to log.

Return type(s): `Undef`. 

## `all`

Runs a [lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html)
repeatedly using each value in a data structure until the lambda returns a non "truthy" value which
makes the function return `false`, or if the end of the iteration is reached, `true` is returned.

This function takes two mandatory arguments, in this order:

1. An array, hash, or other iterable object that the function will iterate over.
2. A lambda, which the function calls for each element in the first argument. It can
request one or two parameters.

`$data.all |$parameter| { <PUPPET CODE BLOCK> }`

or

`all($data) |$parameter| { <PUPPET CODE BLOCK> }`

```puppet
# For the array $data, run a lambda that checks that all values are multiples of 10
$data = [10, 20, 30]
notice $data.all |$item| { $item % 10 == 0 }
```

Would notice `true`.

When the first argument is a `Hash`, Puppet passes each key and value pair to the lambda
as an array in the form `[key, value]`.

```puppet
# For the hash $data, run a lambda using each item as a key-value array
$data = { 'a_0'=> 10, 'b_1' => 20 }
notice $data.all |$item| { $item[1] % 10 == 0  }
```

Would notice `true` if all values in the hash are multiples of 10.

When the lambda accepts two arguments, the first argument gets the index in an array
or the key from a hash, and the second argument the value.


```puppet
# Check that all values are a multiple of 10 and keys start with 'abc'
$data = {abc_123 => 10, abc_42 => 20, abc_blue => 30}
notice $data.all |$key, $value| { $value % 10 == 0  and $key =~ /^abc/ }
```

Would notice `true`.

For an general examples that demonstrates iteration, see the Puppet
[iteration](https://puppet.com/docs/puppet/latest/lang_iteration.html)
documentation.


Signature 1

`all(Hash[Any, Any] $hash, Callable[2,2] &$block)`

Signature 2

`all(Hash[Any, Any] $hash, Callable[1,1] &$block)`

Signature 3

`all(Iterable $enumerable, Callable[2,2] &$block)`

Signature 4

`all(Iterable $enumerable, Callable[1,1] &$block)`

## `annotate`

Handles annotations on objects. The function can be used in four different ways.

With two arguments, an `Annotation` type and an object, the function returns the annotation
for the object of the given type, or `undef` if no such annotation exists.

```puppet
$annotation = Mod::NickNameAdapter.annotate(o)

$annotation = annotate(Mod::NickNameAdapter.annotate, o)
```

With three arguments, an `Annotation` type, an object, and a block, the function returns the
annotation for the object of the given type, or annotates it with a new annotation initialized
from the hash returned by the given block when no such annotation exists. The block will not
be called when an annotation of the given type is already present.

```puppet
$annotation = Mod::NickNameAdapter.annotate(o) || { { 'nick_name' => 'Buddy' } }

$annotation = annotate(Mod::NickNameAdapter.annotate, o) || { { 'nick_name' => 'Buddy' } }
```

With three arguments, an `Annotation` type, an object, and an `Hash`, the function will annotate
the given object with a new annotation of the given type that is initialized from the given hash.
An existing annotation of the given type is discarded.

```puppet
$annotation = Mod::NickNameAdapter.annotate(o, { 'nick_name' => 'Buddy' })

$annotation = annotate(Mod::NickNameAdapter.annotate, o, { 'nick_name' => 'Buddy' })
```

With three arguments, an `Annotation` type, an object, and an the string `clear`, the function will
clear the annotation of the given type in the given object. The old annotation is returned if
it existed.

```puppet
$annotation = Mod::NickNameAdapter.annotate(o, clear)

$annotation = annotate(Mod::NickNameAdapter.annotate, o, clear)
```

With three arguments, the type `Pcore`, an object, and a Hash of hashes keyed by `Annotation` types,
the function will annotate the given object with all types used as keys in the given hash. Each annotation
is initialized with the nested hash for the respective type. The annotated object is returned.

```puppet
  $person = Pcore.annotate(Mod::Person({'name' => 'William'}), {
    Mod::NickNameAdapter >= { 'nick_name' => 'Bill' },
    Mod::HobbiesAdapter => { 'hobbies' => ['Ham Radio', 'Philatelist'] }
  })
```


Signature 1

`annotate(Type[Annotation] $type, Any $value, Optional[Callable[0, 0]] &$block)`

Signature 2

`annotate(Type[Annotation] $type, Any $value, Variant[Enum[clear],Hash[Pcore::MemberName,Any]] $annotation_hash)`

Signature 3

`annotate(Type[Pcore] $type, Any $value, Hash[Type[Annotation], Hash[Pcore::MemberName,Any]] $annotations)`

## `any`

Runs a [lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html)
repeatedly using each value in a data structure until the lambda returns a "truthy" value which
makes the function return `true`, or if the end of the iteration is reached, false is returned.

This function takes two mandatory arguments, in this order:

1. An array, hash, or other iterable object that the function will iterate over.
2. A lambda, which the function calls for each element in the first argument. It can
request one or two parameters.

`$data.any |$parameter| { <PUPPET CODE BLOCK> }`

or

`any($data) |$parameter| { <PUPPET CODE BLOCK> }`

```puppet
# For the array $data, run a lambda that checks if an unknown hash contains those keys
$data = ["routers", "servers", "workstations"]
$looked_up = lookup('somekey', Hash)
notice $data.any |$item| { $looked_up[$item] }
```

Would notice `true` if the looked up hash had a value that is neither `false` nor `undef` for at least
one of the keys. That is, it is equivalent to the expression
`$looked_up[routers] || $looked_up[servers] || $looked_up[workstations]`.

When the first argument is a `Hash`, Puppet passes each key and value pair to the lambda
as an array in the form `[key, value]`.

```puppet
# For the hash $data, run a lambda using each item as a key-value array.
$data = {"rtr" => "Router", "svr" => "Server", "wks" => "Workstation"}
$looked_up = lookup('somekey', Hash)
notice $data.any |$item| { $looked_up[$item[0]] }
```

Would notice `true` if the looked up hash had a value for one of the wanted key that is
neither `false` nor `undef`.

When the lambda accepts two arguments, the first argument gets the index in an array
or the key from a hash, and the second argument the value.


```puppet
# Check if there is an even numbered index that has a non String value
$data = [key1, 1, 2, 2]
notice $data.any |$index, $value| { $index % 2 == 0 and $value !~ String }
```

Would notice true as the index `2` is even and not a `String`

For an general examples that demonstrates iteration, see the Puppet
[iteration](https://puppet.com/docs/puppet/latest/lang_iteration.html)
documentation.


Signature 1

`any(Hash[Any, Any] $hash, Callable[2,2] &$block)`

Signature 2

`any(Hash[Any, Any] $hash, Callable[1,1] &$block)`

Signature 3

`any(Iterable $enumerable, Callable[2,2] &$block)`

Signature 4

`any(Iterable $enumerable, Callable[1,1] &$block)`

## `assert_type`

Returns the given value if it is of the given
[data type](https://puppet.com/docs/puppet/latest/lang_data.html), or
otherwise either raises an error or executes an optional two-parameter
[lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html).

The function takes two mandatory arguments, in this order:

1. The expected data type.
2. A value to compare against the expected data type.

```puppet
$raw_username = 'Amy Berry'

# Assert that $raw_username is a non-empty string and assign it to $valid_username.
$valid_username = assert_type(String[1], $raw_username)

# $valid_username contains "Amy Berry".
# If $raw_username was an empty string or a different data type, the Puppet run would
# fail with an "Expected type does not match actual" error.
```

You can use an optional lambda to provide enhanced feedback. The lambda takes two
mandatory parameters, in this order:

1. The expected data type as described in the function's first argument.
2. The actual data type of the value.

```puppet
$raw_username = 'Amy Berry'

# Assert that $raw_username is a non-empty string and assign it to $valid_username.
# If it isn't, output a warning describing the problem and use a default value.
$valid_username = assert_type(String[1], $raw_username) |$expected, $actual| {
  warning( "The username should be \'${expected}\', not \'${actual}\'. Using 'anonymous'." )
  'anonymous'
}

# $valid_username contains "Amy Berry".
# If $raw_username was an empty string, the Puppet run would set $valid_username to
# "anonymous" and output a warning: "The username should be 'String[1, default]', not
# 'String[0, 0]'. Using 'anonymous'."
```

For more information about data types, see the
[documentation](https://puppet.com/docs/puppet/latest/lang_data.html).


Signature 1

`assert_type(Type $type, Any $value, Optional[Callable[Type, Type]] &$block)`

Signature 2

`assert_type(String $type_string, Any $value, Optional[Callable[Type, Type]] &$block)`

## `binary_file`

Loads a binary file from a module or file system and returns its contents as a `Binary`.
The argument to this function should be a `<MODULE NAME>/<FILE>`
reference, which will load `<FILE>` from a module's `files`
directory. (For example, the reference `mysql/mysqltuner.pl` will load the
file `<MODULES DIRECTORY>/mysql/files/mysqltuner.pl`.)

This function also accepts an absolute file path that allows reading
binary file content from anywhere on disk.

An error is raised if the given file does not exists.

To search for the existence of files, use the `find_file()` function.

- since 4.8.0


`binary_file(String $path)`

## `break`

Breaks an innermost iteration as if it encountered an end of input.
This function does not return to the caller.

The signal produced to stop the iteration bubbles up through
the call stack until either terminating the innermost iteration or
raising an error if the end of the call stack is reached.

The break() function does not accept an argument.

```puppet
$data = [1,2,3]
notice $data.map |$x| { if $x == 3 { break() } $x*10 }
```

Would notice the value `[10, 20]`

```puppet
function break_if_even($x) {
  if $x % 2 == 0 { break() }
}
$data = [1,2,3]
notice $data.map |$x| { break_if_even($x); $x*10 }
```
Would notice the value `[10]`

* Also see functions `next` and `return`


`break()`

## `call`

Calls an arbitrary Puppet function by name.

This function takes one mandatory argument and one or more optional arguments:

1. A string corresponding to a function name.
2. Any number of arguments to be passed to the called function.
3. An optional lambda, if the function being called supports it.

This function can also be used to resolve a `Deferred` given as
the only argument to the function (does not accept arguments nor
a block).

```puppet
$a = 'notice'
call($a, 'message')
```

```puppet
$a = 'each'
$b = [1,2,3]
call($a, $b) |$item| {
 notify { $item: }
}
```

The `call` function can be used to call either Ruby functions or Puppet language
functions.

When used with `Deferred` values, the deferred value can either describe
a function call, or a dig into a variable.

```puppet
$d = Deferred('join', [[1,2,3], ':']) # A future call to join that joins the arguments 1,2,3 with ':'
notice($d.call())
```

Would notice the string "1:2:3".

```puppet
$d = Deferred('$facts', ['processors', 'count'])
notice($d.call())
```

Would notice the value of `$facts['processors']['count']` at the time when the `call` is made.

* Deferred values supported since Puppet 6.0


Signature 1

`call(String $function_name, Any *$arguments, Optional[Callable] &$block)`

Signature 2

`call(Deferred $deferred)`

## `camelcase`

Creates a Camel Case version of a String

This function is compatible with the stdlib function with the same name.

The function does the following:
* For a `String` the conversion replaces all combinations of `*_<char>*` with an upcased version of the
  character following the _.  This is done using Ruby system locale which handles some, but not all
  special international up-casing rules (for example German double-s ß is upcased to "Ss").
* For an `Iterable[Variant[String, Numeric]]` (for example an `Array`) each value is capitalized and the conversion is not recursive.
* If the value is `Numeric` it is simply returned (this is for backwards compatibility).
* An error is raised for all other data types.
* The result will not contain any underscore characters.

Please note: This function relies directly on Ruby's String implementation and as such may not be entirely UTF8 compatible.
To ensure best compatibility please use this function with Ruby 2.4.0 or greater - https://bugs.ruby-lang.org/issues/10085.

```puppet
'hello_friend'.camelcase()
camelcase('hello_friend')
```
Would both result in `"HelloFriend"`

```puppet
['abc_def', 'bcd_xyz'].camelcase()
camelcase(['abc_def', 'bcd_xyz'])
```
Would both result in `['AbcDef', 'BcdXyz']`


Signature 1

`camelcase(Numeric $arg)`

Signature 2

`camelcase(String $arg)`

Signature 3

`camelcase(Iterable[Variant[String, Numeric]] $arg)`

## `capitalize`

Capitalizes the first character of a String, or the first character of every String in an Iterable value (such as an Array).

This function is compatible with the stdlib function with the same name.

The function does the following:
* For a `String`, a string is returned in which the first character is uppercase.
  This is done using Ruby system locale which handles some, but not all
  special international up-casing rules (for example German double-s ß is capitalized to "Ss").
* For an `Iterable[Variant[String, Numeric]]` (for example an `Array`) each value is capitalized and the conversion is not recursive.
* If the value is `Numeric` it is simply returned (this is for backwards compatibility).
* An error is raised for all other data types.

Please note: This function relies directly on Ruby's String implementation and as such may not be entirely UTF8 compatible.
To ensure best compatibility please use this function with Ruby 2.4.0 or greater - https://bugs.ruby-lang.org/issues/10085.

```puppet
'hello'.capitalize()
capitalize('hello')
```
Would both result in `"Hello"`

```puppet
['abc', 'bcd'].capitalize()
capitalize(['abc', 'bcd'])
```
Would both result in `['Abc', 'Bcd']`


Signature 1

`capitalize(Numeric $arg)`

Signature 2

`capitalize(String $arg)`

Signature 3

`capitalize(Iterable[Variant[String, Numeric]] $arg)`

## `ceiling`

Returns the smallest `Integer` greater or equal to the argument.
Takes a single numeric value as an argument.

This function is backwards compatible with the same function in stdlib
and accepts a `Numeric` value. A `String` that can be converted
to a floating point number can also be used in this version - but this
is deprecated.

In general convert string input to `Numeric` before calling this function
to have full control over how the conversion is done.


Signature 1

`ceiling(Numeric $val)`

Signature 2

`ceiling(String $val)`

## `chomp`

Returns a new string with the record separator character(s) removed.
The record separator is the line ending characters `\r` and `\n`.

This function is compatible with the stdlib function with the same name.

The function does the following:
* For a `String` the conversion removes `\r\n`, `\n` or `\r` from the end of a string.
* For an `Iterable[Variant[String, Numeric]]` (for example an `Array`) each value is processed and the conversion is not recursive.
* If the value is `Numeric` it is simply returned (this is for backwards compatibility).
* An error is raised for all other data types.

```puppet
"hello\r\n".chomp()
chomp("hello\r\n")
```
Would both result in `"hello"`

```puppet
["hello\r\n", "hi\r\n"].chomp()
chomp(["hello\r\n", "hi\r\n"])
```
Would both result in `['hello', 'hi']`


Signature 1

`chomp(Numeric $arg)`

Signature 2

`chomp(String $arg)`

Signature 3

`chomp(Iterable[Variant[String, Numeric]] $arg)`

## `chop`

Returns a new string with the last character removed.
If the string ends with `\r\n`, both characters are removed. Applying chop to an empty
string returns an empty string. If you wish to merely remove record
separators then you should use the `chomp` function.

This function is compatible with the stdlib function with the same name.

The function does the following:
* For a `String` the conversion removes the last character, or if it ends with \r\n` it removes both. If String is empty
  an empty string is returned.
* For an `Iterable[Variant[String, Numeric]]` (for example an `Array`) each value is processed and the conversion is not recursive.
* If the value is `Numeric` it is simply returned (this is for backwards compatibility).
* An error is raised for all other data types.

```puppet
"hello\r\n".chop()
chop("hello\r\n")
```
Would both result in `"hello"`

```puppet
"hello".chop()
chop("hello")
```
Would both result in `"hell"`

```puppet
["hello\r\n", "hi\r\n"].chop()
chop(["hello\r\n", "hi\r\n"])
```
Would both result in `['hello', 'hi']`


Signature 1

`chop(Numeric $arg)`

Signature 2

`chop(String $arg)`

Signature 3

`chop(Iterable[Variant[String, Numeric]] $arg)`

## `compare`

Compares two values and returns -1, 0 or 1 if first value is smaller, equal or larger than the second value.
The compare function accepts arguments of the data types `String`, `Numeric`, `Timespan`, `Timestamp`, and `Semver`,
such that:

* two of the same data type can be compared
* `Timespan` and `Timestamp` can be compared with each other and with `Numeric`

When comparing two `String` values the comparison can be made to consider case by passing a third (optional)
boolean `false` value - the default is `true` which ignores case as the comparison operators
in the Puppet Language.


Signature 1

`compare(Numeric $a, Numeric $b)`

Signature 2

`compare(String $a, String $b, Optional[Boolean] $ignore_case)`

Signature 3

`compare(Semver $a, Semver $b)`

Signature 4

`compare(Numeric $a, Variant[Timespan, Timestamp] $b)`

Signature 5

`compare(Timestamp $a, Variant[Timestamp, Numeric] $b)`

Signature 6

`compare(Timespan $a, Variant[Timespan, Numeric] $b)`

## `contain`

Makes one or more classes be contained inside the current class.
If any of these classes are undeclared, they will be declared as if
there were declared with the `include` function.
Accepts a class name, an array of class names, or a comma-separated
list of class names.

A contained class will not be applied before the containing class is
begun, and will be finished before the containing class is finished.

You must use the class's full name;
relative names are not allowed. In addition to names in string form,
you may also directly use `Class` and `Resource` `Type`-values that are produced by
evaluating resource and relationship expressions.

The function returns an array of references to the classes that were contained thus
allowing the function call to `contain` to directly continue.

- Since 4.0.0 support for `Class` and `Resource` `Type`-values, absolute names
- Since 4.7.0 a value of type `Array[Type[Class[n]]]` is returned with all the contained classes


`contain(Any *$names)`

## `convert_to`

The `convert_to(value, type)` is a convenience function that does the same as `new(type, value)`.
The difference in the argument ordering allows it to be used in chained style for
improved readability "left to right".

When the function is given a lambda, it is called with the converted value, and the function
returns what the lambda returns, otherwise the converted value.

```puppet
  # The harder to read variant:
  # Using new operator - that is "calling the type" with operator ()
  Hash(Array("abc").map |$i,$v| { [$i, $v] })

  # The easier to read variant:
  # using 'convert_to'
  "abc".convert_to(Array).map |$i,$v| { [$i, $v] }.convert_to(Hash)
```


`convert_to(Any $value, Type $type, Optional[Any] *$args, Optional[Callable[1,1]] &$block)`

## `create_resources`

Converts a hash into a set of resources and adds them to the catalog.

**Note**: Use this function selectively. It's generally better to write resources in
 [Puppet](https://puppet.com/docs/puppet/latest/lang_resources.html), as
 resources created with `create_resource` are difficult to read and troubleshoot.

This function takes two mandatory arguments: a resource type, and a hash describing
a set of resources. The hash should be in the form `{title => {parameters} }`:

    # A hash of user resources:
    $myusers = {
      'nick' => { uid    => '1330',
                  gid    => allstaff,
                  groups => ['developers', 'operations', 'release'], },
      'dan'  => { uid    => '1308',
                  gid    => allstaff,
                  groups => ['developers', 'prosvc', 'release'], },
    }

    create_resources(user, $myusers)

A third, optional parameter may be given, also as a hash:

    $defaults = {
      'ensure'   => present,
      'provider' => 'ldap',
    }

    create_resources(user, $myusers, $defaults)

The values given on the third argument are added to the parameters of each resource
present in the set given on the second argument. If a parameter is present on both
the second and third arguments, the one on the second argument takes precedence.

This function can be used to create defined resources and classes, as well
as native resources.

Virtual and Exported resources may be created by prefixing the type name
with @ or @@ respectively. For example, the $myusers hash may be exported
in the following manner:

    create_resources("@@user", $myusers)

The $myusers may be declared as virtual resources using:

    create_resources("@user", $myusers)

Note that `create_resources` filters out parameter values that are `undef` so that normal
data binding and Puppet default value expressions are considered (in that order) for the
final value of a parameter (just as when setting a parameter to `undef` in a Puppet language
resource declaration).


`create_resources()`

## `crit`

Logs a message on the server at level `crit`.


`crit(Any *$values)`

### Parameters


* `*values` --- The values to log.

Return type(s): `Undef`. 

## `debug`

Logs a message on the server at level `debug`.


`debug(Any *$values)`

### Parameters


* `*values` --- The values to log.

Return type(s): `Undef`. 

## `defined`

Determines whether a given class or resource type is defined and returns a Boolean
value. You can also use `defined` to determine whether a specific resource is defined,
or whether a variable has a value (including `undef`, as opposed to the variable never
being declared or assigned).

This function takes at least one string argument, which can be a class name, type name,
resource reference, or variable reference of the form `'$name'`. (Note that the `$` sign
is included in the string which must be in single quotes to prevent the `$` character
to be interpreted as interpolation.

The `defined` function checks both native and defined types, including types
provided by modules. Types and classes are matched by their names. The function matches
resource declarations by using resource references.

```puppet
# Matching resource types
defined("file")
defined("customtype")

# Matching defines and classes
defined("foo")
defined("foo::bar")

# Matching variables (note the single quotes)
defined('$name')

# Matching declared resources
defined(File['/tmp/file'])
```

Puppet depends on the configuration's evaluation order when checking whether a resource
is declared.

```puppet
# Assign values to $is_defined_before and $is_defined_after using identical `defined`
# functions.

$is_defined_before = defined(File['/tmp/file'])

file { "/tmp/file":
  ensure => present,
}

$is_defined_after = defined(File['/tmp/file'])

# $is_defined_before returns false, but $is_defined_after returns true.
```

This order requirement only refers to evaluation order. The order of resources in the
configuration graph (e.g. with `before` or `require`) does not affect the `defined`
function's behavior.

> **Warning:** Avoid relying on the result of the `defined` function in modules, as you
> might not be able to guarantee the evaluation order well enough to produce consistent
> results. This can cause other code that relies on the function's result to behave
> inconsistently or fail.

If you pass more than one argument to `defined`, the function returns `true` if _any_
of the arguments are defined. You can also match resources by type, allowing you to
match conditions of different levels of specificity, such as whether a specific resource
is of a specific data type.

```puppet
file { "/tmp/file1":
  ensure => file,
}

$tmp_file = file { "/tmp/file2":
  ensure => file,
}

# Each of these statements return `true` ...
defined(File['/tmp/file1'])
defined(File['/tmp/file1'],File['/tmp/file2'])
defined(File['/tmp/file1'],File['/tmp/file2'],File['/tmp/file3'])
# ... but this returns `false`.
defined(File['/tmp/file3'])

# Each of these statements returns `true` ...
defined(Type[Resource['file','/tmp/file2']])
defined(Resource['file','/tmp/file2'])
defined(File['/tmp/file2'])
defined('$tmp_file')
# ... but each of these returns `false`.
defined(Type[Resource['exec','/tmp/file2']])
defined(Resource['exec','/tmp/file2'])
defined(File['/tmp/file3'])
defined('$tmp_file2')
```


`defined(Variant[String, Type[CatalogEntry], Type[Type[CatalogEntry]]] *$vals)`

## `dig`

Returns a value for a sequence of given keys/indexes into a structure, such as
an array or hash.

This function is used to "dig into" a complex data structure by
using a sequence of keys / indexes to access a value from which
the next key/index is accessed recursively.

The first encountered `undef` value or key stops the "dig" and `undef` is returned.

An error is raised if an attempt is made to "dig" into
something other than an `undef` (which immediately returns `undef`), an `Array` or a `Hash`.

```puppet
$data = {a => { b => [{x => 10, y => 20}, {x => 100, y => 200}]}}
notice $data.dig('a', 'b', 1, 'x')
```

Would notice the value 100.

This is roughly equivalent to `$data['a']['b'][1]['x']`. However, a standard
index will return an error and cause catalog compilation failure if any parent
of the final key (`'x'`) is `undef`. The `dig` function will return `undef`,
rather than failing catalog compilation. This allows you to check if data
exists in a structure without mandating that it always exists.


`dig(Optional[Collection] $data, Any *$arg)`

## `digest`

Returns a hash value from a provided string using the digest_algorithm setting from the Puppet config file.


`digest()`

## `downcase`

Converts a String, Array or Hash (recursively) into lower case.

This function is compatible with the stdlib function with the same name.

The function does the following:
* For a `String`, its lower case version is returned. This is done using Ruby system locale which handles some, but not all
  special international up-casing rules (for example German double-s ß is upcased to "SS", whereas upper case double-s
  is downcased to ß).
* For `Array` and `Hash` the conversion to lower case is recursive and each key and value must be convertible by
  this function.
* When a `Hash` is converted, some keys could result in the same key - in those cases, the
  latest key-value wins. For example if keys "aBC", and "abC" where both present, after downcase there would only be one
  key "abc".
* If the value is `Numeric` it is simply returned (this is for backwards compatibility).
* An error is raised for all other data types.

Please note: This function relies directly on Ruby's String implementation and as such may not be entirely UTF8 compatible.
To ensure best compatibility please use this function with Ruby 2.4.0 or greater - https://bugs.ruby-lang.org/issues/10085.

```puppet
'HELLO'.downcase()
downcase('HEllO')
```
Would both result in `"hello"`

```puppet
['A', 'B'].downcase()
downcase(['A', 'B'])
```
Would both result in `['a', 'b']`

```puppet
{'A' => 'HEllO', 'B' => 'GOODBYE'}.downcase()
```
Would result in `{'a' => 'hello', 'b' => 'goodbye'}`

```puppet
['A', 'B', ['C', ['D']], {'X' => 'Y'}].downcase
```
Would result in `['a', 'b', ['c', ['d']], {'x' => 'y'}]`


Signature 1

`downcase(Numeric $arg)`

Signature 2

`downcase(String $arg)`

Signature 3

`downcase(Array[StringData] $arg)`

Signature 4

`downcase(Hash[StringData, StringData] $arg)`

## `each`

Runs a [lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html)
repeatedly using each value in a data structure, then returns the values unchanged.

This function takes two mandatory arguments, in this order:

1. An array, hash, or other iterable object that the function will iterate over.
2. A lambda, which the function calls for each element in the first argument. It can
request one or two parameters.

`$data.each |$parameter| { <PUPPET CODE BLOCK> }`

or

`each($data) |$parameter| { <PUPPET CODE BLOCK> }`

When the first argument (`$data` in the above example) is an array, Puppet passes each
value in turn to the lambda, then returns the original values.

```puppet
# For the array $data, run a lambda that creates a resource for each item.
$data = ["routers", "servers", "workstations"]
$data.each |$item| {
 notify { $item:
   message => $item
 }
}
# Puppet creates one resource for each of the three items in $data. Each resource is
# named after the item's value and uses the item's value in a parameter.
```

When the first argument is a hash, Puppet passes each key and value pair to the lambda
as an array in the form `[key, value]` and returns the original hash.

```puppet
# For the hash $data, run a lambda using each item as a key-value array that creates a
# resource for each item.
$data = {"rtr" => "Router", "svr" => "Server", "wks" => "Workstation"}
$data.each |$items| {
 notify { $items[0]:
   message => $items[1]
 }
}
# Puppet creates one resource for each of the three items in $data, each named after the
# item's key and containing a parameter using the item's value.
```

When the first argument is an array and the lambda has two parameters, Puppet passes the
array's indexes (enumerated from 0) in the first parameter and its values in the second
parameter.

```puppet
# For the array $data, run a lambda using each item's index and value that creates a
# resource for each item.
$data = ["routers", "servers", "workstations"]
$data.each |$index, $value| {
 notify { $value:
   message => $index
 }
}
# Puppet creates one resource for each of the three items in $data, each named after the
# item's value and containing a parameter using the item's index.
```

When the first argument is a hash, Puppet passes its keys to the first parameter and its
values to the second parameter.

```puppet
# For the hash $data, run a lambda using each item's key and value to create a resource
# for each item.
$data = {"rtr" => "Router", "svr" => "Server", "wks" => "Workstation"}
$data.each |$key, $value| {
 notify { $key:
   message => $value
 }
}
# Puppet creates one resource for each of the three items in $data, each named after the
# item's key and containing a parameter using the item's value.
```

For an example that demonstrates how to create multiple `file` resources using `each`,
see the Puppet
[iteration](https://puppet.com/docs/puppet/latest/lang_iteration.html)
documentation.


Signature 1

`each(Hash[Any, Any] $hash, Callable[2,2] &$block)`

Signature 2

`each(Hash[Any, Any] $hash, Callable[1,1] &$block)`

Signature 3

`each(Iterable $enumerable, Callable[2,2] &$block)`

Signature 4

`each(Iterable $enumerable, Callable[1,1] &$block)`

## `emerg`

Logs a message on the server at level `emerg`.


`emerg(Any *$values)`

### Parameters


* `*values` --- The values to log.

Return type(s): `Undef`. 

## `empty`

Returns `true` if the given argument is an empty collection of values.

This function can answer if one of the following is empty:
* `Array`, `Hash` - having zero entries
* `String`, `Binary` - having zero length

For backwards compatibility with the stdlib function with the same name the
following data types are also accepted by the function instead of raising an error.
Using these is deprecated and will raise a warning:

* `Numeric` - `false` is returned for all `Numeric` values.
* `Undef` - `true` is returned for all `Undef` values.

```puppet
notice([].empty)
notice(empty([]))
# would both notice 'true'
```


Signature 1

`empty(Collection $coll)`

Signature 2

`empty(Sensitive[String] $str)`

Signature 3

`empty(String $str)`

Signature 4

`empty(Numeric $num)`

Signature 5

`empty(Binary $bin)`

Signature 6

`empty(Undef $x)`

## `epp`

Evaluates an Embedded Puppet (EPP) template file and returns the rendered text
result as a String.

`epp('<MODULE NAME>/<TEMPLATE FILE>', <PARAMETER HASH>)`

The first argument to this function should be a `<MODULE NAME>/<TEMPLATE FILE>`
reference, which loads `<TEMPLATE FILE>` from `<MODULE NAME>`'s `templates`
directory. In most cases, the last argument is optional; if used, it should be a
[hash](https://puppet.com/docs/puppet/latest/lang_data_hash.html) that contains parameters to
pass to the template.

- See the [template](https://puppet.com/docs/puppet/latest/lang_template.html)
documentation for general template usage information.
- See the [EPP syntax](https://puppet.com/docs/puppet/latest/lang_template_epp.html)
documentation for examples of EPP.

For example, to call the apache module's `templates/vhost/_docroot.epp`
template and pass the `docroot` and `virtual_docroot` parameters, call the `epp`
function like this:

`epp('apache/vhost/_docroot.epp', { 'docroot' => '/var/www/html',
'virtual_docroot' => '/var/www/example' })`

This function can also accept an absolute path, which can load a template file
from anywhere on disk.

Puppet produces a syntax error if you pass more parameters than are declared in
the template's parameter tag. When passing parameters to a template that
contains a parameter tag, use the same names as the tag's declared parameters.

Parameters are required only if they are declared in the called template's
parameter tag without default values. Puppet produces an error if the `epp`
function fails to pass any required parameter.


`epp(String $path, Optional[Hash[Pattern[/^\w+$/], Any]] $parameters)`

## `err`

Logs a message on the server at level `err`.


`err(Any *$values)`

### Parameters


* `*values` --- The values to log.

Return type(s): `Undef`. 

## `eyaml_lookup_key`

The `eyaml_lookup_key` is a hiera 5 `lookup_key` data provider function.
See [the configuration guide documentation](https://puppet.com/docs/puppet/latest/hiera_config_yaml_5.html#configuring-a-hierarchy-level-hiera-eyaml) for
how to use this function.


`eyaml_lookup_key(String[1] $key, Hash[String[1],Any] $options, Puppet::LookupContext $context)`

## `fail`

Fail with a parse error. Any parameters will be stringified,
concatenated, and passed to the exception-handler.


`fail()`

## `file`

Loads a file from a module and returns its contents as a string.

The argument to this function should be a `<MODULE NAME>/<FILE>`
reference, which will load `<FILE>` from a module's `files`
directory. (For example, the reference `mysql/mysqltuner.pl` will load the
file `<MODULES DIRECTORY>/mysql/files/mysqltuner.pl`.)

This function can also accept:

* An absolute path, which can load a file from anywhere on disk.
* Multiple arguments, which will return the contents of the **first** file
found, skipping any files that don't exist.


`file()`

## `filter`

Applies a [lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html)
to every value in a data structure and returns an array or hash containing any elements
for which the lambda evaluates to a truthy value (not `false` or `undef`).

This function takes two mandatory arguments, in this order:

1. An array, hash, or other iterable object that the function will iterate over.
2. A lambda, which the function calls for each element in the first argument. It can
request one or two parameters.

`$filtered_data = $data.filter |$parameter| { <PUPPET CODE BLOCK> }`

or

`$filtered_data = filter($data) |$parameter| { <PUPPET CODE BLOCK> }`

When the first argument (`$data` in the above example) is an array, Puppet passes each
value in turn to the lambda and returns an array containing the results.

```puppet
# For the array $data, return an array containing the values that end with "berry"
$data = ["orange", "blueberry", "raspberry"]
$filtered_data = $data.filter |$items| { $items =~ /berry$/ }
# $filtered_data = [blueberry, raspberry]
```

When the first argument is a hash, Puppet passes each key and value pair to the lambda
as an array in the form `[key, value]` and returns a hash containing the results.

```puppet
# For the hash $data, return a hash containing all values of keys that end with "berry"
$data = { "orange" => 0, "blueberry" => 1, "raspberry" => 2 }
$filtered_data = $data.filter |$items| { $items[0] =~ /berry$/ }
# $filtered_data = {blueberry => 1, raspberry => 2}
```

When the first argument is an array and the lambda has two parameters, Puppet passes the
array's indexes (enumerated from 0) in the first parameter and its values in the second
parameter.

```puppet
# For the array $data, return an array of all keys that both end with "berry" and have
# an even-numbered index
$data = ["orange", "blueberry", "raspberry"]
$filtered_data = $data.filter |$indexes, $values| { $indexes % 2 == 0 and $values =~ /berry$/ }
# $filtered_data = [raspberry]
```

When the first argument is a hash, Puppet passes its keys to the first parameter and its
values to the second parameter.

```puppet
# For the hash $data, return a hash of all keys that both end with "berry" and have
# values less than or equal to 1
$data = { "orange" => 0, "blueberry" => 1, "raspberry" => 2 }
$filtered_data = $data.filter |$keys, $values| { $keys =~ /berry$/ and $values <= 1 }
# $filtered_data = {blueberry => 1}
```


Signature 1

`filter(Hash[Any, Any] $hash, Callable[2,2] &$block)`

Signature 2

`filter(Hash[Any, Any] $hash, Callable[1,1] &$block)`

Signature 3

`filter(Iterable $enumerable, Callable[2,2] &$block)`

Signature 4

`filter(Iterable $enumerable, Callable[1,1] &$block)`

## `find_file`

Finds an existing file from a module and returns its path.

This function accepts an argument that is a String as a `<MODULE NAME>/<FILE>`
reference, which searches for `<FILE>` relative to a module's `files`
directory. (For example, the reference `mysql/mysqltuner.pl` will search for the
file `<MODULES DIRECTORY>/mysql/files/mysqltuner.pl`.)

If this function is run via puppet agent, it checks for file existence on the
Puppet Primary server. If run via puppet apply, it checks on the local host.
In both cases, the check is performed before any resources are changed.

This function can also accept:

* An absolute String path, which checks for the existence of a file from anywhere on disk.
* Multiple String arguments, which returns the path of the **first** file
  found, skipping nonexistent files.
* An array of string paths, which returns the path of the **first** file
  found from the given paths in the array, skipping nonexistent files.

The function returns `undef` if none of the given paths were found.


Signature 1

`find_file(String *$paths)`

Signature 2

`find_file(Array[String] *$paths_array)`

## `find_template`

Finds an existing template from a module and returns its path.

This function accepts an argument that is a String as a `<MODULE NAME>/<TEMPLATE>`
reference, which searches for `<TEMPLATE>` relative to a module's `templates`
directory on the primary server. (For example, the reference `mymod/secret.conf.epp`
will search for the file `<MODULES DIRECTORY>/mymod/templates/secret.conf.epp`.)

The primary use case is for agent-side template rendering with late-bound variables
resolved, such as from secret stores inaccessible to the primary server, such as

```
$variables = {
  'password' => Deferred('vault_lookup::lookup',
                  ['secret/mymod', 'https://vault.example.com:8200']),
}

# compile the template source into the catalog
file { '/etc/secrets.conf':
  ensure  => file,
  content => Deferred('inline_epp',
               [find_template('mymod/secret.conf.epp').file, $variables]),
}
```



This function can also accept:

* An absolute String path, which checks for the existence of a template from anywhere on disk.
* Multiple String arguments, which returns the path of the **first** template
  found, skipping nonexistent files.
* An array of string paths, which returns the path of the **first** template
  found from the given paths in the array, skipping nonexistent files.

The function returns `undef` if none of the given paths were found.


Signature 1

`find_template(String *$paths)`

Signature 2

`find_template(Array[String] *$paths_array)`

## `flatten`

Returns a flat Array produced from its possibly deeply nested given arguments.

One or more arguments of any data type can be given to this function.
The result is always a flat array representation where any nested arrays are recursively flattened.

```puppet
flatten(['a', ['b', ['c']]])
# Would return: ['a','b','c']
```

To flatten other kinds of iterables (for example hashes, or intermediate results like from a `reverse_each`)
first convert the result to an array using `Array($x)`, or `$x.convert_to(Array)`. See the `new` function
for details and options when performing a conversion.

```puppet
$hsh = { a => 1, b => 2}

# -- without conversion
$hsh.flatten()
# Would return [{a => 1, b => 2}]

# -- with conversion
$hsh.convert_to(Array).flatten()
# Would return [a,1,b,2]

flatten(Array($hsh))
# Would also return [a,1,b,2]
```

```puppet
$a1 = [1, [2, 3]]
$a2 = [[4,[5,6]]
$x = 7
flatten($a1, $a2, $x)
# would return [1,2,3,4,5,6,7]
```

```puppet
flatten(42)
# Would return [42]

flatten([42])
# Would also return [42]
```


`flatten(Any *$args)`

## `floor`

Returns the largest `Integer` less or equal to the argument.
Takes a single numeric value as an argument.

This function is backwards compatible with the same function in stdlib
and accepts a `Numeric` value. A `String` that can be converted
to a floating point number can also be used in this version - but this
is deprecated.

In general convert string input to `Numeric` before calling this function
to have full control over how the conversion is done.


Signature 1

`floor(Numeric $val)`

Signature 2

`floor(String $val)`

## `fqdn_rand`

Usage: `fqdn_rand(MAX, [SEED], [DOWNCASE])`. MAX is required and must be a positive
integer; SEED is optional and may be any number or string; DOWNCASE is optional
and should be a boolean true or false.

Generates a random Integer number greater than or equal to 0 and less than MAX,
combining the `$fqdn` fact and the value of SEED for repeatable randomness.
(That is, each node will get a different random number from this function, but
a given node's result will be the same every time unless its hostname changes.) If
DOWNCASE is true, then the `fqdn` fact will be downcased when computing the value
so that the result is not sensitive to the case of the `fqdn` fact.

This function is usually used for spacing out runs of resource-intensive cron
tasks that run on many nodes, which could cause a thundering herd or degrade
other services if they all fire at once. Adding a SEED can be useful when you
have more than one such task and need several unrelated random numbers per
node. (For example, `fqdn_rand(30)`, `fqdn_rand(30, 'expensive job 1')`, and
`fqdn_rand(30, 'expensive job 2')` will produce totally different numbers.)


`fqdn_rand()`

## `generate`

Calls an external command on the Puppet master and returns
the results of the command. Any arguments are passed to the external command as
arguments. If the generator does not exit with return code of 0,
the generator is considered to have failed and a parse error is
thrown. Generators can only have file separators, alphanumerics, dashes,
and periods in them. This function will attempt to protect you from
malicious generator calls (e.g., those with '..' in them), but it can
never be entirely safe. No subshell is used to execute
generators, so all shell metacharacters are passed directly to
the generator, and all metacharacters are returned by the function.
Consider cleaning white space from any string generated.


`generate()`

## `get`

Digs into a value with dot notation to get a value from within a structure.

**To dig into a given value**, call the function with (at least) two arguments:

* The **first** argument must be an Array, or Hash. Value can also be `undef`
  (which also makes the result `undef` unless a _default value_ is given).
* The **second** argument must be a _dot notation navigation string_.
* The **optional third** argument can be any type of value and it is used
  as the _default value_ if the function would otherwise return `undef`.
* An **optional lambda** for error handling taking one `Error` argument.

**Dot notation navigation string** -
The dot string consists of period `.` separated segments where each
segment is either the index into an array or the value of a hash key.
If a wanted key contains a period it must be quoted to avoid it being
taken as a segment separator. Quoting can be done with either
single quotes `'` or double quotes `"`. If a segment is
a decimal number it is converted to an Integer index. This conversion
can be prevented by quoting the value.

```puppet
#get($facts, 'os.family')
$facts.get('os.family')
```
Would both result in the value of `$facts['os']['family']`

```puppet
get([1,2,[{'name' =>'waldo'}]], '2.0.name')
```
Would result in `'waldo'`

```puppet
get([1,2,[{'name' =>'waldo'}]], '2.1.name', 'not waldo')

```
Would result in `'not waldo'`

```puppet
$x = [1, 2, { 'readme.md' => "This is a readme."}]
$x.get('2."readme.md"')
```

```puppet
$x = [1, 2, { '10' => "ten"}]
$x.get('2."0"')
```

**Error Handling** - There are two types of common errors that can
be handled by giving the function a code block to execute.
(A third kind or error; when the navigation string has syntax errors
(for example an empty segment or unbalanced quotes) will always raise
an error).

The given block will be given an instance of the `Error` data type,
and it has methods to extract `msg`, `issue_code`, `kind`, and
`details`.

The `msg` will be a preformatted message describing the error.
This is the error message that would have surfaced if there was
no block to handle the error.

The `kind` is the string `'SLICE_ERROR'` for both kinds of errors,
and the `issue_code` is either the string `'EXPECTED_INTEGER_INDEX'`
for an attempt to index into an array with a String,
or `'EXPECTED_COLLECTION'` for an attempt to index into something that
is not a Collection.

The `details` is a Hash that for both issue codes contain the
entry `'walked_path'` which is an Array with each key in the
progression of the dig up to the place where the error occurred.

For an `EXPECTED_INTEGER_INDEX`-issue the detail `'index_type'` is
set to the data type of the index value and for an
`'EXPECTED_COLLECTION'`-issue the detail `'value_type'` is set
to the type of the value.

The logic in the error handling block can inspect the details,
and either call `fail()` with a custom error message or produce
the wanted value.

If the block produces `undef` it will not be replaced with a
given default value.

```puppet
$x = 'blue'
$x.get('0.color', 'green') |$error| { undef } # result is undef

$y = ['blue']
$y.get('color', 'green') |$error| { undef } # result is undef
```

```puppet
$x = [1, 2, ['blue']]
$x.get('2.color') |$error| {
  notice("Walked path is ${error.details['walked_path']}")
}
```
Would notice `Walked path is [2, color]`

Also see:
* `getvar()` that takes the first segment to be the name of a variable
  and then delegates to this function.
* `dig()` function which is similar but uses an
  array of navigation values instead of a dot notation string.


`get(Any $value, String $dotted_string, Optional[Any] $default_value, Optional[Callable[1,1]] &$block)`

## `getvar`

Digs into a variable with dot notation to get a value from a structure.

**To get the value from a variable** (that may or may not exist), call the function with
one or two arguments:

* The **first** argument must be a string, and must start with a variable name without leading `$`,
  for example `get('facts')`. The variable name can be followed
  by a _dot notation navigation string_ to dig out a value in the array or hash value
  of the variable.
* The **optional second** argument can be any type of value and it is used as the
  _default value_ if the function would otherwise return `undef`.
* An **optional lambda** for error handling taking one `Error` argument.

**Dot notation navigation string** -
The dot string consists of period `.` separated segments where each
segment is either the index into an array or the value of a hash key.
If a wanted key contains a period it must be quoted to avoid it being
taken as a segment separator. Quoting can be done with either
single quotes `'` or double quotes `"`. If a segment is
a decimal number it is converted to an Integer index. This conversion
can be prevented by quoting the value.

```puppet
getvar('facts') # results in the value of $facts
```

```puppet
getvar('facts.os.family') # results in the value of $facts['os']['family']
```

```puppet
$x = [1,2,[{'name' =>'waldo'}]]
getvar('x.2.1.name', 'not waldo')
# results in 'not waldo'
```

For further examples and how to perform error handling, see the `get()` function
which this function delegates to after having resolved the variable value.


`getvar(Pattern[/\A(?:::)?(?:[a-z]\w*::)*[a-z_]\w*(?:\.|\Z)/] $get_string, Optional[Any] $default_value, Optional[Callable[1,1]] &$block)`

## `group_by`

Groups the collection by result of the block. Returns a hash where the keys are the evaluated result from the block
and the values are arrays of elements in the collection that correspond to the key.


Signature 1

`group_by(Collection $collection, Callable[1,1] &$block)`

### Parameters


* `collection` --- A collection of things to group.

Return type(s): `Hash`. 


### Examples

Group array of strings by length, results in e.g. `{ 1 => [a, b], 2 => [ab] }`

```puppet
[a, b, ab].group_by |$s| { $s.length }
```

Group array of strings by length and index, results in e.g. `{1 => ['a'], 2 => ['b', 'ab']}`

```puppet
[a, b, ab].group_by |$i, $s| { $i%2 + $s.length }
```

Group hash iterating by key-value pair, results in e.g. `{ 2 => [['a', [1, 2]]], 1 => [['b', [1]]] }`

```puppet
{ a => [1, 2], b => [1] }.group_by |$kv| { $kv[1].length }
```

Group hash iterating by key and value, results in e.g. `{ 2 => [['a', [1, 2]]], 1 => [['b', [1]]] }`

```puppet
 { a => [1, 2], b => [1] }.group_by |$k, $v| { $v.length }
```


Signature 2

`group_by(Array $array, Callable[2,2] &$block)`

Signature 3

`group_by(Collection $collection, Callable[2,2] &$block)`

## `hiera`

Performs a standard priority lookup of the hierarchy and returns the most specific value
for a given key. The returned value can be any type of data.

This function is deprecated in favor of the `lookup` function. While this function
continues to work, it does **not** support:
* `lookup_options` stored in the data
* lookup across global, environment, and module layers

The function takes up to three arguments, in this order:

1. A string key that Hiera searches for in the hierarchy. **Required**.
2. An optional default value to return if Hiera doesn't find anything matching the key.
    * If this argument isn't provided and this function results in a lookup failure, Puppet
    fails with a compilation error.
3. The optional name of an arbitrary
[hierarchy level](https://puppet.com/docs/hiera/latest/hierarchy.html) to insert at the
top of the hierarchy. This lets you temporarily modify the hierarchy for a single lookup.
    * If Hiera doesn't find a matching key in the overriding hierarchy level, it continues
    searching the rest of the hierarchy.

The `hiera` function does **not** find all matches throughout a hierarchy, instead
returning the first specific value starting at the top of the hierarchy. To search
throughout a hierarchy, use the `hiera_array` or `hiera_hash` functions.

```yaml
# Assuming hiera.yaml
# :hierarchy:
#   - web01.example.com
#   - common

# Assuming web01.example.com.yaml:
# users:
#   - "Amy Barry"
#   - "Carrie Douglas"

# Assuming common.yaml:
users:
  admins:
    - "Edith Franklin"
    - "Ginny Hamilton"
  regular:
    - "Iris Jackson"
    - "Kelly Lambert"
```

```puppet
# Assuming we are not web01.example.com:

$users = hiera('users', undef)

# $users contains {admins  => ["Edith Franklin", "Ginny Hamilton"],
#                  regular => ["Iris Jackson", "Kelly Lambert"]}
```

You can optionally generate the default value with a
[lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html) that
takes one parameter.

```puppet
# Assuming the same Hiera data as the previous example:

$users = hiera('users') | $key | { "Key \'${key}\' not found" }

# $users contains {admins  => ["Edith Franklin", "Ginny Hamilton"],
#                  regular => ["Iris Jackson", "Kelly Lambert"]}
# If hiera couldn't match its key, it would return the lambda result,
# "Key 'users' not found".
```

The returned value's data type depends on the types of the results. In the example
above, Hiera matches the 'users' key and returns it as a hash.

See
[the 'Using the lookup function' documentation](https://puppet.com/docs/puppet/latest/hiera_automatic.html) for how to perform lookup of data.
Also see
[the 'Using the deprecated hiera functions' documentation](https://puppet.com/docs/puppet/latest/hiera_automatic.html)
for more information about the Hiera 3 functions.


`hiera()`

## `hiera_array`

Finds all matches of a key throughout the hierarchy and returns them as a single flattened
array of unique values. If any of the matched values are arrays, they're flattened and
included in the results. This is called an
[array merge lookup](https://puppet.com/docs/hiera/latest/lookup_types.html#array-merge).

This function is deprecated in favor of the `lookup` function. While this function
continues to work, it does **not** support:
* `lookup_options` stored in the data
* lookup across global, environment, and module layers

The `hiera_array` function takes up to three arguments, in this order:

1. A string key that Hiera searches for in the hierarchy. **Required**.
2. An optional default value to return if Hiera doesn't find anything matching the key.
    * If this argument isn't provided and this function results in a lookup failure, Puppet
    fails with a compilation error.
3. The optional name of an arbitrary
[hierarchy level](https://puppet.com/docs/hiera/latest/hierarchy.html) to insert at the
top of the hierarchy. This lets you temporarily modify the hierarchy for a single lookup.
    * If Hiera doesn't find a matching key in the overriding hierarchy level, it continues
    searching the rest of the hierarchy.

```yaml
# Assuming hiera.yaml
# :hierarchy:
#   - web01.example.com
#   - common

# Assuming common.yaml:
# users:
#   - 'cdouglas = regular'
#   - 'efranklin = regular'

# Assuming web01.example.com.yaml:
# users: 'abarry = admin'
```

```puppet
$allusers = hiera_array('users', undef)

# $allusers contains ["cdouglas = regular", "efranklin = regular", "abarry = admin"].
```

You can optionally generate the default value with a
[lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html) that
takes one parameter.

```puppet
# Assuming the same Hiera data as the previous example:

$allusers = hiera_array('users') | $key | { "Key \'${key}\' not found" }

# $allusers contains ["cdouglas = regular", "efranklin = regular", "abarry = admin"].
# If hiera_array couldn't match its key, it would return the lambda result,
# "Key 'users' not found".
```

`hiera_array` expects that all values returned will be strings or arrays. If any matched
value is a hash, Puppet raises a type mismatch error.

See
[the 'Using the lookup function' documentation](https://puppet.com/docs/puppet/latest/hiera_automatic.html) for how to perform lookup of data.
Also see
[the 'Using the deprecated hiera functions' documentation](https://puppet.com/docs/puppet/latest/hiera_automatic.html)
for more information about the Hiera 3 functions.


`hiera_array()`

## `hiera_hash`

Finds all matches of a key throughout the hierarchy and returns them in a merged hash.

This function is deprecated in favor of the `lookup` function. While this function
continues to work, it does **not** support:
* `lookup_options` stored in the data
* lookup across global, environment, and module layers

If any of the matched hashes share keys, the final hash uses the value from the
highest priority match. This is called a
[hash merge lookup](https://puppet.com/docs/hiera/latest/lookup_types.html#hash-merge).

The merge strategy is determined by Hiera's
[`:merge_behavior`](https://puppet.com/docs/hiera/latest/configuring.html#mergebehavior)
setting.

The `hiera_hash` function takes up to three arguments, in this order:

1. A string key that Hiera searches for in the hierarchy. **Required**.
2. An optional default value to return if Hiera doesn't find anything matching the key.
    * If this argument isn't provided and this function results in a lookup failure, Puppet
    fails with a compilation error.
3. The optional name of an arbitrary
[hierarchy level](https://puppet.com/docs/hiera/latest/hierarchy.html) to insert at the
top of the hierarchy. This lets you temporarily modify the hierarchy for a single lookup.
    * If Hiera doesn't find a matching key in the overriding hierarchy level, it continues
    searching the rest of the hierarchy.

```yaml
# Assuming hiera.yaml
# :hierarchy:
#   - web01.example.com
#   - common

# Assuming common.yaml:
# users:
#   regular:
#     'cdouglas': 'Carrie Douglas'

# Assuming web01.example.com.yaml:
# users:
#   administrators:
#     'aberry': 'Amy Berry'
```

```puppet
# Assuming we are not web01.example.com:

$allusers = hiera_hash('users', undef)

# $allusers contains {regular => {"cdouglas" => "Carrie Douglas"},
#                     administrators => {"aberry" => "Amy Berry"}}
```

You can optionally generate the default value with a
[lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html) that
takes one parameter.

```puppet
# Assuming the same Hiera data as the previous example:

$allusers = hiera_hash('users') | $key | { "Key \'${key}\' not found" }

# $allusers contains {regular => {"cdouglas" => "Carrie Douglas"},
#                     administrators => {"aberry" => "Amy Berry"}}
# If hiera_hash couldn't match its key, it would return the lambda result,
# "Key 'users' not found".
```

`hiera_hash` expects that all values returned will be hashes. If any of the values
found in the data sources are strings or arrays, Puppet raises a type mismatch error.

See
[the 'Using the lookup function' documentation](https://puppet.com/docs/puppet/latest/hiera_automatic.html) for how to perform lookup of data.
Also see
[the 'Using the deprecated hiera functions' documentation](https://puppet.com/docs/puppet/latest/hiera_automatic.html)
for more information about the Hiera 3 functions.


`hiera_hash()`

## `hiera_include`

Assigns classes to a node using an
[array merge lookup](https://puppet.com/docs/hiera/latest/lookup_types.html#array-merge)
that retrieves the value for a user-specified key from Hiera's data.

This function is deprecated in favor of the `lookup` function in combination with `include`.
While this function continues to work, it does **not** support:
* `lookup_options` stored in the data
* lookup across global, environment, and module layers

```puppet
# In site.pp, outside of any node definitions and below any top-scope variables:
lookup('classes', Array[String], 'unique').include
```

The `hiera_include` function requires:

- A string key name to use for classes.
- A call to this function (i.e. `hiera_include('classes')`) in your environment's
`sites.pp` manifest, outside of any node definitions and below any top-scope variables
that Hiera uses in lookups.
- `classes` keys in the appropriate Hiera data sources, with an array for each
`classes` key and each value of the array containing the name of a class.

The function takes up to three arguments, in this order:

1. A string key that Hiera searches for in the hierarchy. **Required**.
2. An optional default value to return if Hiera doesn't find anything matching the key.
    * If this argument isn't provided and this function results in a lookup failure, Puppet
    fails with a compilation error.
3. The optional name of an arbitrary
[hierarchy level](https://puppet.com/docs/hiera/latest/hierarchy.html) to insert at the
top of the hierarchy. This lets you temporarily modify the hierarchy for a single lookup.
    * If Hiera doesn't find a matching key in the overriding hierarchy level, it continues
    searching the rest of the hierarchy.

The function uses an
[array merge lookup](https://puppet.com/docs/hiera/latest/lookup_types.html#array-merge)
to retrieve the `classes` array, so every node gets every class from the hierarchy.

```yaml
# Assuming hiera.yaml
# :hierarchy:
#   - web01.example.com
#   - common

# Assuming web01.example.com.yaml:
# classes:
#   - apache::mod::php

# Assuming common.yaml:
# classes:
#   - apache
```

```puppet
# In site.pp, outside of any node definitions and below any top-scope variables:
hiera_include('classes', undef)

# Puppet assigns the apache and apache::mod::php classes to the web01.example.com node.
```

You can optionally generate the default value with a
[lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html) that
takes one parameter.

```puppet
# Assuming the same Hiera data as the previous example:

# In site.pp, outside of any node definitions and below any top-scope variables:
hiera_include('classes') | $key | {"Key \'${key}\' not found" }

# Puppet assigns the apache and apache::mod::php classes to the web01.example.com node.
# If hiera_include couldn't match its key, it would return the lambda result,
# "Key 'classes' not found".
```

See
[the 'Using the lookup function' documentation](https://puppet.com/docs/puppet/latest/hiera_automatic.html) for how to perform lookup of data.
Also see
[the 'Using the deprecated hiera functions' documentation](https://puppet.com/docs/puppet/latest/hiera_automatic.html)
for more information about the Hiera 3 functions.


`hiera_include()`

## `hocon_data`

The `hocon_data` is a hiera 5 `data_hash` data provider function.
See [the configuration guide documentation](https://puppet.com/docs/puppet/latest/hiera_config_yaml_5.html#configuring-a-hierarchy-level-built-in-backends) for
how to use this function.

Note that this function is not supported without a hocon library being present.


`hocon_data(Struct[{path=>String[1]}] $options, Puppet::LookupContext $context)`

## `import`

The import function raises an error when called to inform the user that import is no longer supported.


`import(Any *$args)`

## `include`

Declares one or more classes, causing the resources in them to be
evaluated and added to the catalog. Accepts a class name, an array of class
names, or a comma-separated list of class names.

The `include` function can be used multiple times on the same class and will
only declare a given class once. If a class declared with `include` has any
parameters, Puppet will automatically look up values for them in Hiera, using
`<class name>::<parameter name>` as the lookup key.

Contrast this behavior with resource-like class declarations
(`class {'name': parameter => 'value',}`), which must be used in only one place
per class and can directly set parameters. You should avoid using both `include`
and resource-like declarations with the same class.

The `include` function does not cause classes to be contained in the class
where they are declared. For that, see the `contain` function. It also
does not create a dependency relationship between the declared class and the
surrounding class; for that, see the `require` function.

You must use the class's full name;
relative names are not allowed. In addition to names in string form,
you may also directly use `Class` and `Resource` `Type`-values that are produced by
the resource and relationship expressions.

- Since < 3.0.0
- Since 4.0.0 support for class and resource type values, absolute names
- Since 4.7.0 returns an `Array[Type[Class]]` of all included classes


`include(Any *$names)`

## `index`

Returns the index (or key in a hash) to a first-found value in an `Iterable` value.

When called with a  [lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html)
the lambda is called repeatedly using each value in a data structure until the lambda returns a "truthy" value which
makes the function return the index or key, or if the end of the iteration is reached, undef is returned.

This function can be called in two different ways; with a value to be searched for, or with
a lambda that determines if an entry in the iterable matches.

When called with a lambda the function takes two mandatory arguments, in this order:

1. An array, hash, string, or other iterable object that the function will iterate over.
2. A lambda, which the function calls for each element in the first argument. It can request one (value) or two (index/key, value) parameters.

`$data.index |$parameter| { <PUPPET CODE BLOCK> }`

or

`index($data) |$parameter| { <PUPPET CODE BLOCK> }`

```puppet
$data = ["routers", "servers", "workstations"]
notice $data.index |$value| { $value == 'servers' } # notices 1
notice $data.index |$value| { $value == 'hosts'  }  # notices undef
```

```puppet
$data = {types => ["routers", "servers", "workstations"], colors => ['red', 'blue', 'green']}
notice $data.index |$value| { 'servers' in $value } # notices 'types'
notice $data.index |$value| { 'red' in $value }     # notices 'colors'
```
Note that the lambda gets the value and not an array with `[key, value]` as in other
iterative functions.

Using a lambda that accepts two values works the same way. The lambda gets the index/key
as the first parameter and the value as the second parameter.

```puppet
# Find the first even numbered index that has a non String value
$data = [key1, 1, 3, 5]
notice $data.index |$idx, $value| { $idx % 2 == 0 and $value !~ String } # notices 2
```

When called on a `String`, the lambda is given each character as a value. What is typically wanted is to
find a sequence of characters which is achieved by calling the function with a value to search for instead
of giving a lambda.


```puppet
# Find first occurrence of 'ah'
$data = "blablahbleh"
notice $data.index('ah') # notices 5
```

```puppet
# Find first occurrence of 'la' or 'le'
$data = "blablahbleh"
notice $data.index(/l(a|e)/ # notices 1
```

When searching in a `String` with a given value that is neither `String` nor `Regexp` the answer is always `undef`.
When searching in any other iterable, the value is matched against each value in the iteration using strict
Ruby `==` semantics. If Puppet Language semantics are wanted (where string compare is case insensitive) use a
lambda and the `==` operator in Puppet.

```puppet
$data = ['routers', 'servers', 'WORKstations']
notice $data.index('servers')      # notices 1
notice $data.index('workstations') # notices undef (not matching case)
```

For an general examples that demonstrates iteration, see the Puppet
[iteration](https://puppet.com/docs/puppet/latest/lang_iteration.html)
documentation.


Signature 1

`index(Hash[Any, Any] $hash, Callable[2,2] &$block)`

Signature 2

`index(Hash[Any, Any] $hash, Callable[1,1] &$block)`

Signature 3

`index(Iterable $enumerable, Callable[2,2] &$block)`

Signature 4

`index(Iterable $enumerable, Callable[1,1] &$block)`

Signature 5

`index(String $str, Variant[String,Regexp] $match)`

Signature 6

`index(Iterable $enumerable, Any $match)`

## `info`

Logs a message on the server at level `info`.


`info(Any *$values)`

### Parameters


* `*values` --- The values to log.

Return type(s): `Undef`. 

## `inline_epp`

Evaluates an Embedded Puppet (EPP) template string and returns the rendered
text result as a String.

`inline_epp('<EPP TEMPLATE STRING>', <PARAMETER HASH>)`

The first argument to this function should be a string containing an EPP
template. In most cases, the last argument is optional; if used, it should be a
[hash](https://puppet.com/docs/puppet/latest/lang_data_hash.html) that contains parameters to
pass to the template.

- See the [template](https://puppet.com/docs/puppet/latest/lang_template.html)
documentation for general template usage information.
- See the [EPP syntax](https://puppet.com/docs/puppet/latest/lang_template_epp.html)
documentation for examples of EPP.

For example, to evaluate an inline EPP template and pass it the `docroot` and
`virtual_docroot` parameters, call the `inline_epp` function like this:

`inline_epp('docroot: <%= $docroot %> Virtual docroot: <%= $virtual_docroot %>',
{ 'docroot' => '/var/www/html', 'virtual_docroot' => '/var/www/example' })`

Puppet produces a syntax error if you pass more parameters than are declared in
the template's parameter tag. When passing parameters to a template that
contains a parameter tag, use the same names as the tag's declared parameters.

Parameters are required only if they are declared in the called template's
parameter tag without default values. Puppet produces an error if the
`inline_epp` function fails to pass any required parameter.

An inline EPP template should be written as a single-quoted string or
[heredoc](https://puppet.com/docs/puppet/latest/lang_data_string.html#heredocs).
A double-quoted string is subject to expression interpolation before the string
is parsed as an EPP template.

For example, to evaluate an inline EPP template using a heredoc, call the
`inline_epp` function like this:

```puppet
# Outputs 'Hello given argument planet!'
inline_epp(@(END), { x => 'given argument' })
<%- | $x, $y = planet | -%>
Hello <%= $x %> <%= $y %>!
END
```


`inline_epp(String $template, Optional[Hash[Pattern[/^\w+$/], Any]] $parameters)`

## `inline_template`

Evaluate a template string and return its value.  See
[the templating docs](https://puppet.com/docs/puppet/latest/lang_template.html) for
more information. Note that if multiple template strings are specified, their
output is all concatenated and returned as the output of the function.


`inline_template()`

## `join`

Joins the values of an Array into a string with elements separated by a delimiter.

Supports up to two arguments
* **values** - first argument is required and must be an an `Array`
* **delimiter** - second arguments is the delimiter between elements, must be a `String` if given, and defaults to an empty string.

```puppet
join(['a','b','c'], ",")
# Would result in: "a,b,c"
```

Note that array is flattened before elements are joined, but flattening does not extend to arrays nested in hashes or other objects.

```puppet
$a = [1,2, undef, 'hello', [x,y,z], {a => 2, b => [3, 4]}]
notice join($a, ', ')

# would result in noticing:
# 1, 2, , hello, x, y, z, {"a"=>2, "b"=>[3, 4]}
```

For joining iterators and other containers of elements a conversion must first be made to
an `Array`. The reason for this is that there are many options how such a conversion should
be made.

```puppet
[1,2,3].reverse_each.convert_to(Array).join(', ')
# would result in: "3, 2, 1"
```
```puppet
{a => 1, b => 2}.convert_to(Array).join(', ')
# would result in "a, 1, b, 2"
```

For more detailed control over the formatting (including indentations and line breaks, delimiters around arrays
and hash entries, between key/values in hash entries, and individual formatting of values in the array)
see the `new` function for `String` and its formatting options for `Array` and `Hash`.


`join(Array $arg, Optional[String] $delimiter)`

## `json_data`

The `json_data` is a hiera 5 `data_hash` data provider function.
See [the configuration guide documentation](https://puppet.com/docs/puppet/latest/hiera_config_yaml_5.html#configuring-a-hierarchy-level-built-in-backends) for
how to use this function.


`json_data(Struct[{path=>String[1]}] $options, Puppet::LookupContext $context)`

## `keys`

Returns the keys of a hash as an Array

```puppet
$hsh = {"apples" => 3, "oranges" => 4 }
$hsh.keys()
keys($hsh)
# both results in the array ["apples", "oranges"]
```

* Note that a hash in the puppet language accepts any data value (including `undef`) unless
  it is constrained with a `Hash` data type that narrows the allowed data types.
* For an empty hash, an empty array is returned.
* The order of the keys is the same as the order in the hash (typically the order in which they were added).


`keys(Hash $hsh)`

## `length`

Returns the length of an Array, Hash, String, or Binary value.

The returned value is a positive integer indicating the number
of elements in the container; counting (possibly multibyte) characters for a `String`,
bytes in a `Binary`, number of elements in an `Array`, and number of
key-value associations in a Hash.

```puppet
"roses".length()        # 5
length("violets")       # 7
[10, 20].length         # 2
{a => 1, b => 3}.length # 2
```


Signature 1

`length(Collection $arg)`

Signature 2

`length(String $arg)`

Signature 3

`length(Binary $arg)`

## `lest`

Calls a [lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html)
without arguments if the value given to `lest` is `undef`.
Returns the result of calling the lambda if the argument is `undef`, otherwise the
given argument.

The `lest` function is useful in a chain of `then` calls, or in general
as a guard against `undef` values. The function can be used to call `fail`, or to
return a default value.

These two expressions are equivalent:

```puppet
if $x == undef { do_things() }
lest($x) || { do_things() }
```

```puppet
$data = {a => [ b, c ] }
notice $data.dig(a, b, c)
 .then |$x| { $x * 2 }
 .lest || { fail("no value for $data[a][b][c]" }
```

Would fail the operation because `$data[a][b][c]` results in `undef`
(there is no `b` key in `a`).

In contrast - this example:

```puppet
$data = {a => { b => { c => 10 } } }
notice $data.dig(a, b, c)
 .then |$x| { $x * 2 }
 .lest || { fail("no value for $data[a][b][c]" }
```

Would notice the value `20`


`lest(Any $arg, Callable[0,0] &$block)`

## `lookup`

Uses the Puppet lookup system to retrieve a value for a given key. By default,
this returns the first value found (and fails compilation if no values are
available), but you can configure it to merge multiple values into one, fail
gracefully, and more.

When looking up a key, Puppet will search up to three tiers of data, in the
following order:

1. Hiera.
2. The current environment's data provider.
3. The indicated module's data provider, if the key is of the form
   `<MODULE NAME>::<SOMETHING>`.

### Arguments

You must provide the name of a key to look up, and can optionally provide other
arguments. You can combine these arguments in the following ways:

* `lookup( <NAME>, [<VALUE TYPE>], [<MERGE BEHAVIOR>], [<DEFAULT VALUE>] )`
* `lookup( [<NAME>], <OPTIONS HASH> )`
* `lookup( as above ) |$key| { # lambda returns a default value }`

Arguments in `[square brackets]` are optional.

The arguments accepted by `lookup` are as follows:

1. `<NAME>` (string or array) --- The name of the key to look up.
    * This can also be an array of keys. If Puppet doesn't find anything for the
    first key, it will try again with the subsequent ones, only resorting to a
    default value if none of them succeed.
2. `<VALUE TYPE>` (data type) --- A
[data type](https://puppet.com/docs/puppet/latest/lang_data_type.html)
that must match the retrieved value; if not, the lookup (and catalog
compilation) will fail. Defaults to `Data` (accepts any normal value).
3. `<MERGE BEHAVIOR>` (string or hash; see **"Merge Behaviors"** below) ---
Whether (and how) to combine multiple values. If present, this overrides any
merge behavior specified in the data sources. Defaults to no value; Puppet will
use merge behavior from the data sources if present, and will otherwise do a
first-found lookup.
4. `<DEFAULT VALUE>` (any normal value) --- If present, `lookup` returns this
when it can't find a normal value. Default values are never merged with found
values. Like a normal value, the default must match the value type. Defaults to
no value; if Puppet can't find a normal value, the lookup (and compilation) will
fail.
5. `<OPTIONS HASH>` (hash) --- Alternate way to set the arguments above, plus
some less-common extra options. If you pass an options hash, you can't combine
it with any regular arguments (except `<NAME>`). An options hash can have the
following keys:
    * `'name'` --- Same as `<NAME>` (argument 1). You can pass this as an
    argument or in the hash, but not both.
    * `'value_type'` --- Same as `<VALUE TYPE>` (argument 2).
    * `'merge'` --- Same as `<MERGE BEHAVIOR>` (argument 3).
    * `'default_value'` --- Same as `<DEFAULT VALUE>` (argument 4).
    * `'default_values_hash'` (hash) --- A hash of lookup keys and default
    values. If Puppet can't find a normal value, it will check this hash for the
    requested key before giving up. You can combine this with `default_value` or
    a lambda, which will be used if the key isn't present in this hash. Defaults
    to an empty hash.
    * `'override'` (hash) --- A hash of lookup keys and override values. Puppet
    will check for the requested key in the overrides hash _first;_ if found, it
    returns that value as the _final_ value, ignoring merge behavior. Defaults
    to an empty hash.

Finally, `lookup` can take a lambda, which must accept a single parameter.
This is yet another way to set a default value for the lookup; if no results are
found, Puppet will pass the requested key to the lambda and use its result as
the default value.

### Merge Behaviors

Puppet lookup uses a hierarchy of data sources, and a given key might have
values in multiple sources. By default, Puppet returns the first value it finds,
but it can also continue searching and merge all the values together.

> **Note:** Data sources can use the special `lookup_options` metadata key to
request a specific merge behavior for a key. The `lookup` function will use that
requested behavior unless you explicitly specify one.

The valid merge behaviors are:

* `'first'` --- Returns the first value found, with no merging. Puppet lookup's
default behavior.
* `'unique'` (called "array merge" in classic Hiera) --- Combines any number of
arrays and scalar values to return a merged, flattened array with all duplicate
values removed. The lookup will fail if any hash values are found.
* `'hash'` --- Combines the keys and values of any number of hashes to return a
merged hash. If the same key exists in multiple source hashes, Puppet will use
the value from the highest-priority data source; it won't recursively merge the
values.
* `'deep'` --- Combines the keys and values of any number of hashes to return a
merged hash. If the same key exists in multiple source hashes, Puppet will
recursively merge hash or array values (with duplicate values removed from
arrays). For conflicting scalar values, the highest-priority value will win.
* `{'strategy' => 'first'}`, `{'strategy' => 'unique'}`,
or `{'strategy' => 'hash'}` --- Same as the string versions of these merge behaviors.
* `{'strategy' => 'deep', <DEEP OPTION> => <VALUE>, ...}` --- Same as `'deep'`,
but can adjust the merge with additional options. The available options are:
    * `'knockout_prefix'` (string) --- A string prefix to indicate a
    value should be _removed_ from the final result. If a value is exactly equal
    to the prefix, it will knockout the entire element. Defaults to `undef`, which
    disables this feature.
    * `'sort_merged_arrays'` (boolean) --- Whether to sort all arrays that are
    merged together. Defaults to `false`.
    * `'merge_hash_arrays'` (boolean) --- Whether to merge hashes within arrays.
    Defaults to `false`.


Signature 1

`lookup(NameType $name, Optional[ValueType] $value_type, Optional[MergeType] $merge)`

Signature 2

`lookup(NameType $name, Optional[ValueType] $value_type, Optional[MergeType] $merge, DefaultValueType $default_value)`

Signature 3

`lookup(NameType $name, Optional[ValueType] $value_type, Optional[MergeType] $merge, BlockType &$block)`

Signature 4

`lookup(OptionsWithName $options_hash, Optional[BlockType] &$block)`

Signature 5

`lookup(Variant[String,Array[String]] $name, OptionsWithoutName $options_hash, Optional[BlockType] &$block)`

## `lstrip`

Strips leading spaces from a String

This function is compatible with the stdlib function with the same name.

The function does the following:
* For a `String` the conversion removes all leading ASCII white space characters such as space, tab, newline, and return.
  It does not remove other space-like characters like hard space (Unicode U+00A0). (Tip, `/^[[:space:]]/` regular expression
  matches all space-like characters).
* For an `Iterable[Variant[String, Numeric]]` (for example an `Array`) each value is processed and the conversion is not recursive.
* If the value is `Numeric` it is simply returned (this is for backwards compatibility).
* An error is raised for all other data types.

```puppet
"\n\thello ".lstrip()
lstrip("\n\thello ")
```
Would both result in `"hello"`

```puppet
["\n\thello ", "\n\thi "].lstrip()
lstrip(["\n\thello ", "\n\thi "])
```
Would both result in `['hello', 'hi']`


Signature 1

`lstrip(Numeric $arg)`

Signature 2

`lstrip(String $arg)`

Signature 3

`lstrip(Iterable[Variant[String, Numeric]] $arg)`

## `map`

Applies a [lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html)
to every value in a data structure and returns an array containing the results.

This function takes two mandatory arguments, in this order:

1. An array, hash, or other iterable object that the function will iterate over.
2. A lambda, which the function calls for each element in the first argument. It can
request one or two parameters.

`$transformed_data = $data.map |$parameter| { <PUPPET CODE BLOCK> }`

or

`$transformed_data = map($data) |$parameter| { <PUPPET CODE BLOCK> }`

When the first argument (`$data` in the above example) is an array, Puppet passes each
value in turn to the lambda.

```puppet
# For the array $data, return an array containing each value multiplied by 10
$data = [1,2,3]
$transformed_data = $data.map |$items| { $items * 10 }
# $transformed_data contains [10,20,30]
```

When the first argument is a hash, Puppet passes each key and value pair to the lambda
as an array in the form `[key, value]`.

```puppet
# For the hash $data, return an array containing the keys
$data = {'a'=>1,'b'=>2,'c'=>3}
$transformed_data = $data.map |$items| { $items[0] }
# $transformed_data contains ['a','b','c']
```

When the first argument is an array and the lambda has two parameters, Puppet passes the
array's indexes (enumerated from 0) in the first parameter and its values in the second
parameter.

```puppet
# For the array $data, return an array containing the indexes
$data = [1,2,3]
$transformed_data = $data.map |$index,$value| { $index }
# $transformed_data contains [0,1,2]
```

When the first argument is a hash, Puppet passes its keys to the first parameter and its
values to the second parameter.

```puppet
# For the hash $data, return an array containing each value
$data = {'a'=>1,'b'=>2,'c'=>3}
$transformed_data = $data.map |$key,$value| { $value }
# $transformed_data contains [1,2,3]
```


Signature 1

`map(Hash[Any, Any] $hash, Callable[2,2] &$block)`

Signature 2

`map(Hash[Any, Any] $hash, Callable[1,1] &$block)`

Signature 3

`map(Iterable $enumerable, Callable[2,2] &$block)`

Signature 4

`map(Iterable $enumerable, Callable[1,1] &$block)`

## `match`

Matches a regular expression against a string and returns an array containing the match
and any matched capturing groups.

The first argument is a string or array of strings. The second argument is either a
regular expression, regular expression represented as a string, or Regex or Pattern
data type that the function matches against the first argument.

The returned array contains the entire match at index 0, and each captured group at
subsequent index values. If the value or expression being matched is an array, the
function returns an array with mapped match results.

If the function doesn't find a match, it returns 'undef'.

```puppet
$matches = "abc123".match(/[a-z]+[1-9]+/)
# $matches contains [abc123]
```

```puppet
$matches = "abc123".match(/([a-z]+)([1-9]+)/)
# $matches contains [abc123, abc, 123]
```

```puppet
$matches = ["abc123","def456"].match(/([a-z]+)([1-9]+)/)
# $matches contains [[abc123, abc, 123], [def456, def, 456]]
```


Signature 1

`match(String $string, Variant[Any, Type] $pattern)`

Signature 2

`match(Array[String] $string, Variant[Any, Type] $pattern)`

## `max`

Returns the highest value among a variable number of arguments.
Takes at least one argument.

This function is (with one exception) compatible with the stdlib function
with the same name and performs deprecated type conversion before
comparison as follows:

* If a value converted to String is an optionally '-' prefixed,
  string of digits, one optional decimal point, followed by optional
  decimal digits - then the comparison is performed on the values
  converted to floating point.
* If a value is not considered convertible to float, it is converted
  to a `String` and the comparison is a lexical compare where min is
  the lexicographical later value.
* A lexicographical compare is performed in a system locale - international
  characters may therefore not appear in what a user thinks is the correct order.
* The conversion rules apply to values in pairs - the rule must hold for both
  values - a value may therefore be compared using different rules depending
  on the "other value".
* The returned result found to be the "highest" is the original unconverted value.

The above rules have been deprecated in Puppet 6.0.0 as they produce strange results when
given values of mixed data types. In general, either convert values to be
all `String` or all `Numeric` values before calling the function, or call the
function with a lambda that performs type conversion and comparison. This because one
simply cannot compare `Boolean` with `Regexp` and with any arbitrary `Array`, `Hash` or
`Object` and getting a meaningful result.

The one change in the function's behavior is when the function is given a single
array argument. The stdlib implementation would return that array as the result where
it now instead returns the max value from that array.

```puppet
notice(max(1)) # would notice 1
notice(max(1,2)) # would notice 2
notice(max("1", 2)) # would notice 2
notice(max("0777", 512)) # would notice "0777", since "0777" is not converted from octal form
notice(max(0777, 512)) # would notice 512, since 0777 is decimal 511
notice(max('aa', 'ab')) # would notice 'ab'
notice(max(['a'], ['b'])) # would notice ['b'], since "['b']" is after "['a']"
```

```puppet
$x = [1,2,3,4]
notice(max(*$x)) # would notice 4
```

```puppet
$x = [1,2,3,4]
notice(max($x)) # would notice 4
notice($x.max) # would notice 4
```
This example shows that a single array argument is used as the set of values
as opposed to being a single returned value.

When calling with a lambda, it must accept two variables and it must return
one of -1, 0, or 1 depending on if first argument is before/lower than, equal to,
or higher/after the second argument.

```puppet
notice(max("2", "10", "100") |$a, $b| { compare($a, $b) })
```

Would notice "2" as higher since it is lexicographically higher/after the other values. Without the
lambda the stdlib compatible (deprecated) behavior would have been to return "100" since number conversion
kicks in.


Signature 1

`max(Numeric *$values)`

Signature 2

`max(String *$values)`

Signature 3

`max(Semver *$values)`

Signature 4

`max(Timespan *$values)`

Signature 5

`max(Timestamp *$values)`

Signature 6

`max(Array[Numeric] $values, Optional[Callable[2,2]] &$block)`

Signature 7

`max(Array[String] $values, Optional[Callable[2,2]] &$block)`

Signature 8

`max(Array[Semver] $values, Optional[Callable[2,2]] &$block)`

Signature 9

`max(Array[Timespan] $values, Optional[Callable[2,2]] &$block)`

Signature 10

`max(Array[Timestamp] $values, Optional[Callable[2,2]] &$block)`

Signature 11

`max(Array $values, Optional[Callable[2,2]] &$block)`

Signature 12

`max(Any *$values, Callable[2,2] &$block)`

Signature 13

`max(Any *$values)`

## `md5`

Returns a MD5 hash value from a provided string.


`md5()`

## `min`

Returns the lowest value among a variable number of arguments.
Takes at least one argument.

This function is (with one exception) compatible with the stdlib function
with the same name and performs deprecated type conversion before
comparison as follows:

* If a value converted to String is an optionally '-' prefixed,
  string of digits, one optional decimal point, followed by optional
  decimal digits - then the comparison is performed on the values
  converted to floating point.
* If a value is not considered convertible to float, it is converted
  to a `String` and the comparison is a lexical compare where min is
  the lexicographical earlier value.
* A lexicographical compare is performed in a system locale - international
  characters may therefore not appear in what a user thinks is the correct order.
* The conversion rules apply to values in pairs - the rule must hold for both
  values - a value may therefore be compared using different rules depending
  on the "other value".
* The returned result found to be the "lowest" is the original unconverted value.

The above rules have been deprecated in Puppet 6.0.0 as they produce strange results when
given values of mixed data types. In general, either convert values to be
all `String` or all `Numeric` values before calling the function, or call the
function with a lambda that performs type conversion and comparison. This because one
simply cannot compare `Boolean` with `Regexp` and with any arbitrary `Array`, `Hash` or
`Object` and getting a meaningful result.

The one change in the function's behavior is when the function is given a single
array argument. The stdlib implementation would return that array as the result where
it now instead returns the max value from that array.

```puppet
notice(min(1)) # would notice 1
notice(min(1,2)) # would notice 1
notice(min("1", 2)) # would notice 1
notice(min("0777", 512)) # would notice 512, since "0777" is not converted from octal form
notice(min(0777, 512)) # would notice 511, since 0777 is decimal 511
notice(min('aa', 'ab')) # would notice 'aa'
notice(min(['a'], ['b'])) # would notice ['a'], since "['a']" is before "['b']"
```

```puppet
$x = [1,2,3,4]
notice(min(*$x)) # would notice 1
```

```puppet
$x = [1,2,3,4]
notice(min($x)) # would notice 1
notice($x.min) # would notice 1
```
This example shows that a single array argument is used as the set of values
as opposed to being a single returned value.

When calling with a lambda, it must accept two variables and it must return
one of -1, 0, or 1 depending on if first argument is before/lower than, equal to,
or higher/after the second argument.

```puppet
notice(min("2", "10", "100") |$a, $b| { compare($a, $b) })
```

Would notice "10" as lower since it is lexicographically lower/before the other values. Without the
lambda the stdlib compatible (deprecated) behavior would have been to return "2" since number conversion kicks in.


Signature 1

`min(Numeric *$values)`

Signature 2

`min(String *$values)`

Signature 3

`min(Semver *$values)`

Signature 4

`min(Timespan *$values)`

Signature 5

`min(Timestamp *$values)`

Signature 6

`min(Array[Numeric] $values, Optional[Callable[2,2]] &$block)`

Signature 7

`min(Array[Semver] $values, Optional[Callable[2,2]] &$block)`

Signature 8

`min(Array[Timespan] $values, Optional[Callable[2,2]] &$block)`

Signature 9

`min(Array[Timestamp] $values, Optional[Callable[2,2]] &$block)`

Signature 10

`min(Array[String] $values, Optional[Callable[2,2]] &$block)`

Signature 11

`min(Array $values, Optional[Callable[2,2]] &$block)`

Signature 12

`min(Any *$values, Callable[2,2] &$block)`

Signature 13

`min(Any *$values)`

## `module_directory`

Finds an existing module and returns the path to its root directory.

The argument to this function should be a module name String
For example, the reference `mysql` will search for the
directory `<MODULES DIRECTORY>/mysql` and return the first
found on the modulepath.

This function can also accept:

* Multiple String arguments, which will return the path of the **first** module
 found, skipping non existing modules.
* An array of module names, which will return the path of the **first** module
 found from the given names in the array, skipping non existing modules.

The function returns `undef` if none of the given modules were found


Signature 1

`module_directory(String *$names)`

Signature 2

`module_directory(Array[String] *$names)`

## `new`

Creates a new instance/object of a given data type.

This function makes it possible to create new instances of
concrete data types. If a block is given it is called with the
just created instance as an argument.

Calling this function is equivalent to directly
calling the data type:

```puppet
$a = Integer.new("42")
$b = Integer("42")
```

These would both convert the string `"42"` to the decimal value `42`.

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

```puppet
Integer[0].new("-100")
```

Would fail with an assertion error (since value is less than 0).

The following sections show the arguments and conversion rules
per data type built into the Puppet Type System.

### Conversion to `Optional[T]` and `NotUndef[T]`

Conversion to these data types is the same as a conversion to the type argument `T`.
In the case of `Optional[T]` it is accepted that the argument to convert may be `undef`.
It is however not acceptable to give other arguments (than `undef`) that cannot be
converted to `T`.

### Conversion to Integer

A new `Integer` can be created from `Integer`, `Float`, `Boolean`, and `String` values.
For conversion from `String` it is possible to specify the radix (base).

```puppet
type Radix = Variant[Default, Integer[2,2], Integer[8,8], Integer[10,10], Integer[16,16]]

function Integer.new(
  String $value,
  Radix $radix = 10,
  Boolean $abs = false
)

function Integer.new(
  Variant[Numeric, Boolean] $value,
  Boolean $abs = false
)
```

* When converting from `String` the default radix is 10.
* If radix is not specified an attempt is made to detect the radix from the start of the string:
  * `0b` or `0B` is taken as radix 2.
  * `0x` or `0X` is taken as radix 16.
  * `0` as radix 8.
  * All others are decimal.
* Conversion from `String` accepts an optional sign in the string.
* For hexadecimal (radix 16) conversion an optional leading `"0x"`, or `"0X"` is accepted.
* For octal (radix 8) an optional leading `"0"` is accepted.
* For binary (radix 2) an optional leading `"0b"` or `"0B"` is accepted.
* When `radix` is set to `default`, the conversion is based on the leading.
  characters in the string. A leading `"0"` for radix 8, a leading `"0x"`, or `"0X"` for
  radix 16, and leading `"0b"` or `"0B"` for binary.
* Conversion from `Boolean` results in `0` for `false` and `1` for `true`.
* Conversion from `Integer`, `Float`, and `Boolean` ignores the radix.
* `Float` value fractions are truncated (no rounding).
* When `abs` is set to `true`, the result will be an absolute integer.

```puppet
$a_number = Integer("0xFF", 16)    # results in 255
$a_number = Integer("010")         # results in 8
$a_number = Integer("010", 10)     # results in 10
$a_number = Integer(true)          # results in 1
$a_number = Integer(-38, 10, true) # results in 38
```

### Conversion to Float

A new `Float` can be created from `Integer`, `Float`, `Boolean`, and `String` values.
For conversion from `String` both float and integer formats are supported.

```puppet
function Float.new(
  Variant[Numeric, Boolean, String] $value,
  Boolean $abs = true
)
```

* For an integer, the floating point fraction of `.0` is added to the value.
* A `Boolean` `true` is converted to `1.0`, and a `false` to `0.0`.
* In `String` format, integer prefixes for hex and binary are understood (but not octal since
  floating point in string format may start with a `'0'`).
* When `abs` is set to `true`, the result will be an absolute floating point value.

### Conversion to Numeric

A new `Integer` or `Float` can be created from `Integer`, `Float`, `Boolean` and
`String` values.

```puppet
function Numeric.new(
  Variant[Numeric, Boolean, String] $value,
  Boolean $abs = true
)
```

* If the value has a decimal period, or if given in scientific notation
  (e/E), the result is a `Float`, otherwise the value is an `Integer`. The
  conversion from `String` always uses a radix based on the prefix of the string.
* Conversion from `Boolean` results in `0` for `false` and `1` for `true`.
* When `abs` is set to `true`, the result will be an absolute `Float`or `Integer` value.

```puppet
$a_number = Numeric(true)        # results in 1
$a_number = Numeric("0xFF")      # results in 255
$a_number = Numeric("010")       # results in 8
$a_number = Numeric("3.14")      # results in 3.14 (a float)
$a_number = Numeric(-42.3, true) # results in 42.3
$a_number = Numeric(-42, true)   # results in 42
```

### Conversion to Timespan

A new `Timespan` can be created from `Integer`, `Float`, `String`, and `Hash` values. Several variants of the constructor are provided.

**Timespan from seconds**

When a Float is used, the decimal part represents fractions of a second.

```puppet
function Timespan.new(
  Variant[Float, Integer] $value
)
```

**Timespan from days, hours, minutes, seconds, and fractions of a second**

The arguments can be passed separately in which case the first four, days, hours, minutes, and seconds are mandatory and the rest are optional.
All values may overflow and/or be negative. The internal 128-bit nano-second integer is calculated as:

```
(((((days * 24 + hours) * 60 + minutes) * 60 + seconds) * 1000 + milliseconds) * 1000 + microseconds) * 1000 + nanoseconds
```

```puppet
function Timespan.new(
  Integer $days, Integer $hours, Integer $minutes, Integer $seconds,
  Integer $milliseconds = 0, Integer $microseconds = 0, Integer $nanoseconds = 0
)
```

or, all arguments can be passed as a `Hash`, in which case all entries are optional:

```puppet
function Timespan.new(
  Struct[{
    Optional[negative] => Boolean,
    Optional[days] => Integer,
    Optional[hours] => Integer,
    Optional[minutes] => Integer,
    Optional[seconds] => Integer,
    Optional[milliseconds] => Integer,
    Optional[microseconds] => Integer,
    Optional[nanoseconds] => Integer
  }] $hash
)
```

**Timespan from String and format directive patterns**

The first argument is parsed using the format optionally passed as a string or array of strings. When an array is used, an attempt
will be made to parse the string using the first entry and then with each entry in succession until parsing succeeds. If the second
argument is omitted, an array of default formats will be used.

An exception is raised when no format was able to parse the given string.

```puppet
function Timespan.new(
  String $string, Variant[String[2],Array[String[2], 1]] $format = <default format>)
)
```

the arguments may also be passed as a `Hash`:

```puppet
function Timespan.new(
  Struct[{
    string => String[1],
    Optional[format] => Variant[String[2],Array[String[2], 1]]
  }] $hash
)
```

The directive consists of a percent (`%`) character, zero or more flags, optional minimum field width and
a conversion specifier as follows:
```
%[Flags][Width]Conversion
```

**Flags:**

| Flag  | Meaning
| ----  | ---------------
| -     | Don't pad numerical output
| _     | Use spaces for padding
| 0     | Use zeros for padding

**Format directives:**

| Format | Meaning |
| ------ | ------- |
| D | Number of Days |
| H | Hour of the day, 24-hour clock |
| M | Minute of the hour (00..59) |
| S | Second of the minute (00..59) |
| L | Millisecond of the second (000..999) |
| N | Fractional seconds digits |

The format directive that represents the highest magnitude in the format will be allowed to
overflow. I.e. if no "%D" is used but a "%H" is present, then the hours may be more than 23.

The default array contains the following patterns:

```
['%D-%H:%M:%S', '%D-%H:%M', '%H:%M:%S', '%H:%M']
```

Examples - Converting to Timespan

```puppet
$duration = Timespan(13.5)       # 13 seconds and 500 milliseconds
$duration = Timespan({days=>4})  # 4 days
$duration = Timespan(4, 0, 0, 2) # 4 days and 2 seconds
$duration = Timespan('13:20')    # 13 hours and 20 minutes (using default pattern)
$duration = Timespan('10:03.5', '%M:%S.%L') # 10 minutes, 3 seconds, and 5 milli-seconds
$duration = Timespan('10:03.5', '%M:%S.%N') # 10 minutes, 3 seconds, and 5 nano-seconds
```

### Conversion to Timestamp

A new `Timestamp` can be created from `Integer`, `Float`, `String`, and `Hash` values. Several variants of the constructor are provided.

**Timestamp from seconds since epoch (1970-01-01 00:00:00 UTC)**

When a Float is used, the decimal part represents fractions of a second.

```puppet
function Timestamp.new(
  Variant[Float, Integer] $value
)
```

**Timestamp from String and patterns consisting of format directives**

The first argument is parsed using the format optionally passed as a string or array of strings. When an array is used, an attempt
will be made to parse the string using the first entry and then with each entry in succession until parsing succeeds. If the second
argument is omitted, an array of default formats will be used.

A third optional timezone argument can be provided. The first argument will then be parsed as if it represents a local time in that
timezone. The timezone can be any timezone that is recognized when using the `'%z'` or `'%Z'` formats, or the word `'current'`, in which
case the current timezone of the evaluating process will be used. The timezone argument is case insensitive.

The default timezone, when no argument is provided, or when using the keyword `default`, is 'UTC'.

It is illegal to provide a timezone argument other than `default` in combination with a format that contains '%z' or '%Z' since that
would introduce an ambiguity as to which timezone to use. The one extracted from the string, or the one provided as an argument.

An exception is raised when no format was able to parse the given string.

```puppet
function Timestamp.new(
  String $string,
  Variant[String[2],Array[String[2], 1]] $format = <default format>,
  String $timezone = default)
)
```

the arguments may also be passed as a `Hash`:

```puppet
function Timestamp.new(
  Struct[{
    string => String[1],
    Optional[format] => Variant[String[2],Array[String[2], 1]],
    Optional[timezone] => String[1]
  }] $hash
)
```

The directive consists of a percent (%) character, zero or more flags, optional minimum field width and
a conversion specifier as follows:
```
%[Flags][Width]Conversion
```

**Flags:**

| Flag  | Meaning
| ----  | ---------------
| -     | Don't pad numerical output
| _     | Use spaces for padding
| 0     | Use zeros for padding
| #     | Change names to upper-case or change case of am/pm
| ^     | Use uppercase
| :     | Use colons for `%z`

**Format directives (names and padding can be altered using flags):**

**Date (Year, Month, Day):**

| Format | Meaning |
| ------ | ------- |
| Y | Year with century, zero-padded to at least 4 digits |
| C | year / 100 (rounded down such as `20` in `2009`) |
| y | year % 100 (`00..99`) |
| m | Month of the year, zero-padded (`01..12`) |
| B | The full month name (`"January"`) |
| b | The abbreviated month name (`"Jan"`) |
| h | Equivalent to `%b` |
| d | Day of the month, zero-padded (`01..31`) |
| e | Day of the month, blank-padded (`1..31`) |
| j | Day of the year (`001..366`) |

**Time (Hour, Minute, Second, Subsecond):**

| Format | Meaning |
| ------ | ------- |
| H | Hour of the day, 24-hour clock, zero-padded (`00..23`) |
| k | Hour of the day, 24-hour clock, blank-padded (`0..23`) |
| I | Hour of the day, 12-hour clock, zero-padded (`01..12`) |
| l | Hour of the day, 12-hour clock, blank-padded (`1..12`) |
| P | Meridian indicator, lowercase (`"am"` or `"pm"`) |
| p | Meridian indicator, uppercase (`"AM"` or `"PM"`) |
| M | Minute of the hour (`00..59`) |
| S | Second of the minute (`00..60`) |
| L | Millisecond of the second (`000..999`). Digits under millisecond are truncated to not produce 1000 |
| N | Fractional seconds digits, default is 9 digits (nanosecond). Digits under a specified width are truncated to avoid carry up |

**Time (Hour, Minute, Second, Subsecond):**

| Format | Meaning |
| ------ | ------- |
| z   | Time zone as hour and minute offset from UTC (e.g. `+0900`) |
| :z  | hour and minute offset from UTC with a colon (e.g. `+09:00`) |
| ::z | hour, minute and second offset from UTC (e.g. `+09:00:00`) |
| Z   | Abbreviated time zone name or similar information.  (OS dependent) |

**Weekday:**

| Format | Meaning |
| ------ | ------- |
| A | The full weekday name (`"Sunday"`) |
| a | The abbreviated name (`"Sun"`) |
| u | Day of the week (Monday is `1`, `1..7`) |
| w | Day of the week (Sunday is `0`, `0..6`) |

**ISO 8601 week-based year and week number:**

The first week of YYYY starts with a Monday and includes YYYY-01-04.
The days in the year before the first week are in the last week of
the previous year.

| Format | Meaning |
| ------ | ------- |
| G | The week-based year |
| g | The last 2 digits of the week-based year (`00..99`) |
| V | Week number of the week-based year (`01..53`) |

**Week number:**

The first week of YYYY that starts with a Sunday or Monday (according to %U
or %W). The days in the year before the first week are in week 0.

| Format | Meaning |
| ------ | ------- |
| U | Week number of the year. The week starts with Sunday. (`00..53`) |
| W | Week number of the year. The week starts with Monday. (`00..53`) |

**Seconds since the Epoch:**

| Format | Meaning |
| s | Number of seconds since 1970-01-01 00:00:00 UTC. |

**Literal string:**

| Format | Meaning |
| ------ | ------- |
| n | Newline character (`\n`) |
| t | Tab character (`\t`) |
| % | Literal `%` character |

**Combination:**

| Format | Meaning |
| ------ | ------- |
| c | date and time (`%a %b %e %T %Y`) |
| D | Date (`%m/%d/%y`) |
| F | The ISO 8601 date format (`%Y-%m-%d`) |
| v | VMS date (`%e-%^b-%4Y`) |
| x | Same as `%D` |
| X | Same as `%T` |
| r | 12-hour time (`%I:%M:%S %p`) |
| R | 24-hour time (`%H:%M`) |
| T | 24-hour time (`%H:%M:%S`) |

The default array contains the following patterns:

When a timezone argument (other than `default`) is explicitly provided:

```
['%FT%T.L', '%FT%T', '%F']
```

otherwise:

```
['%FT%T.%L %Z', '%FT%T %Z', '%F %Z', '%FT%T.L', '%FT%T', '%F']
```

Examples - Converting to Timestamp

```puppet
$ts = Timestamp(1473150899)                              # 2016-09-06 08:34:59 UTC
$ts = Timestamp({string=>'2015', format=>'%Y'})          # 2015-01-01 00:00:00.000 UTC
$ts = Timestamp('Wed Aug 24 12:13:14 2016', '%c')        # 2016-08-24 12:13:14 UTC
$ts = Timestamp('Wed Aug 24 12:13:14 2016 PDT', '%c %Z') # 2016-08-24 19:13:14.000 UTC
$ts = Timestamp('2016-08-24 12:13:14', '%F %T', 'PST')   # 2016-08-24 20:13:14.000 UTC
$ts = Timestamp('2016-08-24T12:13:14', default, 'PST')   # 2016-08-24 20:13:14.000 UTC

```

### Conversion to Type

A new `Type` can be created from its `String` representation.

```puppet
$t = Type.new('Integer[10]')
```

### Conversion to String

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

**Signatures of String conversion**

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

```puppet
$str = String(10)      # produces '10'
$str = String([10])    # produces '["10"]'
```

```puppet
$str = String(10, "%#x")    # produces '0xa'
$str = String([10], "%(a")  # produces '("10")'
```

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

**Integer to String**

| Format  | Integer Formats
| ------  | ---------------
| d       | Decimal, negative values produces leading `-`.
| x X     | Hexadecimal in lower or upper case. Uses `..f/..F` for negative values unless `+` is also used. A `#` adds prefix `0x/0X`.
| o       | Octal. Uses `..0` for negative values unless `+` is also used. A `#` adds prefix `0`.
| b B     | Binary with prefix `b` or `B`. Uses `..1/..1` for negative values unless `+` is also used.
| c       | Numeric value representing a Unicode value, result is a one unicode character string, quoted if alternative flag `#` is used
| s       | Same as `d`, or `d` in quotes if alternative flag `#` is used.
| p       | Same as `d`.
| eEfgGaA | Converts integer to float and formats using the floating point rules.

Defaults to `d`.

**Float to String**

| Format  | Float formats
| ------  | -------------
| f       | Floating point in non exponential notation.
| e E     | Exponential notation with `e` or `E`.
| g G     | Conditional exponential with `e` or `E` if exponent `< -4` or `>=` the precision.
| a A     | Hexadecimal exponential form, using `x`/`X` as prefix and `p`/`P` before exponent.
| s       | Converted to string using format `p`, then applying string formatting rule, alternate form `#`` quotes result.
| p       | Same as `f` format with minimum significant number of fractional digits, prec has no effect.
| dxXobBc | Converts float to integer and formats using the integer rules.

Defaults to `p`.

**String to String**

| Format | String
| ------ | ------
| s      | Unquoted string, verbatim output of control chars.
| p      | Programmatic representation - strings are quoted, interior quotes and control chars are escaped. Selects single or double quotes based on content, or uses double quotes if alternative flag `#` is used.
| C      | Each `::` name segment capitalized, quoted if alternative flag `#` is used.
| c      | Capitalized string, quoted if alternative flag `#` is used.
| d      | Downcased string, quoted if alternative flag `#` is used.
| u      | Upcased string, quoted if alternative flag `#` is used.
| t      | Trims leading and trailing whitespace from the string, quoted if alternative flag `#` is used.

Defaults to `s` at top level and `p` inside array or hash.

**Boolean to String**

| Format    | Boolean Formats
| ----      | -------------------
| t T       | String `'true'/'false'` or `'True'/'False'`, first char if alternate form is used (i.e. `'t'/'f'` or `'T'/'F'`).
| y Y       | String `'yes'/'no'`, `'Yes'/'No'`, `'y'/'n'` or `'Y'/'N'` if alternative flag `#` is used.
| dxXobB    | Numeric value `0/1` in accordance with the given format which must be valid integer format.
| eEfgGaA   | Numeric value `0.0/1.0` in accordance with the given float format and flags.
| s         | String `'true'` / `'false'`.
| p         | String `'true'` / `'false'`.

**Regexp to String**

| Format    | Regexp Formats
| ----      | --------------
| s         | No delimiters, quoted if alternative flag `#` is used.
| p         | Delimiters `/ /`.

**Undef to String**

| Format    | Undef formats
| ------    | -------------
| s         | Empty string, or quoted empty string if alternative flag `#` is used.
| p         | String `'undef'`, or quoted `'"undef"'` if alternative flag `#` is used.
| n         | String `'nil'`, or `'null'` if alternative flag `#` is used.
| dxXobB    | String `'NaN'`.
| eEfgGaA   | String `'NaN'`.
| v         | String `'n/a'`.
| V         | String `'N/A'`.
| u         | String `'undef'`, or `'undefined'` if alternative `#` flag is used.

**Default value to String**

| Format    | Default formats
| ------    | ---------------
| d D       | String `'default'` or `'Default'`, alternative form `#` causes value to be quoted.
| s         | Same as `d`.
| p         | Same as `d`.

**Binary value to String**

| Format    | Default formats
| ------    | ---------------
| s         | binary as unquoted UTF-8 characters (errors if byte sequence is invalid UTF-8). Alternate form escapes non ascii bytes.
| p         | `'Binary("<base64strict>")'`
| b         | `'<base64>'` - base64 string with newlines inserted
| B         | `'<base64strict>'` - base64 strict string (without newlines inserted)
| u         | `'<base64urlsafe>'` - base64 urlsafe string
| t         | `'Binary'` - outputs the name of the type only
| T         | `'BINARY'` - output the name of the type in all caps only

* The alternate form flag `#` will quote the binary or base64 text output.
* The format `%#s` allows invalid UTF-8 characters and outputs all non ascii bytes
  as hex escaped characters on the form `\\xHH` where `H` is a hex digit.
* The width and precision values are applied to the text part only in `%p` format.

**Array & Tuple to String**

| Format    | Array/Tuple Formats
| ------    | -------------
| a         | Formats with `[ ]` delimiters and `,`, alternate form `#` indents nested arrays/hashes.
| s         | Same as `a`.
| p         | Same as `a`.

See "Flags" `<[({\|` for formatting of delimiters, and "Additional parameters for containers; Array and Hash" for
more information about options.

The alternate form flag `#` will cause indentation of nested array or hash containers. If width is also set
it is taken as the maximum allowed length of a sequence of elements (not including delimiters). If this max length
is exceeded, each element will be indented.

**Hash & Struct to String**

| Format    | Hash/Struct Formats
| ------    | -------------
| h         | Formats with `{ }` delimiters, `,` element separator and ` => ` inner element separator unless overridden by flags.
| s         | Same as h.
| p         | Same as h.
| a         | Converts the hash to an array of `[k,v]` tuples and formats it using array rule(s).

See "Flags" `<[({\|` for formatting of delimiters, and "Additional parameters for containers; Array and Hash" for
more information about options.

The alternate form flag `#` will format each hash key/value entry indented on a separate line.

**Type to String**

| Format    | Array/Tuple Formats
| ------    | -------------
| s         | The same as `p`, quoted if alternative flag `#` is used.
| p         | Outputs the type in string form as specified by the Puppet Language.

**Flags**

| Flag     | Effect
| ------   | ------
| (space)  | A space instead of `+` for numeric output (`-` is shown), for containers skips delimiters.
| #        | Alternate format; prefix `0x/0x`, `0` (octal) and `0b/0B` for binary, Floats force decimal '.'. For g/G keep trailing `0`.
| +        | Show sign `+/-` depending on value's sign, changes `x`, `X`, `o`, `b`, `B` format to not use 2's complement form.
| -        | Left justify the value in the given width.
| 0        | Pad with `0` instead of space for widths larger than value.
| <[({\|   | Defines an enclosing pair `<> [] () {} or \| \|` when used with a container type.

### Conversion to Boolean

Accepts a single value as argument:

* Float `0.0` is `false`, all other float values are `true`
* Integer `0` is `false`, all other integer values are `true`
* Strings
  * `true` if 'true', 'yes', 'y' (case independent compare)
  * `false` if 'false', 'no', 'n' (case independent compare)
* Boolean is already boolean and is simply returned

### Conversion to Array and Tuple

When given a single value as argument:

* A non empty `Hash` is converted to an array matching `Array[Tuple[Any,Any], 1]`.
* An empty `Hash` becomes an empty array.
* An `Array` is simply returned.
* An `Iterable[T]` is turned into an array of `T` instances.
* A `Binary` is converted to an `Array[Integer[0,255]]` of byte values

When given a second Boolean argument:

* if `true`, a value that is not already an array is returned as a one element array.
* if `false`, (the default), converts the first argument as shown above.

```puppet
$arr = Array($value, true)
```

Conversion to a `Tuple` works exactly as conversion to an `Array`, only that the constructed array is
asserted against the given tuple type.

### Conversion to Hash and Struct

Accepts a single value as argument:

* An empty `Array` becomes an empty `Hash`
* An `Array` matching `Array[Tuple[Any,Any], 1]` is converted to a hash where each tuple describes a key/value entry
* An `Array` with an even number of entries is interpreted as `[key1, val1, key2, val2, ...]`
* An `Iterable` is turned into an `Array` and then converted to hash as per the array rules
* A `Hash` is simply returned

Alternatively, a tree can be constructed by giving two values; an array of tuples on the form `[path, value]`
(where the `path` is the path from the root of a tree, and `value` the value at that position in the tree), and
either the option `'tree'` (do not convert arrays to hashes except the top level), or
`'hash_tree'` (convert all arrays to hashes).

The tree/hash_tree forms of Hash creation are suited for transforming the result of an iteration
using `tree_each` and subsequent filtering or mapping.

Mapping an arbitrary structure in a way that keeps the structure, but where some values are replaced
can be done by using the `tree_each` function, mapping, and then constructing a new Hash from the result:

```puppet
# A hash tree with 'water' at different locations
$h = { a => { b => { x => 'water'}}, b => { y => 'water'} }
# a helper function that turns water into wine
function make_wine($x) { if $x == 'water' { 'wine' } else { $x } }
# create a flattened tree with water turned into wine
$flat_tree = $h.tree_each.map |$entry| { [$entry[0], make_wine($entry[1])] }
# create a new Hash and log it
notice Hash($flat_tree, 'hash_tree')
```

Would notice the hash `{a => {b => {x => wine}}, b => {y => wine}}`

Conversion to a `Struct` works exactly as conversion to a `Hash`, only that the constructed hash is
asserted against the given struct type.

### Conversion to a Regexp

A `String` can be converted into a `Regexp`

**Example**: Converting a String into a Regexp
```puppet
$s = '[a-z]+\.com'
$r = Regexp($s)
if('foo.com' =~ $r) {
  ...
}
```

### Creating a SemVer

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

### Creating a `SemVerRange`

A `SemVerRange` object represents a range of `SemVer`. It can be created from
a `String`, or from two `SemVer` instances, where either end can be given as
a literal `default` to indicate infinity. The string format of a `SemVerRange` is specified by
the [Semantic Version Range Grammar](https://github.com/npm/node-semver#ranges).

> Use of the comparator sets described in the grammar (joining with `||`) is not supported.

The signatures are:

```puppet
type SemVerRangeString = String[1]
type SemVerRangeHash = Struct[{
  min                   => Variant[Default, SemVer],
  Optional[max]         => Variant[Default, SemVer],
  Optional[exclude_max] => Boolean
}]

function SemVerRange.new(
  SemVerRangeString $semver_range_string
)

function SemVerRange.new(
  Variant[Default,SemVer] $min
  Variant[Default,SemVer] $max
  Optional[Boolean]       $exclude_max = undef
)

function SemVerRange.new(
  SemVerRangeHash $semver_range_hash
)
```

For examples of `SemVerRange` use see "Creating a SemVer"

### Creating a Binary

A `Binary` object represents a sequence of bytes and it can be created from a String in Base64 format,
an Array containing byte values. A Binary can also be created from a Hash containing the value to convert to
a `Binary`.

The signatures are:

```puppet
type ByteInteger = Integer[0,255]
type Base64Format = Enum["%b", "%u", "%B", "%s"]
type StringHash = Struct[{value => String, "format" => Optional[Base64Format]}]
type ArrayHash = Struct[{value => Array[ByteInteger]}]
type BinaryArgsHash = Variant[StringHash, ArrayHash]

function Binary.new(
  String $base64_str,
  Optional[Base64Format] $format
)


function Binary.new(
  Array[ByteInteger] $byte_array
}

# Same as for String, or for Array, but where arguments are given in a Hash.
function Binary.new(BinaryArgsHash $hash_args)
```

The formats have the following meaning:

| format | explanation |
| ----   | ----        |
| B | The data is in base64 strict encoding
| u | The data is in URL safe base64 encoding
| b | The data is in base64 encoding, padding as required by base64 strict, is added by default
| s | The data is a puppet string. The string must be valid UTF-8, or convertible to UTF-8 or an error is raised.
| r | (Ruby Raw) the byte sequence in the given string is used verbatim irrespective of possible encoding errors

* The default format is `%B`.
* Note that the format `%r` should be used sparingly, or not at all. It exists for backwards compatibility reasons when someone receiving
  a string from some function and that string should be treated as Binary. Such code should be changed to return a Binary instead of a String.

```puppet
# create the binary content "abc"
$a = Binary('YWJj')

# create the binary content from content in a module's file
$b = binary_file('mymodule/mypicture.jpg')
```

* Since 4.5.0
* Binary type since 4.8.0

### Creating an instance of a `Type` using the `Init` type

The type `Init[T]` describes a value that can be used when instantiating a type. When used as the first argument in a call to `new`, it
will dispatch the call to its contained type and optionally augment the parameter list with additional arguments.

```puppet
# The following declaration
$x = Init[Integer].new('128')
# is exactly the same as
$x = Integer.new('128')
```

or, with base 16 and using implicit new

```puppet
# The following declaration
$x = Init[Integer,16]('80')
# is exactly the same as
$x = Integer('80', 16)
```

```puppet
$fmt = Init[String,'%#x']
notice($fmt(256)) # will notice '0x100'
```


`new(Type $type, Any *$args, Optional[Callable] &$block)`

## `next`

Makes iteration continue with the next value, optionally with a given value for this iteration.
If a value is not given it defaults to `undef`

```puppet
$data = ['a','b','c']
$data.each |Integer $index, String $value| {
  if $index == 1 {
    next()
  }
  notice ("${index} = ${value}")
}
```

Would notice:
```
Notice: Scope(Class[main]): 0 = a
Notice: Scope(Class[main]): 2 = c
```


`next(Optional[Any] $value)`

## `notice`

Logs a message on the server at level `notice`.


`notice(Any *$values)`

### Parameters


* `*values` --- The values to log.

Return type(s): `Undef`. 

## `partition`

Returns two arrays, the first containing the elements of enum for which the block evaluates to true,
the second containing the rest.


Signature 1

`partition(Collection $collection, Callable[1,1] &$block)`

### Parameters


* `collection` --- A collection of things to partition.

Return type(s): `Tuple[Array, Array]`. 


### Examples

Partition array of empty strings, results in e.g. `[[''], [b, c]]`

```puppet
['', b, c].partition |$s| { $s.empty }
```

Partition array of strings using index, results in e.g. `[['', 'ab'], ['b']]`

```puppet
['', b, ab].partition |$i, $s| { $i == 2 or $s.empty }
```

Partition hash of strings by key-value pair, results in e.g. `[[['b', []]], [['a', [1, 2]]]]`

```puppet
{ a => [1, 2], b => [] }.partition |$kv| { $kv[1].empty }
```

Partition hash of strings by key and value, results in e.g. `[[['b', []]], [['a', [1, 2]]]]`

```puppet
{ a => [1, 2], b => [] }.partition |$k, $v| { $v.empty }
```


Signature 2

`partition(Array $array, Callable[2,2] &$block)`

Signature 3

`partition(Collection $collection, Callable[2,2] &$block)`

## `realize`

Make a virtual object real.  This is useful
when you want to know the name of the virtual object and don't want to
bother with a full collection.  It is slightly faster than a collection,
and, of course, is a bit shorter.  You must pass the object using a
reference; e.g.: `realize User[luke]`.


`realize()`

## `reduce`

Applies a [lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html)
to every value in a data structure from the first argument, carrying over the returned
value of each iteration, and returns the result of the lambda's final iteration. This
lets you create a new value or data structure by combining values from the first
argument's data structure.

This function takes two mandatory arguments, in this order:

1. An array, hash, or other iterable object that the function will iterate over.
2. A lambda, which the function calls for each element in the first argument. It takes
two mandatory parameters:
    1. A memo value that is overwritten after each iteration with the iteration's result.
    2. A second value that is overwritten after each iteration with the next value in the
    function's first argument.

`$data.reduce |$memo, $value| { ... }`

or

`reduce($data) |$memo, $value| { ... }`

You can also pass an optional "start memo" value as an argument, such as `start` below:

`$data.reduce(start) |$memo, $value| { ... }`

or

`reduce($data, start) |$memo, $value| { ... }`

When the first argument (`$data` in the above example) is an array, Puppet passes each
of the data structure's values in turn to the lambda's parameters. When the first
argument is a hash, Puppet converts each of the hash's values to an array in the form
`[key, value]`.

If you pass a start memo value, Puppet executes the lambda with the provided memo value
and the data structure's first value. Otherwise, Puppet passes the structure's first two
values to the lambda.

Puppet calls the lambda for each of the data structure's remaining values. For each
call, it passes the result of the previous call as the first parameter (`$memo` in the
above examples) and the next value from the data structure as the second parameter
(`$value`).

```puppet
# Reduce the array $data, returning the sum of all values in the array.
$data = [1, 2, 3]
$sum = $data.reduce |$memo, $value| { $memo + $value }
# $sum contains 6

# Reduce the array $data, returning the sum of a start memo value and all values in the
# array.
$data = [1, 2, 3]
$sum = $data.reduce(4) |$memo, $value| { $memo + $value }
# $sum contains 10

# Reduce the hash $data, returning the sum of all values and concatenated string of all
# keys.
$data = {a => 1, b => 2, c => 3}
$combine = $data.reduce |$memo, $value| {
  $string = "${memo[0]}${value[0]}"
  $number = $memo[1] + $value[1]
  [$string, $number]
}
# $combine contains [abc, 6]
```

```puppet
# Reduce the array $data, returning the sum of all values in the array and starting
# with $memo set to an arbitrary value instead of $data's first value.
$data = [1, 2, 3]
$sum = $data.reduce(4) |$memo, $value| { $memo + $value }
# At the start of the lambda's first iteration, $memo contains 4 and $value contains 1.
# After all iterations, $sum contains 10.

# Reduce the hash $data, returning the sum of all values and concatenated string of
# all keys, and starting with $memo set to an arbitrary array instead of $data's first
# key-value pair.
$data = {a => 1, b => 2, c => 3}
$combine = $data.reduce( [d, 4] ) |$memo, $value| {
  $string = "${memo[0]}${value[0]}"
  $number = $memo[1] + $value[1]
  [$string, $number]
}
# At the start of the lambda's first iteration, $memo contains [d, 4] and $value
# contains [a, 1].
# $combine contains [dabc, 10]
```

```puppet
# Reduce a hash of hashes $data, merging defaults into the inner hashes.
$data = {
  'connection1' => {
    'username' => 'user1',
    'password' => 'pass1',
  },
  'connection_name2' => {
    'username' => 'user2',
    'password' => 'pass2',
  },
}

$defaults = {
  'maxActive' => '20',
  'maxWait'   => '10000',
  'username'  => 'defaultuser',
  'password'  => 'defaultpass',
}

$merged = $data.reduce( {} ) |$memo, $x| {
  $memo + { $x[0] => $defaults + $data[$x[0]] }
}
# At the start of the lambda's first iteration, $memo is set to {}, and $x is set to
# the first [key, value] tuple. The key in $data is, therefore, given by $x[0]. In
# subsequent rounds, $memo retains the value returned by the expression, i.e.
# $memo + { $x[0] => $defaults + $data[$x[0]] }.
```


Signature 1

`reduce(Iterable $enumerable, Callable[2,2] &$block)`

Signature 2

`reduce(Iterable $enumerable, Any $memo, Callable[2,2] &$block)`

## `regsubst`

Performs regexp replacement on a string or array of strings.


Signature 1

`regsubst(Variant[Array[Variant[String,Sensitive[String]]],Sensitive[Array[Variant[String,Sensitive[String]]]],Variant[String,Sensitive[String]]] $target, String $pattern, Variant[String,Hash[String,String]] $replacement, Optional[Optional[Pattern[/^[GEIM]*$/]]] $flags, Optional[Enum['N','E','S','U']] $encoding)`

### Parameters


* `target` --- The string or array of strings to operate on.  If an array, the replacement will be
performed on each of the elements in the array, and the return value will be an array.

* `pattern` --- The regular expression matching the target string.  If you want it anchored at the start
and or end of the string, you must do that with ^ and $ yourself.

* `replacement` --- Replacement string. Can contain backreferences to what was matched using \\0 (whole match),
\\1 (first set of parentheses), and so on.
If the second argument is a Hash, and the matched text is one of its keys, the corresponding value is the replacement string.

* `flags` --- Optional. String of single letter flags for how the regexp is interpreted (E, I, and M cannot be used
if pattern is a precompiled regexp):
  - *E*         Extended regexps
  - *I*         Ignore case in regexps
  - *M*         Multiline regexps
  - *G*         Global replacement; all occurrences of the regexp in each target string will be replaced.  Without this, only the first occurrence will be replaced.

* `encoding` --- Deprecated and ignored parameter, included only for compatibility.

Return type(s): `Array[String]`, `String`. The result of the substitution. Result type is the same as for the target parameter.


### Examples

Get the third octet from the node's IP address:

```puppet
$i3 = regsubst($ipaddress,'^(\\d+)\\.(\\d+)\\.(\\d+)\\.(\\d+)$','\\3')
```


Signature 2

`regsubst(Variant[Array[Variant[String,Sensitive[String]]],Sensitive[Array[Variant[String,Sensitive[String]]]],Variant[String,Sensitive[String]]] $target, Variant[Regexp,Type[Regexp]] $pattern, Variant[String,Hash[String,String]] $replacement, Optional[Pattern[/^G?$/]] $flags)`

### Parameters


* `target` --- The string or array of strings to operate on.  If an array, the replacement will be
performed on each of the elements in the array, and the return value will be an array.

* `pattern` --- The regular expression matching the target string.  If you want it anchored at the start
and or end of the string, you must do that with ^ and $ yourself.

* `replacement` --- Replacement string. Can contain backreferences to what was matched using \\0 (whole match),
\\1 (first set of parentheses), and so on.
If the second argument is a Hash, and the matched text is one of its keys, the corresponding value is the replacement string.

* `flags` --- Optional. String of single letter flags for how the regexp is interpreted (E, I, and M cannot be used
if pattern is a precompiled regexp):
  - *E*         Extended regexps
  - *I*         Ignore case in regexps
  - *M*         Multiline regexps
  - *G*         Global replacement; all occurrences of the regexp in each target string will be replaced.  Without this, only the first occurrence will be replaced.

Return type(s): `Array[String]`, `String`. The result of the substitution. Result type is the same as for the target parameter.


### Examples

Put angle brackets around each octet in the node's IP address:

```puppet
$x = regsubst($ipaddress, /([0-9]+)/, '<\\1>', 'G')
```


## `require`

Requires the specified classes.
Evaluate one or more classes, adding the required class as a dependency.

The relationship metaparameters work well for specifying relationships
between individual resources, but they can be clumsy for specifying
relationships between classes.  This function is a superset of the
`include` function, adding a class relationship so that the requiring
class depends on the required class.

Warning: using `require` in place of `include` can lead to unwanted dependency cycles.

For instance, the following manifest, with `require` instead of `include`, would produce a nasty
dependence cycle, because `notify` imposes a `before` between `File[/foo]` and `Service[foo]`:

```puppet
class myservice {
  service { foo: ensure => running }
}

class otherstuff {
   include myservice
   file { '/foo': notify => Service[foo] }
}
```

Note that this function only works with clients 0.25 and later, and it will
fail if used with earlier clients.

You must use the class's full name;
relative names are not allowed. In addition to names in string form,
you may also directly use Class and Resource Type values that are produced when evaluating
resource and relationship expressions.

- Since 4.0.0 Class and Resource types, absolute names
- Since 4.7.0 Returns an `Array[Type[Class]]` with references to the required classes


`require(Any *$names)`

## `return`

Makes iteration continue with the next value, optionally with a given value for this iteration.
If a value is not given it defaults to `undef`


`return(Optional[Any] $value)`

## `reverse_each`

Reverses the order of the elements of something that is iterable and optionally runs a
[lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html) for each
element.

This function takes one to two arguments:

1. An `Iterable` that the function will iterate over.
2. An optional lambda, which the function calls for each element in the first argument. It must
   request one parameter.

```puppet
$data.reverse_each |$parameter| { <PUPPET CODE BLOCK> }
```

or

```puppet
$reverse_data = $data.reverse_each
```

or

```puppet
reverse_each($data) |$parameter| { <PUPPET CODE BLOCK> }
```

or

```puppet
$reverse_data = reverse_each($data)
```

When no second argument is present, Puppet returns an `Iterable` that represents the reverse
order of its first argument. This allows methods on `Iterable` to be chained.

When a lambda is given as the second argument, Puppet iterates the first argument in reverse
order and passes each value in turn to the lambda, then returns `undef`.

```puppet
# Puppet will log a notice for each of the three items
# in $data in reverse order.
$data = [1,2,3]
$data.reverse_each |$item| { notice($item) }
```

When no second argument is present, Puppet returns a new `Iterable` which allows it to
be directly chained into another function that takes an `Iterable` as an argument.

```puppet
# For the array $data, return an array containing each
# value multiplied by 10 in reverse order
$data = [1,2,3]
$transformed_data = $data.reverse_each.map |$item| { $item * 10 }
# $transformed_data is set to [30,20,10]
```

```puppet
# For the array $data, return an array containing each
# value multiplied by 10 in reverse order
$data = [1,2,3]
$transformed_data = map(reverse_each($data)) |$item| { $item * 10 }
# $transformed_data is set to [30,20,10]
```


Signature 1

`reverse_each(Iterable $iterable)`

Signature 2

`reverse_each(Iterable $iterable, Callable[1,1] &$block)`

## `round`

Returns an `Integer` value rounded to the nearest value.
Takes a single `Numeric` value as an argument.

```puppet
notice(round(2.9)) # would notice 3
notice(round(2.1)) # would notice 2
notice(round(-2.9)) # would notice -3
```


`round(Numeric $val)`

## `rstrip`

Strips trailing spaces from a String

This function is compatible with the stdlib function with the same name.

The function does the following:
* For a `String` the conversion removes all trailing ASCII white space characters such as space, tab, newline, and return.
  It does not remove other space-like characters like hard space (Unicode U+00A0). (Tip, `/^[[:space:]]/` regular expression
  matches all space-like characters).
* For an `Iterable[Variant[String, Numeric]]` (for example an `Array`) each value is processed and the conversion is not recursive.
* If the value is `Numeric` it is simply returned (this is for backwards compatibility).
* An error is raised for all other data types.

```puppet
" hello\n\t".rstrip()
rstrip(" hello\n\t")
```
Would both result in `"hello"`

```puppet
[" hello\n\t", " hi\n\t"].rstrip()
rstrip([" hello\n\t", " hi\n\t"])
```
Would both result in `['hello', 'hi']`


Signature 1

`rstrip(Numeric $arg)`

Signature 2

`rstrip(String $arg)`

Signature 3

`rstrip(Iterable[Variant[String, Numeric]] $arg)`

## `scanf`

Scans a string and returns an array of one or more converted values based on the given format string.
See the documentation of Ruby's String#scanf method for details about the supported formats (which
are similar but not identical to the formats used in Puppet's `sprintf` function.)

This function takes two mandatory arguments: the first is the string to convert, and the second is
the format string. The result of the scan is an array, with each successfully scanned and transformed value.
The scanning stops if a scan is unsuccessful, and the scanned result up to that point is returned. If there
was no successful scan, the result is an empty array.

   "42".scanf("%i")

You can also optionally pass a lambda to scanf, to do additional validation or processing.


    "42".scanf("%i") |$x| {
      unless $x[0] =~ Integer {
        fail "Expected a well formed integer value, got '$x[0]'"
      }
      $x[0]
    }


`scanf(String $data, String $format, Optional[Callable] &$block)`

## `sha1`

Returns a SHA1 hash value from a provided string.


`sha1()`

## `sha256`

Returns a SHA256 hash value from a provided string.


`sha256()`

## `shellquote`

\
Quote and concatenate arguments for use in Bourne shell.

Each argument is quoted separately, and then all are concatenated
with spaces.  If an argument is an array, the elements of that
array is interpolated within the rest of the arguments; this makes
it possible to have an array of arguments and pass that array to
shellquote instead of having to specify each argument
individually in the call.


`shellquote()`

## `size`

The same as length() - returns the size of an Array, Hash, String, or Binary value.


`size(Variant[Collection, String, Binary] $arg)`

## `slice`

Slices an array or hash into pieces of a given size.

This function takes two mandatory arguments: the first should be an array or hash, and the second specifies
the number of elements to include in each slice.

When the first argument is a hash, each key value pair is counted as one. For example, a slice size of 2 will produce
an array of two arrays with key, and value.

```puppet
$a.slice(2) |$entry|          { notice "first ${$entry[0]}, second ${$entry[1]}" }
$a.slice(2) |$first, $second| { notice "first ${first}, second ${second}" }
```
The function produces a concatenated result of the slices.

```puppet
slice([1,2,3,4,5,6], 2) # produces [[1,2], [3,4], [5,6]]
slice(Integer[1,6], 2)  # produces [[1,2], [3,4], [5,6]]
slice(4,2)              # produces [[0,1], [2,3]]
slice('hello',2)        # produces [[h, e], [l, l], [o]]
```

```puppet
 $a.slice($n) |$x| { ... }
 slice($a) |$x| { ... }
```

The lambda should have either one parameter (receiving an array with the slice), or the same number
of parameters as specified by the slice size (each parameter receiving its part of the slice).
If there are fewer remaining elements than the slice size for the last slice, it will contain the remaining
elements. If the lambda has multiple parameters, excess parameters are set to undef for an array, or
to empty arrays for a hash.

```puppet
    $a.slice(2) |$first, $second| { ... }
```


Signature 1

`slice(Hash[Any, Any] $hash, Integer[1, default] $slice_size, Optional[Callable] &$block)`

Signature 2

`slice(Iterable $enumerable, Integer[1, default] $slice_size, Optional[Callable] &$block)`

## `sort`

Sorts an Array numerically or lexicographically or the characters of a String lexicographically.
Please note: This function is based on Ruby String comparison and as such may not be entirely UTF8 compatible.
To ensure compatibility please use this function with Ruby 2.4.0 or greater - https://bugs.ruby-lang.org/issues/10085.

This function is compatible with the function `sort()` in `stdlib`.
* Comparison of characters in a string always uses a system locale and may not be what is expected for a particular locale
* Sorting is based on Ruby's `<=>` operator unless a lambda is given that performs the comparison.
  * comparison of strings is case dependent (use lambda with `compare($a,$b)` to ignore case)
  * comparison of mixed data types raises an error (if there is the need to sort mixed data types use a lambda)

Also see the `compare()` function for information about comparable data types in general.

```puppet
notice(sort("xadb")) # notices 'abdx'
```

```puppet
notice(sort([3,6,2])) # notices [2, 3, 6]
```

```puppet
notice(sort([3,6,2]) |$a,$b| { compare($a, $b) }) # notices [2, 3, 6]
notice(sort([3,6,2]) |$a,$b| { compare($b, $a) }) # notices [6, 3, 2]
```

```puppet
notice(sort(['A','b','C']))                                    # notices ['A', 'C', 'b']
notice(sort(['A','b','C']) |$a,$b| { compare($a, $b) })        # notices ['A', 'b', 'C']
notice(sort(['A','b','C']) |$a,$b| { compare($a, $b, true) })  # notices ['A', 'b', 'C']
notice(sort(['A','b','C']) |$a,$b| { compare($a, $b, false) }) # notices ['A','C', 'b']
```

```puppet
notice(sort(['b', 3, 'a', 2]) |$a, $b| {
  case [$a, $b] {
    [String, Numeric] : { 1 }
    [Numeric, String] : { -1 }
    default:            { compare($a, $b) }
  }
})
```
Would notice `[2,3,'a','b']`


Signature 1

`sort(String $string_value, Optional[Callable[2,2]] &$block)`

Signature 2

`sort(Array $array_value, Optional[Callable[2,2]] &$block)`

## `split`

Splits a string into an array using a given pattern.
The pattern can be a string, regexp or regexp type.

```puppet
$string     = 'v1.v2:v3.v4'
$array_var1 = split($string, /:/)
$array_var2 = split($string, '[.]')
$array_var3 = split($string, Regexp['[.:]'])

#`$array_var1` now holds the result `['v1.v2', 'v3.v4']`,
# while `$array_var2` holds `['v1', 'v2:v3', 'v4']`, and
# `$array_var3` holds `['v1', 'v2', 'v3', 'v4']`.
```

Note that in the second example, we split on a literal string that contains
a regexp meta-character (`.`), which must be escaped.  A simple
way to do that for a single character is to enclose it in square
brackets; a backslash will also escape a single character.


Signature 1

`split(String $str, String $pattern)`

Signature 2

`split(String $str, Regexp $pattern)`

Signature 3

`split(String $str, Type[Regexp] $pattern)`

Signature 4

`split(Sensitive[String] $sensitive, String $pattern)`

Signature 5

`split(Sensitive[String] $sensitive, Regexp $pattern)`

Signature 6

`split(Sensitive[String] $sensitive, Type[Regexp] $pattern)`

## `sprintf`

Perform printf-style formatting of text.

The first parameter is format string describing how the rest of the parameters should be formatted.
See the documentation for the [`Kernel::sprintf` function](https://ruby-doc.org/core/Kernel.html)
in Ruby for details.

To use [named format](https://idiosyncratic-ruby.com/49-what-the-format.html) arguments, provide a
hash containing the target string values as the argument to be formatted. For example:

```puppet
notice sprintf(\"%<x>s : %<y>d\", { 'x' => 'value is', 'y' => 42 })
```

This statement produces a notice of `value is : 42`.


`sprintf()`

## `step`

When no block is given, Puppet returns a new `Iterable` which allows it to be directly chained into
another function that takes an `Iterable` as an argument.

```puppet
# For the array $data, return an array, set to the first element and each 5th successor element, in reverse
# order multiplied by 10
$data = Integer[0,20]
$transformed_data = $data.step(5).map |$item| { $item * 10 }
$transformed_data contains [0,50,100,150,200]
```

```puppet
# For the array $data, return an array, set to the first and each 5th
# successor, in reverse order, multiplied by 10
$data = Integer[0,20]
$transformed_data = map(step($data, 5)) |$item| { $item * 10 }
$transformed_data contains [0,50,100,150,200]
```


Signature 1

`step(Iterable $iterable, Integer[1] $step)`

Signature 2

`step(Iterable $iterable, Integer[1] $step, Callable[1,1] &$block)`

## `strftime`

Formats timestamp or timespan according to the directives in the given format string. The directives begins with a percent (%) character.
Any text not listed as a directive will be passed through to the output string.

A third optional timezone argument can be provided. The first argument will then be formatted to represent a local time in that
timezone. The timezone can be any timezone that is recognized when using the '%z' or '%Z' formats, or the word 'current', in which
case the current timezone of the evaluating process will be used. The timezone argument is case insensitive.

The default timezone, when no argument is provided, or when using the keyword `default`, is 'UTC'.

The directive consists of a percent (%) character, zero or more flags, optional minimum field width and
a conversion specifier as follows:

```
%[Flags][Width]Conversion
```

### Flags that controls padding

| Flag  | Meaning
| ----  | ---------------
| -     | Don't pad numerical output
| _     | Use spaces for padding
| 0     | Use zeros for padding

### `Timestamp` specific flags

| Flag  | Meaning
| ----  | ---------------
| #     | Change case
| ^     | Use uppercase
| :     | Use colons for %z

### Format directives applicable to `Timestamp` (names and padding can be altered using flags):

**Date (Year, Month, Day):**

| Format | Meaning |
| ------ | ------- |
| Y | Year with century, zero-padded to at least 4 digits |
| C | year / 100 (rounded down such as 20 in 2009) |
| y | year % 100 (00..99) |
| m | Month of the year, zero-padded (01..12) |
| B | The full month name ("January") |
| b | The abbreviated month name ("Jan") |
| h | Equivalent to %b |
| d | Day of the month, zero-padded (01..31) |
| e | Day of the month, blank-padded ( 1..31) |
| j | Day of the year (001..366) |

**Time (Hour, Minute, Second, Subsecond):**

| Format | Meaning |
| ------ | ------- |
| H | Hour of the day, 24-hour clock, zero-padded (00..23) |
| k | Hour of the day, 24-hour clock, blank-padded ( 0..23) |
| I | Hour of the day, 12-hour clock, zero-padded (01..12) |
| l | Hour of the day, 12-hour clock, blank-padded ( 1..12) |
| P | Meridian indicator, lowercase ("am" or "pm") |
| p | Meridian indicator, uppercase ("AM" or "PM") |
| M | Minute of the hour (00..59) |
| S | Second of the minute (00..60) |
| L | Millisecond of the second (000..999). Digits under millisecond are truncated to not produce 1000 |
| N | Fractional seconds digits, default is 9 digits (nanosecond). Digits under a specified width are truncated to avoid carry up |

**Time (Hour, Minute, Second, Subsecond):**

| Format | Meaning |
| ------ | ------- |
| z   | Time zone as hour and minute offset from UTC (e.g. +0900) |
| :z  | hour and minute offset from UTC with a colon (e.g. +09:00) |
| ::z | hour, minute and second offset from UTC (e.g. +09:00:00) |
| Z   | Abbreviated time zone name or similar information.  (OS dependent) |

**Weekday:**

| Format | Meaning |
| ------ | ------- |
| A | The full weekday name ("Sunday") |
| a | The abbreviated name ("Sun") |
| u | Day of the week (Monday is 1, 1..7) |
| w | Day of the week (Sunday is 0, 0..6) |

**ISO 8601 week-based year and week number:**

The first week of YYYY starts with a Monday and includes YYYY-01-04.
The days in the year before the first week are in the last week of
the previous year.

| Format | Meaning |
| ------ | ------- |
| G | The week-based year |
| g | The last 2 digits of the week-based year (00..99) |
| V | Week number of the week-based year (01..53) |

**Week number:**

The first week of YYYY that starts with a Sunday or Monday (according to %U
or %W). The days in the year before the first week are in week 0.

| Format | Meaning |
| ------ | ------- |
| U | Week number of the year. The week starts with Sunday. (00..53) |
| W | Week number of the year. The week starts with Monday. (00..53) |

**Seconds since the Epoch:**

| Format | Meaning |
| ------ | ------- |
| s | Number of seconds since 1970-01-01 00:00:00 UTC. |

**Literal string:**

| Format | Meaning |
| ------ | ------- |
| n | Newline character (\n) |
| t | Tab character (\t) |
| % | Literal "%" character |

**Combination:**

| Format | Meaning |
| ------ | ------- |
| c | date and time (%a %b %e %T %Y) |
| D | Date (%m/%d/%y) |
| F | The ISO 8601 date format (%Y-%m-%d) |
| v | VMS date (%e-%^b-%4Y) |
| x | Same as %D |
| X | Same as %T |
| r | 12-hour time (%I:%M:%S %p) |
| R | 24-hour time (%H:%M) |
| T | 24-hour time (%H:%M:%S) |

```puppet
$timestamp = Timestamp('2016-08-24T12:13:14')

# Notice the timestamp using a format that notices the ISO 8601 date format
notice($timestamp.strftime('%F')) # outputs '2016-08-24'

# Notice the timestamp using a format that notices weekday, month, day, time (as UTC), and year
notice($timestamp.strftime('%c')) # outputs 'Wed Aug 24 12:13:14 2016'

# Notice the timestamp using a specific timezone
notice($timestamp.strftime('%F %T %z', 'PST')) # outputs '2016-08-24 04:13:14 -0800'

# Notice the timestamp using timezone that is current for the evaluating process
notice($timestamp.strftime('%F %T', 'current')) # outputs the timestamp using the timezone for the current process
```

### Format directives applicable to `Timespan`:

| Format | Meaning |
| ------ | ------- |
| D | Number of Days |
| H | Hour of the day, 24-hour clock |
| M | Minute of the hour (00..59) |
| S | Second of the minute (00..59) |
| L | Millisecond of the second (000..999). Digits under millisecond are truncated to not produce 1000. |
| N | Fractional seconds digits, default is 9 digits (nanosecond). Digits under a specified length are truncated to avoid carry up |

The format directive that represents the highest magnitude in the format will be allowed to overflow.
I.e. if no "%D" is used but a "%H" is present, then the hours will be more than 23 in case the
timespan reflects more than a day.

```puppet
$duration = Timespan({ hours => 3, minutes => 20, seconds => 30 })

# Notice the duration using a format that outputs <hours>:<minutes>:<seconds>
notice($duration.strftime('%H:%M:%S')) # outputs '03:20:30'

# Notice the duration using a format that outputs <minutes>:<seconds>
notice($duration.strftime('%M:%S')) # outputs '200:30'
```

- Since 4.8.0


Signature 1

`strftime(Timespan $time_object, String $format)`

Signature 2

`strftime(Timestamp $time_object, String $format, Optional[String] $timezone)`

Signature 3

`strftime(String $format, Optional[String] $timezone)`

## `strip`

Strips leading and trailing spaces from a String

This function is compatible with the stdlib function with the same name.

The function does the following:
* For a `String` the conversion removes all leading and trailing ASCII white space characters such as space, tab, newline, and return.
  It does not remove other space-like characters like hard space (Unicode U+00A0). (Tip, `/^[[:space:]]/` regular expression
  matches all space-like characters).
* For an `Iterable[Variant[String, Numeric]]` (for example an `Array`) each value is processed and the conversion is not recursive.
* If the value is `Numeric` it is simply returned (this is for backwards compatibility).
* An error is raised for all other data types.

```puppet
" hello\n\t".strip()
strip(" hello\n\t")
```
Would both result in `"hello"`

```puppet
[" hello\n\t", " hi\n\t"].strip()
strip([" hello\n\t", " hi\n\t"])
```
Would both result in `['hello', 'hi']`


Signature 1

`strip(Numeric $arg)`

Signature 2

`strip(String $arg)`

Signature 3

`strip(Iterable[Variant[String, Numeric]] $arg)`

## `tag`

Add the specified tags to the containing class
or definition.  All contained objects will then acquire that tag, also.


`tag()`

## `tagged`

A boolean function that
tells you whether the current container is tagged with the specified tags.
The tags are ANDed, so that all of the specified tags must be included for
the function to return true.


`tagged()`

## `template`

Loads an ERB template from a module, evaluates it, and returns the resulting
value as a string.

The argument to this function should be a `<MODULE NAME>/<TEMPLATE FILE>`
reference, which will load `<TEMPLATE FILE>` from a module's `templates`
directory. (For example, the reference `apache/vhost.conf.erb` will load the
file `<MODULES DIRECTORY>/apache/templates/vhost.conf.erb`.)

This function can also accept:

* An absolute path, which can load a template file from anywhere on disk.
* Multiple arguments, which will evaluate all of the specified templates and
return their outputs concatenated into a single string.


`template()`

## `then`

Calls a [lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html)
with the given argument unless the argument is `undef`.
Returns `undef` if the argument is `undef`, and otherwise the result of giving the
argument to the lambda.

This is useful to process a sequence of operations where an intermediate
result may be `undef` (which makes the entire sequence `undef`).
The `then` function is especially useful with the function `dig` which
performs in a similar way "digging out" a value in a complex structure.

```puppet
$data = {a => { b => [{x => 10, y => 20}, {x => 100, y => 200}]}}
notice $data.dig(a, b, 1, x).then |$x| { $x * 2 }
```

Would notice the value 200

Contrast this with:

```puppet
$data = {a => { b => [{x => 10, y => 20}, {not_x => 100, why => 200}]}}
notice $data.dig(a, b, 1, x).then |$x| { $x * 2 }
```

Which would notice `undef` since the last lookup of 'x' results in `undef` which
is returned (without calling the lambda given to the `then` function).

As a result there is no need for conditional logic or a temporary (non local)
variable as the result is now either the wanted value (`x`) multiplied
by 2 or `undef`.

Calls to `then` can be chained. In the next example, a structure is using an offset based on
using 1 as the index to the first element (instead of 0 which is used in the language).
We are not sure if user input actually contains an index at all, or if it is
outside the range of available names.args.

```puppet
# Names to choose from
$names = ['Ringo', 'Paul', 'George', 'John']

# Structure where 'beatle 2' is wanted (but where the number refers
# to 'Paul' because input comes from a source using 1 for the first
# element).

$data = ['singer', { beatle => 2 }]
$picked = assert_type(String,
  # the data we are interested in is the second in the array,
  # a hash, where we want the value of the key 'beatle'
  $data.dig(1, 'beatle')
    # and we want the index in $names before the given index
    .then |$x| { $names[$x-1] }
    # so we can construct a string with that beatle's name
    .then |$x| { "Picked Beatle '${x}'" }
)
notice $picked
```

Would notice "Picked Beatle 'Paul'", and would raise an error if the result
was not a String.

* Since 4.5.0


`then(Any $arg, Callable[1,1] &$block)`

## `tree_each`

Runs a [lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html)
recursively and repeatedly using values from a data structure, then returns the unchanged data structure, or if
a lambda is not given, returns an `Iterator` for the tree.

This function takes one mandatory argument, one optional, and an optional block in this order:

1. An `Array`, `Hash`, `Iterator`, or `Object` that the function will iterate over.
2. An optional hash with the options:
   * `include_containers` => `Optional[Boolean]` # default `true` - if containers should be given to the lambda
   * `include_values` => `Optional[Boolean]` # default `true` - if non containers should be given to the lambda
   * `include_root` => `Optional[Boolean]` # default `true` - if the root container should be given to the lambda
   * `container_type` => `Optional[Type[Variant[Array, Hash, Object]]]` # a type that determines what a container is - can only
      be set to a type that matches the default `Variant[Array, Hash, Object]`.
   * `order` => `Enum[depth_first, breadth_first]` # default ´depth_first`, the order in which elements are visited
   * `include_refs` => `Optional[Boolean]` # default `false`, if attributes in objects marked as bing of `reference` kind
      should be included.
3. An optional lambda, which the function calls for each element in the first argument. It must
   accept one or two arguments; either `$path`, and `$value`, or just `$value`.

`$data.tree_each |$path, $value| { <PUPPET CODE BLOCK> }`
`$data.tree_each |$value| { <PUPPET CODE BLOCK> }`

or

`tree_each($data) |$path, $value| { <PUPPET CODE BLOCK> }`
`tree_each($data) |$value| { <PUPPET CODE BLOCK> }`

The parameter `$path` is always given as an `Array` containing the path that when applied to
the tree as `$data.dig(*$path) yields the `$value`.
The `$value` is the value at that path.

For `Array` values, the path will contain `Integer` entries with the array index,
and for `Hash` values, the path will contain the hash key, which may be `Any` value.
For `Object` containers, the entry is the name of the attribute (a `String`).

The tree is walked in either depth-first order, or in breadth-first order under the control of the
`order` option, yielding each `Array`, `Hash`, `Object`, and each entry/attribute.
The default is `depth_first` which means that children are processed before siblings.
An order of `breadth_first` means that siblings are processed before children.

```puppet
[1, [2, 3], 4]
```

If containers are skipped, results in:

* `depth_first` order `1`, `2`, `3`, `4`
* `breadth_first` order `1`, `4`,`2`, `3`

If containers and root are included, results in:

* `depth_first` order `[1, [2, 3], 4]`, `1`, `[2, 3]`, `2`, `3`, `4`
* `breadth_first` order `[1, [2, 3], 4]`, `1`, `[2, 3]`, `4`, `2`, `3`

Typical use of the `tree_each` function include:
* a more efficient way to iterate over a tree than first using `flatten` on an array
  as that requires a new (potentially very large) array to be created
* when a tree needs to be transformed and 'pretty printed' in a template
* avoiding having to write a special recursive function when tree contains hashes (flatten does
  not work on hashes)

```puppet
$data = [1, 2, [3, [4, 5]]]
$data.tree_each({include_containers => false}) |$v| { notice "$v" }
```

This would call the lambda 5 times with with the following values in sequence: `1`, `2`, `3`, `4`, `5`

```puppet
$data = [1, 2, [3, [4, 5]]]
$data.tree_each |$v| { notice "$v" }
```

This would call the lambda 7 times with the following values in sequence:
`1`, `2`, `[3, [4, 5]]`, `3`, `[4, 5]`, `4`, `5`

```puppet
$data = [1, 2, [3, [4, 5]]]
$data.tree_each({include_values => false, include_root => false}) |$v| { notice "$v" }
```

This would call the lambda 2 times with the following values in sequence:
`[3, [4, 5]]`, `[4, 5]`

Any Puppet Type system data type can be used to filter what is
considered to be a container, but it must be a narrower type than one of
the default `Array`, `Hash`, `Object` types - for example it is not possible to make a
`String` be a container type.

```puppet
$data = [1, {a => 'hello', b => [100, 200]}, [3, [4, 5]]]
$data.tree_each({container_type => Array, include_containers => false} |$v| { notice "$v" }
```

Would call the lambda 5 times with `1`, `{a => 'hello', b => [100, 200]}`, `3`, `4`, `5`

**Chaining** When calling `tree_each` without a lambda the function produces an `Iterator`
that can be chained into another iteration. Thus it is easy to use one of:

* `reverse_each` - get "leaves before root"
* `filter` - prune the tree
* `map` - transform each element

Note than when chaining, the value passed on is a `Tuple` with `[path, value]`.

```puppet
# A tree of some complexity (here very simple for readability)
$tree = [
 { name => 'user1', status => 'inactive', id => '10'},
 { name => 'user2', status => 'active', id => '20'}
]
notice $tree.tree_each.filter |$v| {
 $value = $v[1]
 $value =~ Hash and $value[status] == active
}
```

Would notice `[[[1], {name => user2, status => active, id => 20}]]`, which can then be processed
further as each filtered result appears as a `Tuple` with `[path, value]`.


For general examples that demonstrates iteration see the Puppet
[iteration](https://puppet.com/docs/puppet/latest/lang_iteration.html)
documentation.


Signature 1

`tree_each(Variant[Iterator, Array, Hash, Object] $tree, Optional[OptionsType] $options, Callable[2,2] &$block)`

Signature 2

`tree_each(Variant[Iterator, Array, Hash, Object] $tree, Optional[OptionsType] $options, Callable[1,1] &$block)`

Signature 3

`tree_each(Variant[Iterator, Array, Hash, Object] $tree, Optional[OptionsType] $options)`

## `type`

Returns the data type of a given value with a given degree of generality.

```puppet
type InferenceFidelity = Enum[generalized, reduced, detailed]

function type(Any $value, InferenceFidelity $fidelity = 'detailed') # returns Type
```

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

``` puppet
notice type([3.14, 42], 'generalized')
notice type([3.14, 42], 'reduced'')
notice type([3.14, 42], 'detailed')
notice type([3.14, 42])
```

Would notice the four values:

1. `Array[Numeric]`
2. `Array[Numeric, 2, 2]`
3. `Tuple[Float[3.14], Integer[42,42]]]`
4. `Tuple[Float[3.14], Integer[42,42]]]`


Signature 1

`type(Any $value, Optional[Enum[detailed]] $inference_method)`

Signature 2

`type(Any $value, Enum[reduced] $inference_method)`

Signature 3

`type(Any $value, Enum[generalized] $inference_method)`

## `unique`

Produces a unique set of values from an `Iterable` argument.

* If the argument is a `String`, the unique set of characters are returned as a new `String`.
* If the argument is a `Hash`, the resulting hash associates a set of keys with a set of unique values.
* For all other types of `Iterable` (`Array`, `Iterator`) the result is an `Array` with
  a unique set of entries.
* Comparison of all `String` values are case sensitive.
* An optional code block can be given - if present it is given each candidate value and its return is used instead of the given value. This
  enables transformation of the value before comparison. The result of the lambda is only used for comparison.
* The optional code block when used with a hash is given each value (not the keys).

```puppet
# will produce 'abc'
"abcaabb".unique
```

```puppet
# will produce ['a', 'b', 'c']
['a', 'b', 'c', 'a', 'a', 'b'].unique
```

```puppet
# will produce { ['a', 'b'] => [10], ['c'] => [20]}
{'a' => 10, 'b' => 10, 'c' => 20}.unique

# will produce { 'a' => 10, 'c' => 20 } (use first key with first value)
Hash.new({'a' => 10, 'b' => 10, 'c' => 20}.unique.map |$k, $v| { [ $k[0] , $v[0]] })

# will produce { 'b' => 10, 'c' => 20 } (use last key with first value)
Hash.new({'a' => 10, 'b' => 10, 'c' => 20}.unique.map |$k, $v| { [ $k[-1] , $v[0]] })
```

```
# will produce [3, 2, 1]
[1,2,2,3,3].reverse_each.unique
```

```puppet
# will produce [['sam', 'smith'], ['sue', 'smith']]
[['sam', 'smith'], ['sam', 'brown'], ['sue', 'smith']].unique |$x| { $x[0] }

# will produce [['sam', 'smith'], ['sam', 'brown']]
[['sam', 'smith'], ['sam', 'brown'], ['sue', 'smith']].unique |$x| { $x[1] }

# will produce ['aBc', 'bbb'] (using a lambda to make comparison using downcased (%d) strings)
['aBc', 'AbC', 'bbb'].unique |$x| { String($x,'%d') }

# will produce {[a] => [10], [b, c, d, e] => [11, 12, 100]}
{a => 10, b => 11, c => 12, d => 100, e => 11}.unique |$v| { if $v > 10 { big } else { $v } }
```

Note that for `Hash` the result is slightly different than for the other data types. For those the result contains the
*first-found* unique value, but for `Hash` it contains associations from a set of keys to the set of values clustered by the
equality lambda (or the default value equality if no lambda was given). This makes the `unique` function more versatile for hashes
in general, while requiring that the simple computation of "hash's unique set of values" is performed as `$hsh.map |$k, $v| { $v }.unique`.
(Generally, it's meaningless to compute the unique set of hash keys because they are unique by definition. However, the
situation can change if the hash keys are processed with a different lambda for equality. For this unique computation,
first map the hash to an array of its keys.)
If the more advanced clustering is wanted for one of the other data types, simply transform it into a `Hash` as shown in the
following example.

```puppet
# Array ['a', 'b', 'c'] to Hash with index results in
# {0 => 'a', 1 => 'b', 2 => 'c'}
Hash(['a', 'b', 'c'].map |$i, $v| { [$i, $v]})

# String "abc" to Hash with index results in
# {0 => 'a', 1 => 'b', 2 => 'c'}
Hash(Array("abc").map |$i,$v| { [$i, $v]})
"abc".to(Array).map |$i,$v| { [$i, $v]}.to(Hash)
```


Signature 1

`unique(String $string, Optional[Callable[String]] &$block)`

Signature 2

`unique(Hash $hash, Optional[Callable[Any]] &$block)`

Signature 3

`unique(Array $array, Optional[Callable[Any]] &$block)`

Signature 4

`unique(Iterable $iterable, Optional[Callable[Any]] &$block)`

## `unwrap`

Unwraps a Sensitive value and returns the wrapped object.
Returns the Value itself, if it is not Sensitive.

```puppet
$plaintext = 'hunter2'
$pw = Sensitive.new($plaintext)
notice("Wrapped object is $pw") #=> Prints "Wrapped object is Sensitive [value redacted]"
$unwrapped = $pw.unwrap
notice("Unwrapped object is $unwrapped") #=> Prints "Unwrapped object is hunter2"
```

You can optionally pass a block to unwrap in order to limit the scope where the
unwrapped value is visible.

```puppet
$pw = Sensitive.new('hunter2')
notice("Wrapped object is $pw") #=> Prints "Wrapped object is Sensitive [value redacted]"
$pw.unwrap |$unwrapped| {
  $conf = inline_template("password: ${unwrapped}\n")
  Sensitive.new($conf)
} #=> Returns a new Sensitive object containing an interpolated config file
# $unwrapped is now out of scope
```


Signature 1

`unwrap(Sensitive $arg, Optional[Callable] &$block)`

Signature 2

`unwrap(Any $arg, Optional[Callable] &$block)`

## `upcase`

Converts a String, Array or Hash (recursively) into upper case.

This function is compatible with the stdlib function with the same name.

The function does the following:
* For a `String`, its upper case version is returned. This is done using Ruby system locale which handles some, but not all
  special international up-casing rules (for example German double-s ß is upcased to "SS", whereas upper case double-s
  is downcased to ß).
* For `Array` and `Hash` the conversion to upper case is recursive and each key and value must be convertible by
  this function.
* When a `Hash` is converted, some keys could result in the same key - in those cases, the
  latest key-value wins. For example if keys "aBC", and "abC" where both present, after upcase there would only be one
  key "ABC".
* If the value is `Numeric` it is simply returned (this is for backwards compatibility).
* An error is raised for all other data types.

Please note: This function relies directly on Ruby's String implementation and as such may not be entirely UTF8 compatible.
To ensure best compatibility please use this function with Ruby 2.4.0 or greater - https://bugs.ruby-lang.org/issues/10085.

```puppet
'hello'.upcase()
upcase('hello')
```
Would both result in `"HELLO"`

```puppet
['a', 'b'].upcase()
upcase(['a', 'b'])
```
Would both result in `['A', 'B']`

```puppet
{'a' => 'hello', 'b' => 'goodbye'}.upcase()
```
Would result in `{'A' => 'HELLO', 'B' => 'GOODBYE'}`

```puppet
['a', 'b', ['c', ['d']], {'x' => 'y'}].upcase
```
Would result in `['A', 'B', ['C', ['D']], {'X' => 'Y'}]`


Signature 1

`upcase(Numeric $arg)`

Signature 2

`upcase(String $arg)`

Signature 3

`upcase(Array[StringData] $arg)`

Signature 4

`upcase(Hash[StringData, StringData] $arg)`

## `values`

Returns the values of a hash as an Array

```puppet
$hsh = {"apples" => 3, "oranges" => 4 }
$hsh.values()
values($hsh)
# both results in the array [3, 4]
```

* Note that a hash in the puppet language accepts any data value (including `undef`) unless
  it is constrained with a `Hash` data type that narrows the allowed data types.
* For an empty hash, an empty array is returned.
* The order of the values is the same as the order in the hash (typically the order in which they were added).


`values(Hash $hsh)`

## `versioncmp`

Compares two version numbers.

Prototype:

    $result = versioncmp(a, b)

Where a and b are arbitrary version strings.

Optional parameter ignore_trailing_zeroes is used to ignore unnecessary
trailing version numbers like .0 or .0.00

This function returns:

* `1` if version a is greater than version b
* `0` if the versions are equal
* `-1` if version a is less than version b

This function uses the same version comparison algorithm used by Puppet's
`package` type.


`versioncmp(String $a, String $b, Optional[Boolean] $ignore_trailing_zeroes)`

## `warning`

Logs a message on the server at level `warning`.


`warning(Any *$values)`

### Parameters


* `*values` --- The values to log.

Return type(s): `Undef`. 

## `with`

Calls a [lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html)
with the given arguments and returns the result.

Since a lambda's scope is
[local](https://puppet.com/docs/puppet/latest/lang_lambdas.html#lambda-scope)
to the lambda, you can use the `with` function to create private blocks of code within a
class using variables whose values cannot be accessed outside of the lambda.

```puppet
# Concatenate three strings into a single string formatted as a list.
$fruit = with("apples", "oranges", "bananas") |$x, $y, $z| {
  "${x}, ${y}, and ${z}"
}
$check_var = $x
# $fruit contains "apples, oranges, and bananas"
# $check_var is undefined, as the value of $x is local to the lambda.
```


`with(Any *$arg, Callable &$block)`

## `yaml_data`

The `yaml_data` is a hiera 5 `data_hash` data provider function.
See [the configuration guide documentation](https://puppet.com/docs/puppet/latest/hiera_config_yaml_5.html#configuring-a-hierarchy-level-built-in-backends) for
how to use this function.


`yaml_data(Struct[{path=>String[1]}] $options, Puppet::LookupContext $context)`

