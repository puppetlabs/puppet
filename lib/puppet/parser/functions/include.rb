# Include the specified classes
Puppet::Parser::Functions::newfunction(:include, :arity => -2, :doc =>
"Declares one or more classes, causing the resources in them to be
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
you may also directly use Class and Resource Type values that are produced by
the future parser's resource and relationship expressions.

- Since < 3.0.0
- Since 4.0.0 support for class and resource type values, absolute names
") do |vals|

  # Unify call patterns (if called with nested arrays), make names absolute if
  # wanted and evaluate the classes
  compiler.evaluate_classes(
  transform_and_assert_classnames(
      vals.is_a?(Array) ? vals.flatten : [vals]),
      self, false)
end
