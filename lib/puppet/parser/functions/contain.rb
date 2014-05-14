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
"
) do |classes|
  scope = self

  containing_resource = scope.resource

  included = scope.function_include(classes)
  included.each do |resource|
    if ! scope.catalog.edge?(containing_resource, resource)
      scope.catalog.add_edge(containing_resource, resource)
    end
  end
end
