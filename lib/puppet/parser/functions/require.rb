# Requires the specified classes

  Puppet::Parser::Functions::newfunction(
    :require,
    :arity => -2,
    :doc =>"Evaluate one or more classes,  adding the required class as a dependency.

The relationship metaparameters work well for specifying relationships
between individual resources, but they can be clumsy for specifying
relationships between classes.  This function is a superset of the
'include' function, adding a class relationship so that the requiring
class depends on the required class.

Warning: using require in place of include can lead to unwanted dependency cycles.

For instance the following manifest, with 'require' instead of 'include' would produce a nasty dependence cycle, because notify imposes a before between File[/foo] and Service[foo]:

    class myservice {
      service { foo: ensure => running }
    }

    class otherstuff {
      include myservice
      file { '/foo': notify => Service[foo] }
    }

Note that this function only works with clients 0.25 and later, and it will
fail if used with earlier clients.

You must use the class's full name;
relative names are not allowed. In addition to names in string form,
you may also directly use Class and Resource Type values that are produced when evaluating
resource and relationship expressions.

- Since 4.0.0 Class and Resource types, absolute names
") do |vals|
  # Make call patterns uniform and protected against nested arrays, also make
  # names absolute if so desired.
  vals = transform_and_assert_classnames(vals.is_a?(Array) ? vals.flatten : [vals])

  # This is the same as calling the include function (but faster) since it again
  # would otherwise need to perform the optional absolute name transformation
  # (for no reason since they are already made absolute here).
  #
  compiler.evaluate_classes(vals, self, false)

  vals.each do |klass|
    # lookup the class in the scopes
    if classobj = find_hostclass(klass)
      klass = classobj.name
    else
      raise Puppet::ParseError, "Could not find class #{klass}"
    end

    # This is a bit hackish, in some ways, but it's the only way
    # to configure a dependency that will make it to the client.
    # The 'obvious' way is just to add an edge in the catalog,
    # but that is considered a containment edge, not a dependency
    # edge, so it usually gets lost on the client.
    ref = Puppet::Resource.new(:class, klass)
    resource.set_parameter(:require, [resource[:require]].flatten.compact << ref)
  end
end
