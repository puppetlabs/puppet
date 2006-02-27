require 'puppet/parser/ast/compdef'

class Puppet::Parser::AST
    # Define a new class.  Syntactically similar to component definitions,
    # but classes are always singletons -- only one can exist on a given
    # host.
    class ClassDef < AST::CompDef
        attr_accessor :parentclass

        def each
            if @parentclass
                #[@type,@args,@parentclass,@code].each { |child| yield child }
                [@type,@parentclass,@code].each { |child| yield child }
            else
                #[@type,@args,@code].each { |child| yield child }
                [@type,@code].each { |child| yield child }
            end
        end

        # Store our parse tree according to type.
        def evaluate(hash)
            scope = hash[:scope]
            type = @type.safeevaluate(:scope => scope)
            #args = @args.safeevaluate(:scope => scope)

                #:args => args,
            arghash = {
                :type => type,
                :code => @code
            }

            if @parentclass
                arghash[:parentclass] = @parentclass.safeevaluate(:scope => scope)
            end

            #Puppet.debug("defining hostclass '%s' with arguments [%s]" %
            #    [type,args])

            begin
                hclass = HostClass.new(arghash)
                hclass.keyword = self.keyword
                scope.settype(type, hclass)
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
            @keyword = "class"
            super
        end

        def tree(indent = 0)
                #@args.tree(indent + 1),
            return [
                @type.tree(indent + 1),
                ((@@indline * 4 * indent) + self.typewrap("class")),
                @parentclass ? @parentclass.tree(indent + 1) : "",
                @code.tree(indent + 1),
            ].join("\n")
        end

        def to_s
            return "class %s(%s) inherits %s {\n%s }" %
                [@type, @parentclass, @code]
                #[@type, @args, @parentclass, @code]
        end
    end

end
