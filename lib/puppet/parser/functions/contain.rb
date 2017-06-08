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

The function returns an array of references to the classes that were contained thus
allowing the function call to `contain` to directly continue.

- Since 4.0.0 support for Class and Resource Type values, absolute names
- Since 4.7.0 an Array[Type[Class[n]]] is returned with all the contained classes
"
) do |classes|
  # Call the 4.x version of this function in case 3.x ruby code uses this function
  Puppet.warn_once('deprecations', '3xfunction#contain', _("Calling function_contain via the Scope class is deprecated. Use Scope#call_function instead"))
  call_function('contain', classes)
end
