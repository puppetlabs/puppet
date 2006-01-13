class Puppet::Parser::AST
    # A reference to an object.  Only valid as an rvalue.
    class ObjectRef < AST::Branch
        attr_accessor :name, :type

        def each
            [@type,@name].flatten.each { |param|
                #Puppet.debug("yielding param %s" % param)
                yield param
            }
        end

        # Evaluate our object, but just return a simple array of the type
        # and name.
        def evaluate(scope)
            objtype = @type.safeevaluate(scope)
            objnames = @name.safeevaluate(scope)

            # it's easier to always use an array, even for only one name
            unless objnames.is_a?(Array)
                objnames = [objnames]
            end

            # Verify we can find the object.
            begin
                object = scope.lookuptype(objtype)
            rescue Puppet::ParseError => except
                except.line = self.line
                except.file = self.file
                raise except
            rescue => detail
                error = Puppet::ParseError.new(detail)
                error.line = self.line
                error.file = self.file
                error.stack = caller
                raise error
            end
            Puppet.debug "ObjectRef returned type %s" % object

            # should we implicitly iterate here?
            # yes, i believe that we essentially have to...
            objnames.collect { |objname|
                if object.is_a?(AST::Component)
                    objname = "%s[%s]" % [objtype,objname]
                    objtype = "component"
                end
                [objtype,objname]
            }.reject { |obj| obj.nil? }
        end

        def tree(indent = 0)
            return [
                @type.tree(indent + 1),
                @name.tree(indent + 1),
                ((@@indline * indent) + self.typewrap(self.pin))
            ].join("\n")
        end

        def to_s
            return "%s[%s]" % [@name,@type]
        end
    end

end
