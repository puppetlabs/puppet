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
            title = [title] unless title.is_a?(Array)

            if @type.to_s.downcase == "class"
                resource_type = "class"
                title = title.collect { |t| qualified_class(scope, t) }
            else
                resource_type = qualified_type(scope)
            end

            title = title.collect { |t| Puppet::Parser::Resource::Reference.new(
                :type => resource_type, :title => t
            ) }
            return title.pop if title.length == 1
            return title
        end

        # Look up a fully qualified class name.
        def qualified_class(scope, title)
            # Look up the full path to the class
            if classobj = scope.find_hostclass(title)
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
                if dtype = scope.find_definition(objtype)
                    objtype = dtype.classname
                else
                    raise Puppet::ParseError, "Could not find resource type %s" % objtype
                end
            end
            return objtype
        end

        def to_s
            if title.is_a?(ASTArray)
                "#{type.to_s.capitalize}#{title}"
            else
                "#{type.to_s.capitalize}[#{title}]"
            end
        end
    end
end
