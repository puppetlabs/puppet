# Called within a class definition, establishes a containment
# relationship with another class
# For documentation, see the 3.x stub
#
Puppet::Functions.create_function(:contain, Puppet::Functions::InternalFunction) do
  dispatch :contain do
    scope_param
    # The function supports what the type system sees as Ruby runtime objects, and
    # they cannot be parameterized to find what is actually valid instances.
    # The validation is instead done in the function body itself via a call to
    # `transform_and_assert_classnames` on the calling scope.
    required_repeated_param 'Any', :names
  end

  def contain(scope, *classes)
    # Make call patterns uniform and protected against nested arrays, also make
    # names absolute if so desired.
    classes = scope.transform_and_assert_classnames(classes.flatten)

    result = classes.map {|name| Puppet::Pops::Types::TypeFactory.host_class(name) }
    containing_resource = scope.resource

    # This is the same as calling the include function but faster and does not rely on the include
    # function.
    (scope.compiler.evaluate_classes(classes, scope, false) || []).each do |resource|
      if ! scope.catalog.edge?(containing_resource, resource)
        scope.catalog.add_edge(containing_resource, resource)
      end
    end
    # Result is an Array[Class, 1, n] which allows chaining other operations
    result
  end
end