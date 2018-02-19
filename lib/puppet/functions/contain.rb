# Makes one or more classes be contained inside the current class.
# If any of these classes are undeclared, they will be declared as if
# there were declared with the `include` function.
# Accepts a class name, an array of class names, or a comma-separated
# list of class names.
#
# A contained class will not be applied before the containing class is
# begun, and will be finished before the containing class is finished.
#
# You must use the class's full name;
# relative names are not allowed. In addition to names in string form,
# you may also directly use `Class` and `Resource` `Type`-values that are produced by
# evaluating resource and relationship expressions.
#
# The function returns an array of references to the classes that were contained thus
# allowing the function call to `contain` to directly continue.
#
# - Since 4.0.0 support for `Class` and `Resource` `Type`-values, absolute names
# - Since 4.7.0 a value of type `Array[Type[Class[n]]]` is returned with all the contained classes
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
    if Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING,
        {:operation => 'contain'})
    end

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