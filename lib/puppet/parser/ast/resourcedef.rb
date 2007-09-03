require 'puppet/parser/ast/branch'

# Any normal puppet object declaration.  Can result in a class or a 
# component, in addition to builtin types.
class Puppet::Parser::AST
class ResourceDef < AST::Branch
    attr_accessor :title, :type, :exported, :virtual
    attr_reader :params

    # probably not used at all
    def []=(index,obj)
        @params[index] = obj
    end

    # probably not used at all
    def [](index)
        return @params[index]
    end

    # Iterate across all of our children.
    def each
        [@type,@title,@params].flatten.each { |param|
            #Puppet.debug("yielding param %s" % param)
            yield param
        }
    end

    # Does not actually return an object; instead sets an object
    # in the current scope.
    def evaluate(hash)
        scope = hash[:scope]
        @scope = scope
        hash = {}

        # Get our type and name.
        objtype = @type

        # Disable definition inheritance, for now.  8/27/06, luke
        #if objtype == "super"
        #    objtype = supertype()
        #    @subtype = true
        #else
            @subtype = false
        #end

        # Evaluate all of the specified params.
        paramobjects = @params.collect { |param|
            param.safeevaluate(:scope => scope)
        }

        # Now collect info from our parent.
        parentname = nil
        if @subtype
            parentname = supersetup(hash)
        end

        objtitles = nil
        # Determine our name if we have one.
        if self.title
            objtitles = @title.safeevaluate(:scope => scope)
            # it's easier to always use an array, even for only one name
            unless objtitles.is_a?(Array)
                objtitles = [objtitles]
            end
        else
            if parentname
                objtitles = [parentname]
            else
                # See if they specified the name as a parameter instead of
                # as a normal name (i.e., before the colon).
                unless object # we're a builtin
                    if objclass = Puppet::Type.type(objtype)
                        namevar = objclass.namevar

                        tmp = hash["name"] || hash[namevar.to_s] 

                        if tmp
                            objtitles = [tmp]
                        end
                    else
                        # This isn't grammatically legal.
                        raise Puppet::ParseError, "Got a resource with no title"
                    end
                end
            end
        end

        # This is where our implicit iteration takes place; if someone
        # passed an array as the name, then we act just like the called us
        # many times.
        objtitles.collect { |objtitle|
            exceptwrap :type => Puppet::ParseError do
                exp = self.exported || scope.exported?
                # We want virtual to be true if exported is true.  We can't
                # just set :virtual => self.virtual in the initialization,
                # because sometimes the :virtual attribute is set *after*
                # :exported, in which case it clobbers :exported if :exported
                # is true.  Argh, this was a very tough one to track down.
                virt = self.virtual || scope.virtual? || exported
                obj = Puppet::Parser::Resource.new(
                    :type => objtype,
                    :title => objtitle,
                    :params => paramobjects,
                    :file => @file,
                    :line => @line,
                    :exported => exp,
                    :virtual => virt,
                    :source => scope.source,
                    :scope => scope
                )

                # And then store the resource in the scope.
                # XXX At some point, we need to switch all of this to return
                # objects instead of storing them like this.
                scope.compile.store_resource(scope, obj)
                obj
            end
        }.reject { |obj| obj.nil? }
    end

    # Create our ResourceDef.  Handles type checking for us.
    def initialize(hash)
        @checked = false
        super

        #self.typecheck(@type.value)
    end

    # Set the parameters for our object.
    def params=(params)
        if params.is_a?(AST::ASTArray)
            @params = params
        else
            @params = AST::ASTArray.new(
                :line => params.line,
                :file => params.file,
                :children => [params]
            )
        end
    end

    def supercomp
        unless defined? @supercomp
            if @scope and comp = @scope.inside
                @supercomp = comp
            else
                error = Puppet::ParseError.new(
                    "'super' is only valid within definitions"
                )
                error.line = self.line
                error.file = self.file
                raise error
            end
        end
        @supercomp
    end

    # Take all of the arguments of our parent and add them into our own,
    # without overriding anything.
    def supersetup(hash)
        comp = supercomp()

        # Now check each of the arguments from the parent.
        comp.arguments.each do |name, value|
            unless hash.has_key? name
                hash[name] = value
            end
        end

        # Return the parent name, so it can be used if appropriate.
        return comp.name
    end

    # Retrieve our supertype.
    def supertype
        unless defined? @supertype
            if parent = supercomp.parentclass
                @supertype = parent
            else
                error = Puppet::ParseError.new(
                    "%s does not have a parent class" % comp.type
                )
                error.line = self.line
                error.file = self.file
                raise error
            end
        end
        @supertype
    end

    # Print this object out.
    def tree(indent = 0)
        return [
            @type.tree(indent + 1),
            @title.tree(indent + 1),
            ((@@indline * indent) + self.typewrap(self.pin)),
            @params.collect { |param|
                begin
                    param.tree(indent + 1)
                rescue NoMethodError => detail
                    Puppet.err @params.inspect
                    error = Puppet::DevError.new(
                        "failed to tree a %s" % self.class
                    )
                    error.set_backtrace detail.backtrace
                    raise error
                end
            }.join("\n")
        ].join("\n")
    end

    def to_s
        return "%s => { %s }" % [@title,
            @params.collect { |param|
                param.to_s
            }.join("\n")
        ]
    end
end
end

# $Id$
