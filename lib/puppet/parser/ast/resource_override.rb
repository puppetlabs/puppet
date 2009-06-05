require 'puppet/parser/ast/resource'

class Puppet::Parser::AST
    # Set a parameter on a resource specification created somewhere else in the
    # configuration.  The object is responsible for verifying that this is allowed.
    class ResourceOverride < Resource

        associates_doc

        attr_accessor :object
        attr_reader :params

        # Iterate across all of our children.
        def each
            [@object,@params].flatten.each { |param|
                #Puppet.debug("yielding param %s" % param)
                yield param
            }
        end

        # Does not actually return an object; instead sets an object
        # in the current scope.
        def evaluate(scope)
            # Get our object reference.
            resource = @object.safeevaluate(scope)

            hash = {}

            # Evaluate all of the specified params.
            params = @params.collect { |param|
                param.safeevaluate(scope)
            }

            # Now we just create a normal resource, but we call a very different
            # method on the scope.
            resource = [resource] unless resource.is_a?(Array)

            resource = resource.collect do |r|
                res = Puppet::Parser::Resource.new(
                    :type => r.type,
                    :title => r.title,
                    :params => params,
                    :file => file,
                    :line => line,
                    :source => scope.source,
                    :scope => scope
                )

                # Now we tell the scope that it's an override, and it behaves as
                # necessary.
                scope.compiler.add_override(res)

                res
            end
            # decapsulate array in case of only one item
            return resource.pop if resource.length == 1
            return resource
        end

        # Create our ResourceDef.  Handles type checking for us.
        def initialize(hash)
            @checked = false
            super

            #self.typecheck(@type.value)
        end
    end
end
