require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # A reference to an object.  Only valid as an rvalue.
    class ResourceReference < AST::Branch
        attr_accessor :title, :type
        # Is the type a builtin type?
        def builtintype?(type)
            if typeklass = Puppet::Type.type(type)
                return typeklass
            else
                return false
            end
        end

        def each
            [@type,@title].flatten.each { |param|
                #Puppet.debug("yielding param %s" % param)
                yield param
            }
        end

        # Evaluate our object, but just return a simple array of the type
        # and name.
        def evaluate(scope)
            title = @title.safeevaluate(scope)
            if @type.to_s.downcase == "class"
                objtype = "class"
                title = qualified_class(scope, title)
            else
                objtype = qualified_type(scope)
            end

            return Puppet::Parser::Resource::Reference.new(
                :type => objtype, :title => title
            )
        end

        # Look up a fully qualified class name.
        def qualified_class(scope, title)
            # Look up the full path to the class
            if classobj = scope.findclass(title)
                title = classobj.classname
            else
                raise Puppet::ParseError, "Could not find class %s" % title
            end
        end

        # Look up a fully-qualified type.  This method is
        # also used in AST::Resource.
        def qualified_type(scope, title = nil)
            # We want a lower-case type.  For some reason.
            objtype = @type.downcase
            unless builtintype?(objtype)
                if dtype = scope.finddefine(objtype)
                    objtype = dtype.classname
                else
                    raise Puppet::ParseError, "Could not find resource type %s" % objtype
                end
            end
            return objtype
        end
    end
end
