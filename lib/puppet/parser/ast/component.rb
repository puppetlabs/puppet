class Puppet::Parser::AST
    # Evaluate the stored parse tree for a given component.  This will
    # receive the arguments passed to the component and also the type and
    # name of the component.
    class Component < AST::Branch
        class << self
            attr_accessor :name
        end

        # The class name
        @name = :component

        attr_accessor :type, :args, :code, :scope, :keyword

        #def evaluate(scope,hash,objtype,objname)
        def evaluate(hash)
            origscope = hash[:scope]
            objtype = hash[:type]
            objname = hash[:name]
            arguments = hash[:arguments] || {}

            pscope = origscope
            #pscope = if ! Puppet[:lexical] or hash[:asparent] == false
            #    origscope
            #else
            #    @scope
            #end
            scope = pscope.newscope(
                :type => @type,
                :name => objname,
                :keyword => self.keyword
            )
            newcontext = hash[:newcontext]

            unless self.is_a? AST::HostClass and ! newcontext
                #scope.warning "Setting context to %s" % self.object_id
                scope.context = self.object_id
            end
            @scope = scope

            # Additionally, add a tag for whatever kind of class
            # we are
            scope.tag(@type)

            unless objname.nil?
                scope.tag(objname)
            end

            # define all of the arguments in our local scope
            if self.args
                # Verify that all required arguments are either present or
                # have been provided with defaults.
                # FIXME This should probably also require each parent
                # class's arguments...
                self.args.each { |arg, default|
                    unless arguments.include?(arg)
                        if defined? default and ! default.nil?
                            arguments[arg] = default
                            #Puppet.debug "Got default %s for %s in %s" %
                            #    [default.inspect, arg.inspect, objname.inspect]
                        else
                            error = Puppet::ParseError.new(
                                "Must pass %s to %s of type %s" %
                                    [arg.inspect,objname,@type]
                            )
                            error.line = self.line
                            error.file = self.file
                            raise error
                        end
                    end
                }
            end

            # Set each of the provided arguments as variables in the
            # component's scope.
            arguments["name"] = objname
            arguments.each { |arg,value|
                begin
                    scope.setvar(arg,arguments[arg])
                rescue Puppet::ParseError => except
                    except.line = self.line
                    except.file = self.file
                    raise except
                rescue Puppet::ParseError => except
                    except.line = self.line
                    except.file = self.file
                    raise except
                rescue => except
                    error = Puppet::ParseError.new(except.message)
                    error.line = self.line
                    error.file = self.file
                    error.backtrace = except.backtrace
                    raise error
                end
            }

            # Now just evaluate the code with our new bindings.
            self.code.safeevaluate(:scope => scope)

            # If we're being evaluated as a parent class, we want to return the
            # scope, so it can be overridden and such, but if not, we want to 
            # return a TransBucket of our objects.
            if hash.include?(:asparent)
                return scope
            else
                return scope.to_trans
            end
        end

        # Check whether a given argument is valid.  Searches up through
        # any parent classes that might exist.
        def validarg?(param)
            found = false
            unless @args.is_a? Array
                @args = [@args]
            end

            found = @args.detect { |arg|
                if arg.is_a? Array
                    arg[0] == param
                else
                    arg == param
                end
            }

            if found
                # It's a valid arg for us
                return true
            elsif defined? @parentclass and @parentclass
                # Else, check any existing parent
                parent = @scope.lookuptype(@parentclass)
                if parent and parent != []
                    return parent.validarg?(param)
                else
                    raise Puppet::Error, "Could not find parent class %s" %
                        @parentclass
                end
            else
                # Or just return false
                return false
            end
        end
    end
end

# $Id$
