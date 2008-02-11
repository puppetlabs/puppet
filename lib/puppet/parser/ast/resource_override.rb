require 'puppet/parser/ast/resource'

class Puppet::Parser::AST
    # Set a parameter on a resource specification created somewhere else in the
    # configuration.  The object is responsible for verifying that this is allowed.
    class ResourceOverride < Resource
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
            object = @object.safeevaluate(scope)

            hash = {}

            # Evaluate all of the specified params.
            params = @params.collect { |param|
                param.safeevaluate(scope)
            }

            # Now we just create a normal resource, but we call a very different
            # method on the scope.
            obj = Puppet::Parser::Resource.new(
                :type => object.type,
                :title => object.title,
                :params => params,
                :file => @file,
                :line => @line,
                :source => scope.source,
                :scope => scope
            )

            # Now we tell the scope that it's an override, and it behaves as
            # necessary.
            scope.compile.add_override(obj)

            obj
        end

        # Create our ResourceDef.  Handles type checking for us.
        def initialize(hash)
            @checked = false
            super

            #self.typecheck(@type.value)
        end
    end
end
