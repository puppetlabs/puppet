require 'puppet'
require 'puppet/util/tagging'
require 'puppet/resource/reference'
require 'puppet/util/pson'

# The simplest resource class.  Eventually it will function as the
# base class for all resource-like behaviour.
class Puppet::Resource
    include Puppet::Util::Tagging
    extend Puppet::Util::Pson
    include Enumerable
    attr_accessor :file, :line, :catalog, :exported, :virtual
    attr_writer :type, :title

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
            hash[param] = value
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
        @parameters[parameter_name(param)] = value
    end

    # Return a given parameter's value.  Converts all passed names
    # to lower-case symbols.
    def [](param)
        @parameters[parameter_name(param)]
    end

    # Compatibility method.
    def builtin?
        builtin_type?
    end

    # Is this a builtin resource type?
    def builtin_type?
        @reference.builtin_type?
    end

    # Iterate over each param/value pair, as required for Enumerable.
    def each
        @parameters.each { |p,v| yield p, v }
    end

    %w{exported virtual}.each do |m|
        define_method(m+"?") do
            self.send(m)
        end
    end

    # Create our resource.
    def initialize(type, title, parameters = {})
        @reference = Puppet::Resource::Reference.new(type, title)
        @parameters = {}

        parameters.each do |param, value|
            self[param] = value
        end

        tag(@reference.type)
        tag(@reference.title) if valid_tag?(@reference.title)
    end

    # Provide a reference to our resource in the canonical form.
    def ref
        @reference.to_s
    end

    # Get our title information from the reference, since it will canonize it for us.
    def title
        @reference.title
    end

    # Get our type information from the reference, since it will canonize it for us.
    def type
        @reference.type
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
        return ref
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
        if @reference.builtin_type?
            result = to_transobject
        else
            result = to_transbucket
        end

        result.file = self.file
        result.line = self.line

        return result
    end

    # Create an old-style TransObject instance, for builtin resource types.
    def to_transobject
        # Now convert to a transobject
        result = Puppet::TransObject.new(@reference.title, @reference.type)
        to_hash.each do |p, v|
            if v.is_a?(Puppet::Resource::Reference)
                v = v.to_trans_ref
            elsif v.is_a?(Array)
                v = v.collect { |av|
                    if av.is_a?(Puppet::Resource::Reference)
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

    private

    # Produce a canonical method name.
    def parameter_name(param)
        param = param.to_s.downcase.to_sym
        if param == :name and n = namevar()
            param = namevar
        end
        param
    end

    # The namevar for our resource type. If the type doesn't exist,
    # always use :name.
    def namevar
        if t = resource_type
            t.namevar
        else
            :name
        end
    end

    # Retrieve the resource type.
    def resource_type
        Puppet::Type.type(type)
    end

    # Create an old-style TransBucket instance, for non-builtin resource types.
    def to_transbucket
        bucket = Puppet::TransBucket.new([])

        bucket.type = self.type
        bucket.name = self.title

        # TransBuckets don't support parameters, which is why they're being deprecated.
        return bucket
    end
end
