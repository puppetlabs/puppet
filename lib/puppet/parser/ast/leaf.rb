class Puppet::Parser::AST
    # The base class for all of the leaves of the parse trees.  These
    # basically just have types and values.  Both of these parameters
    # are simple values, not AST objects.
    class Leaf < AST
        attr_accessor :value, :type

        # Return our value.
        def evaluate(scope)
            return @value
        end

        # Print the value in parse tree context.
        def tree(indent = 0)
            return ((@@indent * indent) + self.typewrap(self.value))
        end

        def to_s
            return @value
        end
    end

    # The boolean class.  True or false.  Converts the string it receives
    # to a Ruby boolean.
    class Boolean < AST::Leaf

        # Use the parent method, but then convert to a real boolean.
        def initialize(hash)
            super

            unless @value == 'true' or @value == 'false'
                raise Puppet::DevError,
                    "'%s' is not a boolean" % @value
            end
            if @value == 'true'
                @value = true
            else
                @value = false
            end
        end
    end

    # The base string class.
    class String < AST::Leaf
        # Interpolate the string looking for variables, and then return
        # the result.
        def evaluate(scope)
            return scope.strinterp(@value)
        end
    end

    # The base string class.
    class FlatString < AST::Leaf
        # Interpolate the string looking for variables, and then return
        # the result.
        def evaluate(scope)
            return @value
        end
    end

    # The 'default' option on case statements and selectors.
    class Default < AST::Leaf; end

    # Capitalized words; used mostly for type-defaults, but also
    # get returned by the lexer any other time an unquoted capitalized
    # word is found.
    class Type < AST::Leaf; end

    # Lower-case words.
    class Name < AST::Leaf; end

    # A simple variable.  This object is only used during interpolation;
    # the VarDef class is used for assignment.
    class Variable < Name
        # Looks up the value of the object in the scope tree (does
        # not include syntactical constructs, like '$' and '{}').
        def evaluate(scope)
            begin
                return scope.lookupvar(@value)
            rescue Puppet::ParseError => except
                except.line = self.line
                except.file = self.file
                raise except
            rescue => detail
                error = Puppet::DevError.new(detail)
                error.line = self.line
                error.file = self.file
                error.backtrace = detail.backtrace
                raise error
            end
        end
    end

end
