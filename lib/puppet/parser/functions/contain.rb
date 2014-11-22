# Called within a class definition, establishes a containment
# relationship with another class

Puppet::Parser::Functions::newfunction(
  :contain,
  :arity => -2,
  :doc => "Contain one or more classes inside the current class. If any of
these classes are undeclared, they will be declared as if called with the
`include` function. Accepts a class name, an array of class names, or a
comma-separated list of class names.

A contained class will not be applied before the containing class is
begun, and will be finished before the containing class is finished.

You must use the class's full name;
relative names are not allowed. In addition to names in string form,
you may also directly use Class and Resource Type values that are produced by
evaluating resource and relationship expressions.

- Since 4.0.0 support for Class and Resource Type values, absolute names
"
) do |classes|
  scope = self

  # Make call patterns uniform and protected against nested arrays, also make
  # names absolute if so desired.
  classes = transform_and_assert_classnames(classes.is_a?(Array) ? classes.flatten : [classes])

  containing_resource = scope.resource

  # This is the same as calling the include function but faster and does not rely on the include
  # function (which is a statement) to return something (it should not).
  (compiler.evaluate_classes(classes, self, false) || []).each do |resource|
    if ! scope.catalog.edge?(containing_resource, resource)
      scope.catalog.add_edge(containing_resource, resource)
    end
  end
end
