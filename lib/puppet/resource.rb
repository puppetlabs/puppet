require 'puppet'
require 'puppet/util/tagging'
require 'puppet/util/pson'

# The simplest resource class.  Eventually it will function as the
# base class for all resource-like behaviour.
class Puppet::Resource
    include Puppet::Util::Tagging

    require 'puppet/resource/type_collection_helper'
    include Puppet::Resource::TypeCollectionHelper

    extend Puppet::Util::Pson
    include Enumerable
    attr_accessor :file, :line, :catalog, :exported, :virtual, :validate_parameters, :strict
    attr_reader :namespaces

    require 'puppet/indirector'
    extend Puppet::Indirector
    indirects :resource, :terminus_class => :ral

    ATTRIBUTES = [:file, :line, :exported]

    def self.from_pson(pson)
        raise ArgumentError, "No resource type provided in pson data" unless type = pson['type']
        raise ArgumentError, "No resource title provided in pson data" unless title = pson['title']

        resource = new(type, title)

        if params = pson['parameters']
            params.each { |param, value| resource[param] = value }
        end

        if tags = pson['tags']
            tags.each { |tag| resource.tag(tag) }
        end

        ATTRIBUTES.each do |a|
            if value = pson[a.to_s]
                resource.send(a.to_s + "=", value)
            end
        end

        resource.exported ||= false

        resource
    end

    def to_pson_data_hash
        data = ([:type, :title, :tags] + ATTRIBUTES).inject({}) do |hash, param|
            next hash unless value = self.send(param)
            hash[param.to_s] = value
            hash
        end

        data["exported"] ||= false

        params = self.to_hash.inject({}) do |hash, ary|
            param, value = ary

            # Don't duplicate the title as the namevar
            next hash if param == namevar and value == title
            if value.is_a? Puppet::Resource
                hash[param] = value.to_s
            else
                hash[param] = value
            end
            hash
        end

        data["parameters"] = params unless params.empty?

        data
    end

    def to_pson(*args)
        to_pson_data_hash.to_pson(*args)
    end

    # Proxy these methods to the parameters hash.  It's likely they'll
    # be overridden at some point, but this works for now.
    %w{has_key? keys length delete empty? <<}.each do |method|
        define_method(method) do |*args|
            @parameters.send(method, *args)
        end
    end

    # Set a given parameter.  Converts all passed names
    # to lower-case symbols.
    def []=(param, value)
        validate_parameter(param) if validate_parameters
        @parameters[parameter_name(param)] = value
    end

    # Return a given parameter's value.  Converts all passed names
    # to lower-case symbols.
    def [](param)
        @parameters[parameter_name(param)]
    end

    def ==(other)
        return false unless other.respond_to?(:title) and self.type == other.type and self.title == other.title

        return false unless to_hash == other.to_hash
        true
    end

    # Compatibility method.
    def builtin?
        builtin_type?
    end

    # Is this a builtin resource type?
    def builtin_type?
        resource_type.is_a?(Class)
    end

    # Iterate over each param/value pair, as required for Enumerable.
    def each
        @parameters.each { |p,v| yield p, v }
    end

    def include?(parameter)
        super || @parameters.keys.include?( parameter_name(parameter) )
    end

    # These two methods are extracted into a Helper
    # module, but file load order prevents me
    # from including them in the class, and I had weird
    # behaviour (i.e., sometimes it didn't work) when
    # I directly extended each resource with the helper.
    def environment
        Puppet::Node::Environment.new(@environment)
    end

    def environment=(env)
        if env.is_a?(String) or env.is_a?(Symbol)
            @environment = env
        else
            @environment = env.name
        end
    end

    %w{exported virtual strict}.each do |m|
        define_method(m+"?") do
            self.send(m)
        end
    end

    # Create our resource.
    def initialize(type, title = nil, attributes = {})
        @parameters = {}
        @namespaces = [""]

        # Set things like namespaces and strictness first.
        attributes.each do |attr, value|
            next if attr == :parameters
            send(attr.to_s + "=", value)
        end

        # We do namespaces first, and use tmp variables, so our title
        # canonicalization works (i.e., namespaces are set and resource
        # types can be looked up)
        tmp_type, tmp_title = extract_type_and_title(type, title)
        self.type = tmp_type
        self.title = tmp_title

        if params = attributes[:parameters]
            extract_parameters(params)
        end

        resolve_type_and_title()

        tag(self.type)
        tag(self.title) if valid_tag?(self.title)

        if strict? and ! resource_type
            raise ArgumentError, "Invalid resource type #{type}"
        end
    end

    def ref
        to_s
    end

    # Find our resource.
    def resolve
        return catalog.resource(to_s) if catalog
        return nil
    end

    def title=(value)
        @unresolved_title = value
        @title = nil
    end

    def old_title
        if type == "Class" and value == ""
            @title = :main
            return
        end

        if klass = resource_type
            p klass
            if type == "Class"
                value = munge_type_name(resource_type.name)
            end

            if klass.respond_to?(:canonicalize_ref)
                value = klass.canonicalize_ref(value)
            end
        elsif type == "Class"
            value = munge_type_name(value)
        end

        @title = value
    end

    def resource_type
        case type
        when "Class"; find_hostclass(title)
        when "Node"; find_node(title)
        else
            find_resource_type(type)
        end
    end

    # Produce a simple hash of our parameters.
    def to_hash
        result = @parameters.dup
        unless result.include?(namevar)
            result[namevar] = title
        end
        result
    end

    def to_s
        "#{type}[#{title}]"
    end

    # Convert our resource to Puppet code.
    def to_manifest
        "%s { '%s':\n%s\n}" % [self.type.to_s.downcase, self.title,
             @parameters.collect { |p, v|
                 if v.is_a? Array
                     "    #{p} => [\'#{v.join("','")}\']"
                 else
                     "    #{p} => \'#{v}\'"
                 end
             }.join(",\n")
            ]
    end

    def to_ref
        ref
    end

    # Convert our resource to a RAL resource instance.  Creates component
    # instances for resource types that don't exist.
    def to_ral
        if typeklass = Puppet::Type.type(self.type)
            return typeklass.new(self)
        else
            return Puppet::Type::Component.new(self)
        end
    end

    # Translate our object to a backward-compatible transportable object.
    def to_trans
        if builtin_type?
            result = to_transobject
        else
            result = to_transbucket
        end

        result.file = self.file
        result.line = self.line

        return result
    end

    def to_trans_ref
        [type.to_s, title.to_s]
    end

    # Create an old-style TransObject instance, for builtin resource types.
    def to_transobject
        # Now convert to a transobject
        result = Puppet::TransObject.new(title, type)
        to_hash.each do |p, v|
            if v.is_a?(Puppet::Resource)
                v = v.to_trans_ref
            elsif v.is_a?(Array)
                v = v.collect { |av|
                    if av.is_a?(Puppet::Resource)
                        av = av.to_trans_ref
                    end
                    av
                }
            end

            # If the value is an array with only one value, then
            # convert it to a single value.  This is largely so that
            # the database interaction doesn't have to worry about
            # whether it returns an array or a string.
            result[p.to_s] = if v.is_a?(Array) and v.length == 1
                              v[0]
                          else
                              v
                          end
        end

        result.tags = self.tags

        return result
    end

    def name
        # this is potential namespace conflict
        # between the notion of an "indirector name"
        # and a "resource name"
        [ type, title ].join('/')
    end

    def to_resource
        self
    end

    # We have to lazy-evaluate this.
    def title=(value)
        @title = nil
        @unresolved_title = value
    end

    # We have to lazy-evaluate this.
    def type=(value)
        @type = nil
        @unresolved_type = value || "Class"
    end

    def title
        resolve_type_and_title unless @title
        @title
    end

    def type
        resolve_type_and_title unless @type
        @type
    end

    def valid_parameter?(name)
        resource_type.valid_parameter?(name)
    end

    def validate_parameter(name)
        raise ArgumentError, "Invalid parameter #{name}" unless valid_parameter?(name)
    end

    private

    def find_node(name)
        known_resource_types.node(name)
    end

    def find_hostclass(title)
        name = title == :main ? "" : title
        known_resource_types.find_hostclass(namespaces, name)
    end

    def find_resource_type(type)
        find_builtin_resource_type(type) || find_defined_resource_type(type)
    end

    def find_builtin_resource_type(type)
        Puppet::Type.type(type.to_s.downcase.to_sym)
    end

    def find_defined_resource_type(type)
        known_resource_types.find_definition(namespaces, type.to_s.downcase)
    end

    # Produce a canonical method name.
    def parameter_name(param)
        param = param.to_s.downcase.to_sym
        if param == :name and n = namevar()
            param = namevar
        end
        param
    end

    def namespaces=(ns)
        @namespaces = Array(ns)
    end

    # The namevar for our resource type. If the type doesn't exist,
    # always use :name.
    def namevar
        if builtin_type? and t = resource_type
            t.namevar
        else
            :name
        end
    end

    # Create an old-style TransBucket instance, for non-builtin resource types.
    def to_transbucket
        bucket = Puppet::TransBucket.new([])

        bucket.type = self.type
        bucket.name = self.title

        # TransBuckets don't support parameters, which is why they're being deprecated.
        return bucket
    end

    def extract_parameters(params)
        params.each do |param, value|
            validate_parameter(param) if strict?
            self[param] = value
        end
    end

    def extract_type_and_title(argtype, argtitle)
	    if    (argtitle || argtype) =~ /^([^\[\]]+)\[(.+)\]$/m then [ $1,                 $2            ]
	    elsif argtitle                                         then [ argtype,            argtitle      ]
	    elsif argtype.is_a?(Puppet::Type)                      then [ argtype.class.name, argtype.title ]
	    else raise ArgumentError, "No title provided and #{argtype.inspect} is not a valid resource reference"
	    end
    end

    def munge_type_name(value)
        return :main if value == :main
        return "Class" if value == "" or value.nil? or value.to_s.downcase == "component"

        value.to_s.split("::").collect { |s| s.capitalize }.join("::")
    end

    # This is an annoyingly complicated method for resolving qualified
    # types as necessary, and putting them in type or title attributes.
    def resolve_type_and_title
        if @unresolved_type
            @type = resolve_type
            @unresolved_type = nil
        end
        if @unresolved_title
            @title = resolve_title
            @unresolved_title = nil
        end
    end

    def resolve_type
        type = munge_type_name(@unresolved_type)

        case type
        when "Class", "Node";
            return type
        else
            # Otherwise, some kind of builtin or defined resource type
            return munge_type_name(if r = find_resource_type(type)
                r.name
            else
                type
            end)
        end
    end

    # This method only works if resolve_type was called first
    def resolve_title
        case @type
        when "Node"; return @unresolved_title
        when "Class";
            resolve_title_for_class(@unresolved_title)
        else
            resolve_title_for_resource(@unresolved_title)
        end
    end

    def resolve_title_for_class(title)
        if title == "" or title == :main
            return :main
        end

        if klass = find_hostclass(title)
            result = klass.name

            if klass.respond_to?(:canonicalize_ref)
                result = klass.canonicalize_ref(result)
            end
        end
        return munge_type_name(result || title)
    end

    def resolve_title_for_resource(title)
        if type = find_resource_type(@type) and type.respond_to?(:canonicalize_ref)
            return type.canonicalize_ref(title)
        else
            return title
        end
    end
end
