# Include the specified classes
Puppet::Parser::Functions::newfunction(:include, :doc => "Evaluate one or more classes.") do |vals|
        vals = [vals] unless vals.is_a?(Array)

        # The 'false' disables lazy evaluation.
        klasses = compiler.evaluate_classes(vals, self, false)

        missing = vals.find_all do |klass|
            ! klasses.include?(klass)
        end

        unless missing.empty?
            # Throw an error if we didn't evaluate all of the classes.
            str = "Could not find class"
            if missing.length > 1
                str += "es"
            end

            str += " " + missing.join(", ")

            if n = namespaces and ! n.empty? and n != [""]
                str += " in namespaces %s" % @namespaces.join(", ")
            end
            self.fail Puppet::ParseError, str
        end
end
