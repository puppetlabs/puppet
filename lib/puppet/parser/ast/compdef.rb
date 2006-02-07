class Puppet::Parser::AST
    # Define a new component.  This basically just stores the
    # associated parse tree by name in our current scope.  Note that
    # there is currently a mismatch in how we look up components -- it
    # usually uses scopes, but sometimes uses '@@settypes'.
    # FIXME This class should verify that each of its direct children
    # has an abstractable name -- i.e., if a file does not include a
    # variable in its name, then the user is essentially guaranteed to
    # encounter an error if the component is instantiated more than
    # once.
    class CompDef < AST::Branch
        attr_accessor :name, :args, :code, :keyword

        def each
            [@name,@args,@code].each { |child| yield child }
        end

        # Store the parse tree.
        def evaluate(scope)
            name = @name.safeevaluate(scope)
            args = @args.safeevaluate(scope)

            begin
                comp = AST::Component.new(
                    :name => name,
                    :args => args,
                    :code => @code
                )
                comp.keyword = self.keyword
                scope.settype(name, comp)
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

            # Set a default keyword
            @keyword = "define"
            super

            #Puppet.debug "Defining type %s" % @name.value

            # we need to both mark that a given argument is valid,
            # and we need to also store any provided default arguments
            # FIXME This creates a global list of types and their
            # acceptable arguments.  This should really be scoped
            # instead.
            @@settypes[@name.value] = self
        end

        def tree(indent = 0)
            return [
                @name.tree(indent + 1),
                ((@@indline * 4 * indent) + self.typewrap("define")),
                @args.tree(indent + 1),
                @code.tree(indent + 1),
            ].join("\n")
        end

        def to_s
            return "define %s(%s) {\n%s }" % [@name, @args, @code]
        end

        # Check whether a given argument is valid.  Searches up through
        # any parent classes that might exist.
        def validarg?(param)
            found = false
            if @args.is_a?(AST::ASTArray)
                found = @args.detect { |arg|
                    if arg.is_a?(AST::ASTArray)
                        arg[0].value == param
                    else
                        arg.value == param
                    end
                }
            else
                found = @args.value == param
                #Puppet.warning "got arg %s" % @args.inspect
                #hash[@args.value] += 1
            end

            if found
                return true
            # a nil parentclass is an empty astarray
            # stupid but true
            elsif @parentclass
                parent = @@settypes[@parentclass.value]
                if parent and parent != []
                    return parent.validarg?(param)
                else
                    raise Puppet::Error, "Could not find parent class %s" %
                        @parentclass.value
                end
            else
                return false
            end

        end
    end

end
