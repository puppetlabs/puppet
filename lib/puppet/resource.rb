require 'puppet'
require 'puppet/util/tagging'
require 'puppet/resource_reference'

# The simplest resource class.  Eventually it will function as the
# base class for all resource-like behaviour.
class Puppet::Resource
    include Puppet::Util::Tagging
    include Enumerable
    attr_accessor :type, :title, :file, :line, :catalog

    # Proxy these methods to the parameters hash.  It's likely they'll
    # be overridden at some point, but this works for now.
    %w{has_key? length delete empty? <<}.each do |method|
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

    # Iterate over each param/value pair, as required for Enumerable.
    def each
        @parameters.each { |p,v| yield p, v }
    end

    # Create our resource.
    def initialize(type, title, parameters = {})
        @reference = Puppet::ResourceReference.new(type, title)
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
        @parameters.dup
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
            return typeklass.create(self)
        else
            return Puppet::Type::Component.create(self)
        end
    end

    private

    # Produce a canonical method name.
    def parameter_name(param)
        param.to_s.downcase.to_sym
    end
end
