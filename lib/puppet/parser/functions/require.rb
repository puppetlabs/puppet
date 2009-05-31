# Requires the specified classes
Puppet::Parser::Functions::newfunction(:require,
        :doc =>"Evaluate one or more classes,  adding the required class as a dependency.

The relationship metaparameters work well for specifying relationships
between individual resources, but they can be clumsy for specifying 
relationships between classes.  This function is a superset of the
'include' function, adding a class relationship so that the requiring
class depends on the required class.

.. Warning::
  using require in place of include can lead to unwanted dependency cycles.
  For instance the following manifest, with 'require' instead of 'include'
  would produce a nasty dependence cycle, because notify imposes a before
  between File[/foo] and Service[foo]::

    class myservice {
       service { foo: ensure => running }
    }

    class otherstuff {
       include myservice
       file { '/foo': notify => Service[foo] }
    }

") do |vals|
        send(:function_include, vals)
        vals = [vals] unless vals.is_a?(Array)

        # add a relation from ourselves to each required klass
        vals.each do |klass|
            compiler.catalog.add_edge(resource, findresource(:class, klass))
        end
end
