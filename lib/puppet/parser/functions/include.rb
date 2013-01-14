# Include the specified classes
Puppet::Parser::Functions::newfunction(:include, :arity => -2, :doc => "Evaluate one or more classes.") do |vals|
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
