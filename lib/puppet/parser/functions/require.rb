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
- Since 4.7.0 Returns an Array[Type[Class]] with references to the required classes
") do |classes|
  call_function('require', classes)
  Puppet.warn_once('deprecations', '3xfunction#require', _("Calling function_require via the Scope class is deprecated. Use Scope#call_function instead"))
end
