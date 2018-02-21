# Requires the specified classes.
# Evaluate one or more classes, adding the required class as a dependency.
#
# The relationship metaparameters work well for specifying relationships
# between individual resources, but they can be clumsy for specifying
# relationships between classes.  This function is a superset of the
# 'include' function, adding a class relationship so that the requiring
# class depends on the required class.
#
# Warning: using require in place of include can lead to unwanted dependency cycles.
#
# For instance the following manifest, with 'require' instead of 'include' would produce a nasty
# dependence cycle, because notify imposes a before between File[/foo] and Service[foo]:
#
# ```puppet
# class myservice {
#   service { foo: ensure => running }
# }
#
# class otherstuff {
#    include myservice
#    file { '/foo': notify => Service[foo] }
# }
# ```
#
# Note that this function only works with clients 0.25 and later, and it will
# fail if used with earlier clients.
#
# You must use the class's full name;
# relative names are not allowed. In addition to names in string form,
# you may also directly use Class and Resource Type values that are produced when evaluating
# resource and relationship expressions.
#
# - Since 4.0.0 Class and Resource types, absolute names
# - Since 4.7.0 Returns an Array[Type[Class]] with references to the required classes
#
Puppet::Functions.create_function(:require, Puppet::Functions::InternalFunction) do
  dispatch :require_impl do
    scope_param
    # The function supports what the type system sees as Ruby runtime objects, and
    # they cannot be parameterized to find what is actually valid instances.
    # The validation is instead done in the function body itself via a call to
    # `transform_and_assert_classnames` on the calling scope.
    required_repeated_param 'Any', :names
  end

  def require_impl(scope, *classes)
    if Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING,
        {:operation => 'require'})
    end

    # Make call patterns uniform and protected against nested arrays, also make
    # names absolute if so desired.
    classes = scope.transform_and_assert_classnames(classes.flatten)

    result = classes.map {|name| Puppet::Pops::Types::TypeFactory.host_class(name) }

    # This is the same as calling the include function (but faster) since it again
    # would otherwise need to perform the optional absolute name transformation
    # (for no reason since they are already made absolute here).
    #
    scope.compiler.evaluate_classes(classes, scope, false)
    krt = scope.environment.known_resource_types

    classes.each do |klass|
      # lookup the class in the scopes
      klass = (classobj = krt.find_hostclass(klass)) ? classobj.name : nil
      raise Puppet::ParseError.new(_("Could not find class %{klass}") % { klass: klass }) unless klass
      ref = Puppet::Resource.new(:class, klass)
      resource = scope.resource
      resource.set_parameter(:require, [resource[:require]].flatten.compact << ref)
    end
    result
  end
end
