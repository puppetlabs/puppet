require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # A statement syntactically similar to an ResourceDef, but uses a
    # capitalized object type and cannot have a name.
    class ResourceDefaults < AST::Branch
        attr_accessor :type, :params

        associates_doc

        # As opposed to ResourceDef, this stores each default for the given
        # object type.
        def evaluate(scope)
            # Use a resource reference to canonize the type
            ref = Puppet::Resource::Reference.new(@type, "whatever")
            type = ref.type
            params = @params.safeevaluate(scope)

            parsewrap do
                scope.setdefaults(type, params)
            end
        end
    end
end
