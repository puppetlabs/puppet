require 'puppet/parser/parser'
require 'puppet/util/warnings'
require 'puppet/util/errors'
require 'puppet/util/inline_docs'
require 'puppet/parser/ast/leaf'
require 'puppet/dsl'

class Puppet::Resource::Type
    Puppet::ResourceType = self
    include Puppet::Util::InlineDocs
    include Puppet::Util::Warnings
    include Puppet::Util::Errors

    RESOURCE_SUPERTYPES = [:hostclass, :node, :definition]

    attr_accessor :file, :line, :doc, :code, :ruby_code, :parent, :resource_type_collection
    attr_reader :type, :namespace, :arguments, :behaves_like

    RESOURCE_SUPERTYPES.each do |t|
        define_method("#{t}?") { self.type == t }
    end

    require 'puppet/indirector'
    extend Puppet::Indirector
    indirects :resource_type, :terminus_class => :parser

    def self.from_pson(data)
        name = data.delete('name') or raise ArgumentError, "Resource Type names must be specified"
        type = data.delete('type') || "definition"

        data = data.inject({}) { |result, ary| result[ary[0].intern] = ary[1]; result }

        new(type, name, data)
    end

    def to_pson_data_hash
        data = [:code, :doc, :line, :file, :parent].inject({}) do |hash, param|
            next hash unless value = self.send(param)
            hash[param.to_s] = value
            hash
        end

        data['arguments'] = arguments.dup

        data['name'] = name
        data['type'] = type

        data
    end

    def to_pson(*args)
        to_pson_data_hash.to_pson(*args)
    end

    # Are we a child of the passed class?  Do a recursive search up our
    # parentage tree to figure it out.
    def child_of?(klass)
        return false unless parent

        return true if klass == parent_type
        return parent_type.child_of?(klass)
    end

    # Now evaluate the code associated with this class or definition.
    def evaluate_code(resource)
        scope = resource.scope

        if tmp = evaluate_parent_type(resource)
            scope = tmp
        end

        scope = subscope(scope, resource)

        set_resource_parameters(resource, scope)

        code.safeevaluate(scope) if code

        evaluate_ruby_code(resource, scope) if ruby_code
    end

    def initialize(type, name, options = {})
        @type = type.to_s.downcase.to_sym
        raise ArgumentError, "Invalid resource supertype '#{type}'" unless RESOURCE_SUPERTYPES.include?(@type)

        name = convert_from_ast(name) if name.is_a?(Puppet::Parser::AST::HostName)

        set_name_and_namespace(name)

        [:code, :doc, :line, :file, :parent].each do |param|
            next unless value = options[param]
            send(param.to_s + "=", value)
        end

        set_arguments(options[:arguments])
    end

    # This is only used for node names, and really only when the node name
    # is a regexp.
    def match(string)
        return string.to_s.downcase == name unless name_is_regex?

        return @name =~ string
    end

    # Add code from a new instance to our code.
    def merge(other)
        fail "#{name} is not a class; cannot add code to it" unless type == :hostclass
        fail "#{other.name} is not a class; cannot add code from it" unless other.type == :hostclass

        if parent and other.parent and parent != other.parent
            fail "Cannot merge classes with different parent classes (#{name} => #{parent} vs. #{other.name} => #{other.parent})"
        end

        # We know they're either equal or only one is set, so keep whichever parent is specified.
        self.parent ||= other.parent

        if other.doc
            self.doc ||= ""
            self.doc += other.doc
        end

        # This might just be an empty, stub class.
        return unless other.code

        unless self.code
            self.code = other.code
            return
        end

        array_class = Puppet::Parser::AST::ASTArray
        unless self.code.is_a?(array_class)
            self.code = array_class.new(:children => [self.code])
        end

        if other.code.is_a?(array_class)
            code.children += other.code.children
        else
            code.children << other.code
        end
    end

    # Make an instance of our resource type.  This is only possible
    # for those classes and nodes that don't have any arguments, and is
    # only useful for things like the 'include' function.
    def mk_plain_resource(scope)
        type == :definition and raise ArgumentError, "Cannot create resources for defined resource types"
        resource_type = type == :hostclass ? :class : :node

        # Make sure our parent class has been evaluated, if we have one.
        if parent and ! scope.catalog.resource(resource_type, parent)
            parent_type.mk_plain_resource(scope)
        end

        # Do nothing if the resource already exists; this makes sure we don't
        # get multiple copies of the class resource, which helps provide the
        # singleton nature of classes.
        if resource = scope.catalog.resource(resource_type, name)
            return resource
        end

        resource = Puppet::Parser::Resource.new(resource_type, name, :scope => scope, :source => self)
        scope.compiler.add_resource(scope, resource)
        scope.catalog.tag(*resource.tags)
        resource
    end

    def name
        return @name unless @name.is_a?(Regexp)
        return @name.source.downcase.gsub(/[^-\w:.]/,'').sub(/^\.+/,'')
    end

    def name_is_regex?
        @name.is_a?(Regexp)
    end

    def parent_type
        return nil unless parent

        unless @parent_type ||= resource_type_collection.send(type, parent)
            fail Puppet::ParseError, "Could not find parent resource type '#{parent}'"
        end

        @parent_type
    end

    # Set any arguments passed by the resource as variables in the scope.
    def set_resource_parameters(resource, scope)
        set = {}
        resource.to_hash.each do |param, value|
            param = param.to_sym
            fail Puppet::ParseError, "#{resource.ref} does not accept attribute #{param}" unless valid_parameter?(param)

            exceptwrap { scope.setvar(param.to_s, value) }

            set[param] = true
        end

        # Verify that all required arguments are either present or
        # have been provided with defaults.
        arguments.each do |param, default|
            param = param.to_sym
            next if set.include?(param)
            
            # Even if 'default' is a false value, it's an AST value, so this works fine
            fail Puppet::ParseError, "Must pass #{param} to #{resource.ref}" unless default

            scope.setvar(param.to_s, default.safeevaluate(scope))
        end

        scope.setvar("title", resource.title) unless set.include? :title
        scope.setvar("name", resource.name) unless set.include? :name
        scope.class_set(self.name,scope) if hostclass?
    end

    # Create a new subscope in which to evaluate our code.
    def subscope(scope, resource)
        scope.newscope :resource => resource, :namespace => self.namespace, :source => self
    end

    # Check whether a given argument is valid.
    def valid_parameter?(param)
        param = param.to_s

        return true if param == "name"
        return true if Puppet::Type.metaparam?(param)
        return false unless defined?(@arguments)
        return true if arguments.include?(param)
        return false
    end

    def set_arguments(arguments)
        @arguments = {}
        return if arguments.nil?

        arguments.each do |arg, default|
            arg = arg.to_s
            warn_if_metaparam(arg, default)
            @arguments[arg] = default
        end
    end

    private

    def convert_from_ast(name)
        value = name.value
        if value.is_a?(Puppet::Parser::AST::Regex)
            name = value.value
        else
            name = value
        end
    end

    def evaluate_parent_type(resource)
        #return unless klass = parent_type and parent_resource = resource.scope.compiler.catalog.resource(:class, klass.name)
        return unless klass = parent_type and parent_resource = resource.catalog.resource(:class, klass.name)
        parent_resource.evaluate unless parent_resource.evaluated?
        return parent_scope(resource.scope, klass)
    end

    def evaluate_ruby_code(resource, scope)
        Puppet::DSL::ResourceAPI.new(resource, scope, ruby_code).evaluate
    end

    # Split an fq name into a namespace and name
    def namesplit(fullname)
        ary = fullname.split("::")
        n = ary.pop || ""
        ns = ary.join("::")
        return ns, n
    end

    def parent_scope(scope, klass)
        scope.class_scope(klass) || raise(Puppet::DevError, "Could not find scope for #{klass.name}")
    end

    def set_name_and_namespace(name)
        if name.is_a?(Regexp)
            @name = name
            @namespace = ""
        else
            @name = name.to_s.downcase
            @namespace, ignored_shortname = namesplit(@name)
        end
    end

    def warn_if_metaparam(param, default)
        return unless Puppet::Type.metaparamclass(param)

        if default
            warnonce "#{param} is a metaparam; this value will inherit to all contained resources"
        else
            raise Puppet::ParseError, "#{param} is a metaparameter; please choose another parameter name in the #{self.name} definition"
        end
    end
end

