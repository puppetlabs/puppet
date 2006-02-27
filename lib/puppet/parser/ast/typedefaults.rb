class Puppet::Parser::AST
    # A statement syntactically similar to an ObjectDef, but uses a
    # capitalized object type and cannot have a name.  
    class TypeDefaults < AST::Branch
        attr_accessor :type, :params

        def each
            [@type,@params].each { |child| yield child }
        end

        # As opposed to ObjectDef, this stores each default for the given
        # object type.
        def evaluate(hash)
            scope = hash[:scope]
            type = @type.safeevaluate(:scope => scope)
            params = @params.safeevaluate(:scope => scope)

            begin
                scope.setdefaults(type.downcase,params)
            rescue Puppet::ParseError => except
                except.line = self.line
                except.file = self.file
                raise except
            rescue => detail
                error = Puppet::ParseError.new(detail)
                error.line = self.line
                error.file = self.file
                error.backtrace = detail.backtrace
                raise error
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
