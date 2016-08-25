# Requires the specified classes
# For documentation see the 3.x function stub
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
      raise Puppet::ParseError.new("Could not find class #{klass}") unless klass
      ref = Puppet::Resource.new(:class, klass)
      resource = scope.resource
      resource.set_parameter(:require, [resource[:require]].flatten.compact << ref)
    end
    result
  end
end
