require 'puppet/external/gratr/digraph'

# This class models a node configuration.  It is the thing
# meant to be passed from server to client, and it contains all
# of the information in the configuration, including the resources
# and the relationships between them.
class Puppet::Node::Configuration < Puppet::PGraph
    attr_accessor :name, :version
    attr_reader :extraction_format

    # Add classes to our class list.
    def add_class(*classes)
        classes.each do |klass|
            @classes << klass
        end

        # Add the class names as tags, too.
        tag(*classes)
    end

    # Add a resource to our graph and to our resource table.
    def add_resource(resource)
        unless resource.respond_to?(:ref)
            raise ArgumentError, "Can only add objects that respond to :ref"
        end

        ref = resource.ref
        if @resource_table.include?(ref)
            raise ArgumentError, "Resource %s is already defined" % ref
        else
            @resource_table[ref] = resource
        end
    end
    
    def clear
        super
        @resource_table.clear
    end

    def classes
        @classes.dup
    end

    # Make sure we support the requested extraction format.
    def extraction_format=(value)
        unless respond_to?("extract_to_%s" % value)
            raise ArgumentError, "Invalid extraction format %s" % value
        end
        @extraction_format = value
    end

    # Turn our configuration graph into whatever the client is expecting.
    def extract
        send("extract_to_%s" % extraction_format)
    end

    # Create the traditional TransBuckets and TransObjects from our configuration
    # graph.  This will hopefully be deprecated soon.
    def extract_to_transportable
        top = nil
        current = nil
        buckets = {}

        unless main = vertices.find { |res| res.type == "class" and res.title == :main }
            raise Puppet::DevError, "Could not find 'main' class; cannot generate configuration"
        end

        # Create a proc for examining edges, which we'll use to build our tree
        # of TransBuckets and TransObjects.
        bucket = nil
        edges = proc do |edge|
            # The sources are always non-builtins.
            source, target = edge.source, edge.target
            unless tmp = buckets[source.to_s]
                if tmp = buckets[source.to_s] = source.to_trans
                    bucket = tmp
                else
                    # This is because virtual resources return nil.  If a virtual
                    # container resource contains realized resources, we still need to get
                    # to them.  So, we keep a reference to the last valid bucket
                    # we returned and use that if the container resource is virtual.
                end
            end
            bucket = tmp || bucket
            if child = target.to_trans
                unless bucket
                    raise "No bucket created for %s" % source
                end
                bucket.push child

                # It's important that we keep a reference to any TransBuckets we've created, so
                # we don't create multiple buckets for children.
                unless target.builtin?
                    buckets[target.to_s] = child
                end
            end
        end
        dfs(:start => main, :examine_edge => edges)

        unless main
            raise Puppet::DevError, "Could not find 'main' class; cannot generate configuration"
        end

        # Retrive the bucket for the top-level scope and set the appropriate metadata.
        unless result = buckets[main.to_s]
            raise Puppet::DevError, "Did not evaluate top scope"
        end

        result.classes = classes

        # Clear the cache to encourage the GC
        buckets.clear
        return result
    end

    def initialize(name)
        super()
        @name = name
        @extraction_format ||= :transportable
        @tags = []
        @classes = []
        @resource_table = {}
    end

    # Look a resource up by its reference (e.g., File[/etc/passwd]).
    def resource(ref)
        @resource_table[ref]
    end

    # Add a tag.
    def tag(*names)
        names.each do |name|
            name = name.to_s
            @tags << name unless @tags.include?(name)
            if name.include?("::")
                name.split("::").each do |sub|
                    @tags << sub unless @tags.include?(sub)
                end
            end
        end
        nil
    end

    # Return the list of tags.
    def tags
        @tags.dup
    end
end
