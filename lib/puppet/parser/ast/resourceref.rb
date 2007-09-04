require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # A reference to an object.  Only valid as an rvalue.
    class ResourceRef < AST::Branch
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
        def evaluate(hash)
            scope = hash[:scope]

            # We want a lower-case type.
            objtype = @type.downcase
            title = @title.safeevaluate(:scope => scope)

            unless builtintype?(objtype)
                if dtype = scope.finddefine(objtype)
                    objtype = dtype.classname
                elsif objtype == "class"
                    # Look up the full path to the class
                    if classobj = scope.findclass(title)
                        title = classobj.classname
                    else
                        raise Puppet::ParseError, "Could not find class %s" % title
                    end
                else
                    raise Puppet::ParseError, "Could not find resource type %s" % objtype
                end
            end

            return Puppet::Parser::Resource::Reference.new(
                :type => objtype, :title => title
            )
        end
    end
end
