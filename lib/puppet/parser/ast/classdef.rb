require 'puppet/parser/ast/compdef'

class Puppet::Parser::AST
    # Define a new class.  Syntactically similar to component definitions,
    # but classes are always singletons -- only one can exist on a given
    # host.
    class ClassDef < AST::CompDef
        attr_accessor :parentclass

        def each
            if @parentclass
                #[@name,@args,@parentclass,@code].each { |child| yield child }
                [@name,@parentclass,@code].each { |child| yield child }
            else
                #[@name,@args,@code].each { |child| yield child }
                [@name,@code].each { |child| yield child }
            end
        end

        # Store our parse tree according to name.
        def evaluate(scope)
            name = @name.safeevaluate(scope)
            #args = @args.safeevaluate(scope)

                #:args => args,
            arghash = {
                :name => name,
                :code => @code
            }

            if @parentclass
                arghash[:parentclass] = @parentclass.safeevaluate(scope)
            end

            #Puppet.debug("defining hostclass '%s' with arguments [%s]" %
            #    [name,args])

            begin
                scope.settype(name,
                    HostClass.new(arghash)
                )
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

        def initialize(hash)
            @parentclass = nil
            super
        end

        def tree(indent = 0)
                #@args.tree(indent + 1),
            return [
                @name.tree(indent + 1),
                ((@@indline * 4 * indent) + self.typewrap("class")),
                @parentclass ? @parentclass.tree(indent + 1) : "",
                @code.tree(indent + 1),
            ].join("\n")
        end

        def to_s
            return "class %s(%s) inherits %s {\n%s }" %
                [@name, @parentclass, @code]
                #[@name, @args, @parentclass, @code]
        end
    end

end
