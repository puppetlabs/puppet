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

            unless @value == true or @value == false
                raise Puppet::DevError,
                    "'%s' is not a boolean" % @value
            end
            @value
        end
    end

    # The base string class.
    class String < AST::Leaf
        # Interpolate the string looking for variables, and then return
        # the result.
        def evaluate(scope)
            return scope.strinterp(@value, file, line)
        end
    end

    # An uninterpreted string.
    class FlatString < AST::Leaf
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

    # double-colon separated class names
    class ClassName < AST::Leaf; end

    # undef values; equiv to nil
    class Undef < AST::Leaf; end

    # Host names, either fully qualified or just the short name
    class HostName < AST::Leaf
        def initialize(hash)
            super

            unless @value =~ %r{^[0-9a-zA-Z\-]+(\.[0-9a-zA-Z\-]+)*$}
                raise Puppet::DevError,
                    "'%s' is not a valid hostname" % @value
            end
        end
    end

    # A simple variable.  This object is only used during interpolation;
    # the VarDef class is used for assignment.
    class Variable < Name
        # Looks up the value of the object in the scope tree (does
        # not include syntactical constructs, like '$' and '{}').
        def evaluate(scope)
            parsewrap do
                return scope.lookupvar(@value)
            end
        end
    end
end
