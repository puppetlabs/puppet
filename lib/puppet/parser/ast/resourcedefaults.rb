require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # A statement syntactically similar to an ResourceDef, but uses a
    # capitalized object type and cannot have a name.  
    class ResourceDefaults < AST::Branch
        attr_accessor :type, :params

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
    end
end
