# Include the specified classes
# For documentation see the 3.x stub
Puppet::Functions.create_function(:include, Puppet::Functions::InternalFunction) do
  dispatch :include do
    scope_param
    # The function supports what the type system sees as Ruby runtime objects, and
    # they cannot be parameterized to find what is actually valid instances.
    # The validation is instead done in the function body itself via a call to
    # `transform_and_assert_classnames` on the calling scope.
    required_repeated_param 'Any', :names
  end

  def include(scope, *classes)
    classes = scope.transform_and_assert_classnames(classes.flatten)
    result = classes.map {|name| Puppet::Pops::Types::TypeFactory.host_class(name) }
    scope.compiler.evaluate_classes(classes, scope, false)

    # Result is an Array[Class, 1, n] which allows chaining other operations
    result
  end
end
