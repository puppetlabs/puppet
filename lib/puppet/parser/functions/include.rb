# Include the specified classes
Puppet::Parser::Functions::newfunction(:include, :arity => -2, :doc =>
"Declares one or more classes, causing the resources in them to be
evaluated and added to the catalog. Accepts a class name, an array of class
names, or a comma-separated list of class names.

The `include` function can be used multiple times on the same class and will
only declare a given class once. If a class declared with `include` has any
parameters, Puppet will automatically look up values for them in Hiera, using
`<class name>::<parameter name>` as the lookup key.

Contrast this behavior with resource-like class declarations
(`class {'name': parameter => 'value',}`), which must be used in only one place
per class and can directly set parameters. You should avoid using both `include`
and resource-like declarations with the same class.

The `include` function does not cause classes to be contained in the class
where they are declared. For that, see the `contain` function. It also
does not create a dependency relationship between the declared class and the
surrounding class; for that, see the `require` function.") do |vals|
    if vals.is_a?(Array)
      # Protect against array inside array
      vals = vals.flatten
    else
      vals = [vals]
    end

    # The 'false' disables lazy evaluation.
    klasses = compiler.evaluate_classes(vals, self, false)

    missing = vals.find_all do |klass|
      ! klasses.include?(klass)
    end

    unless missing.empty?
      # Throw an error if we didn't evaluate all of the classes.
      str = "Could not find class"
      str += "es" if missing.length > 1

      str += " " + missing.join(", ")

      if n = namespaces and ! n.empty? and n != [""]
        str += " in namespaces #{@namespaces.join(", ")}"
      end
      self.fail Puppet::ParseError, str
    end
end
