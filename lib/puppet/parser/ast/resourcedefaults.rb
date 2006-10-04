class Puppet::Parser::AST
    # A statement syntactically similar to an ResourceDef, but uses a
    # capitalized object type and cannot have a name.  
    class ResourceDefaults < AST::Branch
        attr_accessor :type, :params

        def each
            [@type,@params].each { |child| yield child }
        end

        # As opposed to ResourceDef, this stores each default for the given
        # object type.
        def evaluate(hash)
            scope = hash[:scope]
            type = @type.downcase
            params = @params.safeevaluate(:scope => scope)

            parsewrap do
                scope.setdefaults(type, params)
            end
        end

        def tree(indent = 0)
            return [
                @type.tree(indent + 1),
                ((@@indline * 4 * indent) + self.typewrap(self.pin)),
                @params.tree(indent + 1)
            ].join("\n")
        end

        def to_s
            return "%s { %s }" % [@type,@params]
        end
    end

end

# $Id$
