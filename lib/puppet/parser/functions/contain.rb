# Called within a class definition, establishes a containment
# relationship with another class

Puppet::Parser::Functions::newfunction(
  :contain,
  :arity => -2,
  :doc => "Contain one or more classes inside the current class. Any
given undeclared classes will be declared as if called with 'include'.
Contained classes will be evaluated during the evaluation of the
containing class."
) do |args|
  scope = self

  include_function = Puppet::Parser::Functions.function("include")
  scope.send(include_function, args)

  args.each do |class_name|
    class_resource = scope.catalog.resource("Class", class_name)

    if scope.catalog.edge?(scope.resource, class_resource)
      raise ParseError, "Cannot create duplicate containment relationship; #{scope.resource} already contains #{class_resource}"
    end

    scope.catalog.add_edge(scope.resource, class_resource)
  end
end
