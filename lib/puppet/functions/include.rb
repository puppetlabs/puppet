# Declares one or more classes, which causes the resources in them to be
# evaluated and added to the catalog. Accepts a class name, an array of class
# names, or a comma-separated list of class names.
#
# You can use the `include` function multiple times on the same class, and it declares
# a given class only once. If a class declared with `include` has any parameters, Puppet
# automatically looks up values for them in Hiera, using `<class name>::<parameter name>`
# as the lookup key.
#
# Contrast this behavior with resource-like class declarations, such as:
#
# ``` puppet
# class {'name': parameter => 'value',}
# ```
#
# These must be used in only one place per class and can directly set parameters.
#
# Avoid using both `include` and resource-like declarations with the same class.
#
# The `include` function does not cause classes to be contained in the class
# where they are declared. For that, see the `contain` function.
#
# It also does not create a dependency relationship between the declared class and the
# surrounding class. For that, see the `require` function.
#
# You must use a class's full name; relative names are not allowed. In addition to
# providing class names in string form, you can also directly use Class and Resource Type
# values produced by evaluating resource and relationship expressions.
#
# @since < 3.0.0
# @since 4.0.0 support for class and resource type values, absolute names
# @since 4.7.0 returns an Array[Type[Class]] of all included classes
#
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
    if Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING,
        {:operation => 'include'})
    end

    classes = scope.transform_and_assert_classnames(classes.flatten)
    result = classes.map {|name| Puppet::Pops::Types::TypeFactory.host_class(name) }
    scope.compiler.evaluate_classes(classes, scope, false)

    # Result is an Array[Class, 1, n] which allows chaining other operations
    result
  end
end
