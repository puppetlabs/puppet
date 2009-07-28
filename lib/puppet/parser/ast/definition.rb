require 'puppet/parser/ast/branch'

require 'puppet/util/warnings'

# The AST class for defined types, which is also the base class
# nodes and classes.
class Puppet::Parser::AST::Definition < Puppet::Parser::AST::Branch
    include Puppet::Util::Warnings
    class << self
        attr_accessor :name
    end

    associates_doc

    # The class name
    @name = :definition

    attr_accessor :classname, :arguments, :code, :scope, :keyword
    attr_accessor :exported, :namespace, :parser, :virtual, :name

    attr_reader :parentclass

    def child_of?(klass)
        false
    end

    def get_classname(scope)
        self.classname
    end

    # Create a resource that knows how to evaluate our actual code.
    def evaluate(scope)
        resource = Puppet::Parser::Resource.new(:type => self.class.name, :title => get_classname(scope), :scope => scope, :source => scope.source)

        scope.catalog.tag(*resource.tags)

        scope.compiler.add_resource(scope, resource)

        return resource
    end

    # Now evaluate the code associated with this class or definition.
    def evaluate_code(resource)
        # Create a new scope.
        scope = subscope(resource.scope, resource)

        set_resource_parameters(scope, resource)

        if self.code
            return self.code.safeevaluate(scope)
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
                raise Puppet::ParseError, "%s is a metaparameter; please choose another parameter name in the %s definition" % [arg, self.classname]
            end
        end
    end

    def find_parentclass
        @parser.find_hostclass(namespace, parentclass)
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
        return nil unless @parentclass

        # Cache our result, since it should never change.
        unless defined?(@parentobj)
            unless tmp = find_parentclass
                parsefail "Could not find %s parent %s" % [self.class.name, @parentclass]
            end

            if tmp == self
                parsefail "Parent classes must have dissimilar names"
            end

            @parentobj = tmp
        end
        @parentobj
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
                arg = arg.to_sym
                unless args.include?(arg)
                    if defined? default and ! default.nil?
                        default = default.safeevaluate scope
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
