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
        attr_accessor :type, :args, :code, :keyword

        def each
            [@type,@args,@code].each { |child| yield child }
        end

        # Store the parse tree.
        def evaluate(hash)
            scope = hash[:scope]
            type = @type.safeevaluate(:scope => scope)
            args = @args.safeevaluate(:scope => scope)

            begin
                comp = AST::Component.new(
                    :type => type,
                    :args => args,
                    :code => @code
                )
                comp.keyword = self.keyword
                scope.settype(type, comp)
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

            #if @parentclass
            #    Puppet.notice "Parent class of %s is %s" %
            #        [@type.value, @parentclass.value]
            #end

            #Puppet.debug "Defining type %s" % @type.value
        end

        def tree(indent = 0)
            return [
                @type.tree(indent + 1),
                ((@@indline * 4 * indent) + self.typewrap("define")),
                @args.tree(indent + 1),
                @code.tree(indent + 1),
            ].join("\n")
        end

        def to_s
            return "define %s(%s) {\n%s }" % [@type, @args, @code]
        end
    end
end

# $Id$
