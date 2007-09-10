require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # Evaluate the stored parse tree for a given component.  This will
    # receive the arguments passed to the component and also the type and
    # name of the component.
    class Definition < AST::Branch
        include Puppet::Util
        include Puppet::Util::Warnings
        include Puppet::Util::MethodHelper
        class << self
            attr_accessor :name
        end

        # The class name
        @name = :definition

        attr_accessor :classname, :arguments, :code, :scope, :keyword
        attr_accessor :exported, :namespace, :parser, :virtual

        # These are retrieved when looking up the superclass
        attr_accessor :name

        attr_reader :parentclass

        def child_of?(klass)
            false
        end

        def evaluate(options)
            origscope = options[:scope]
            resource = options[:resource]

            # Create a new scope.
            scope = subscope(origscope, resource)

            # Additionally, add a tag for whatever kind of class
            # we are
            if @classname != "" and ! @classname.nil?
                @classname.split(/::/).each { |tag| scope.resource.tag(tag) }
            end

            [resource.name, resource.title].each do |str|
                unless str.nil? or str =~ /[^\w]/ or str == ""
                    scope.resource.tag(str)
                end
            end

            set_resource_parameters(scope, resource)

            if self.code
                return self.code.safeevaluate(:scope => scope)
            else
                return nil
            end
        end

        def initialize(hash = {})
            @arguments = nil
            @parentclass = nil
            super

            # Convert the arguments to a hash for ease of later use.
            if @arguments
                unless @arguments.is_a? Array
                    @arguments = [@arguments]
                end
                oldargs = @arguments
                @arguments = {}
                oldargs.each do |arg, val|
                    @arguments[arg] = val
                end
            else
                @arguments = {}
            end

            # Deal with metaparams in the argument list.
            @arguments.each do |arg, defvalue|
                next unless Puppet::Type.metaparamclass(arg)
                if defvalue
                    warnonce "%s is a metaparam; this value will inherit to all contained resources" % arg
                else
                    raise Puppet::ParseError,
                        "%s is a metaparameter; please choose another name" %
                        name
                end
            end
        end

        def find_parentclass
            @parser.findclass(namespace, parentclass)
        end

        # Set our parent class, with a little check to avoid some potential
        # weirdness.
        def parentclass=(name)
            if name == self.classname
                parsefail "Parent classes must have dissimilar names"
            end

            @parentclass = name
        end

        # Hunt down our class object.
        def parentobj
            if @parentclass
                # Cache our result, since it should never change.
                unless defined?(@parentobj)
                    unless tmp = find_parentclass
                        parsefail "Could not find %s %s" % [self.class.name, @parentclass]
                    end

                    if tmp == self
                        parsefail "Parent classes must have dissimilar names"
                    end

                    @parentobj = tmp
                end
                @parentobj
            else
                nil
            end
        end

        # Create a new subscope in which to evaluate our code.
        def subscope(scope, resource)
            args = {
                :resource => resource,
                :keyword => self.keyword,
                :namespace => self.namespace,
                :source => self
            }

            oldscope = scope
            scope = scope.newscope(args)
            scope.source = self

            return scope
        end

        def to_s
            classname
        end

        # Check whether a given argument is valid.  Searches up through
        # any parent classes that might exist.
        def validattr?(param)
            param = param.to_s

            if @arguments.include?(param)
                # It's a valid arg for us
                return true
            elsif param == "name"
                return true
#            elsif defined? @parentclass and @parentclass
#                # Else, check any existing parent
#                if parent = @scope.lookuptype(@parentclass) and parent != []
#                    return parent.validarg?(param)
#                elsif builtin = Puppet::Type.type(@parentclass)
#                    return builtin.validattr?(param)
#                else
#                    raise Puppet::Error, "Could not find parent class %s" %
#                        @parentclass
#                end
            elsif Puppet::Type.metaparam?(param)
                return true
            else
                # Or just return false
                return false
            end
        end

        private

        # Set any arguments passed by the resource as variables in the scope.
        def set_resource_parameters(scope, resource)
            args = symbolize_options(resource.to_hash || {})

            # Verify that all required arguments are either present or
            # have been provided with defaults.
            if self.arguments
                self.arguments.each { |arg, default|
                    arg = symbolize(arg)
                    unless args.include?(arg)
                        if defined? default and ! default.nil?
                            default = default.safeevaluate :scope => scope
                            args[arg] = default
                            #Puppet.debug "Got default %s for %s in %s" %
                            #    [default.inspect, arg.inspect, @name.inspect]
                        else
                            parsefail "Must pass %s to %s of type %s" %
                                    [arg, resource.title, @classname]
                        end
                    end
                }
            end

            # Set each of the provided arguments as variables in the
            # definition's scope.
            args.each { |arg,value|
                unless validattr?(arg)
                    parsefail "%s does not accept attribute %s" % [@classname, arg]
                end

                exceptwrap do
                    scope.setvar(arg.to_s, args[arg])
                end
            }

            scope.setvar("title", resource.title) unless args.include? :title
            scope.setvar("name", resource.name) unless args.include? :name
        end
    end
end
