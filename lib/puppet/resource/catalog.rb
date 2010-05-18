require 'puppet/node'
require 'puppet/indirector'
require 'puppet/simple_graph'
require 'puppet/transaction'

require 'puppet/util/cacher'
require 'puppet/util/pson'

require 'puppet/util/tagging'

# This class models a node catalog.  It is the thing
# meant to be passed from server to client, and it contains all
# of the information in the catalog, including the resources
# and the relationships between them.
class Puppet::Resource::Catalog < Puppet::SimpleGraph
    class DuplicateResourceError < Puppet::Error; end

    extend Puppet::Indirector
    indirects :catalog, :terminus_setting => :catalog_terminus

    include Puppet::Util::Tagging
    extend Puppet::Util::Pson
    include Puppet::Util::Cacher::Expirer

    # The host name this is a catalog for.
    attr_accessor :name

    # The catalog version.  Used for testing whether a catalog
    # is up to date.
    attr_accessor :version

    # How long this catalog took to retrieve.  Used for reporting stats.
    attr_accessor :retrieval_duration

    # How we should extract the catalog for sending to the client.
    attr_reader :extraction_format

    # Whether this is a host catalog, which behaves very differently.
    # In particular, reports are sent, graphs are made, and state is
    # stored in the state database.  If this is set incorrectly, then you often
    # end up in infinite loops, because catalogs are used to make things
    # that the host catalog needs.
    attr_accessor :host_config

    # Whether this catalog was retrieved from the cache, which affects
    # whether it is written back out again.
    attr_accessor :from_cache

    # Some metadata to help us compile and generally respond to the current state.
    attr_accessor :client_version, :server_version

    # Add classes to our class list.
    def add_class(*classes)
        classes.each do |klass|
            @classes << klass
        end

        # Add the class names as tags, too.
        tag(*classes)
    end

    # Add one or more resources to our graph and to our resource table.
    # This is actually a relatively complicated method, because it handles multiple
    # aspects of Catalog behaviour:
    # * Add the resource to the resource table
    # * Add the resource to the resource graph
    # * Add the resource to the relationship graph
    # * Add any aliases that make sense for the resource (e.g., name != title)
    def add_resource(*resources)
        resources.each do |resource|
            unless resource.respond_to?(:ref)
                raise ArgumentError, "Can only add objects that respond to :ref, not instances of %s" % resource.class
            end
        end.each { |resource| fail_unless_unique(resource) }.each do |resource|
            ref = resource.ref

            @transient_resources << resource if applying?
            @resource_table[ref] = resource

            # If the name and title differ, set up an alias

            if resource.respond_to?(:name) and resource.respond_to?(:title) and resource.name != resource.title
                self.alias(resource, resource.name) if resource.isomorphic?
            end

            resource.catalog = self if resource.respond_to?(:catalog=)

            add_vertex(resource)

            if @relationship_graph
                @relationship_graph.add_vertex(resource)
            end

            yield(resource) if block_given?
        end
    end

    # Create an alias for a resource.
    def alias(resource, name)
        #set $1
        resource.ref =~ /^(.+)\[/

        newref = "%s[%s]" % [$1 || resource.class.name, name]

        # LAK:NOTE It's important that we directly compare the references,
        # because sometimes an alias is created before the resource is
        # added to the catalog, so comparing inside the below if block
        # isn't sufficient.
        return if newref == resource.ref
        if existing = @resource_table[newref]
            return if existing == resource
            raise(ArgumentError, "Cannot alias %s to %s; resource %s already exists" % [resource.ref, name, newref])
        end
        @resource_table[newref] = resource
        @aliases[resource.ref] ||= []
        @aliases[resource.ref] << newref
    end

    # Apply our catalog to the local host.  Valid options
    # are:
    #   :tags - set the tags that restrict what resources run
    #       during the transaction
    #   :ignoreschedules - tell the transaction to ignore schedules
    #       when determining the resources to run
    def apply(options = {})
        @applying = true

        # Expire all of the resource data -- this ensures that all
        # data we're operating against is entirely current.
        expire()

        Puppet::Util::Storage.load if host_config?
        transaction = Puppet::Transaction.new(self)

        transaction.tags = options[:tags] if options[:tags]
        transaction.ignoreschedules = true if options[:ignoreschedules]

        transaction.addtimes :config_retrieval => self.retrieval_duration


        begin
            transaction.evaluate
        rescue Puppet::Error => detail
            puts detail.backtrace if Puppet[:trace]
            Puppet.err "Could not apply complete catalog: %s" % detail
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            Puppet.err "Got an uncaught exception of type %s: %s" % [detail.class, detail]
        ensure
            # Don't try to store state unless we're a host config
            # too recursive.
            Puppet::Util::Storage.store if host_config?
        end

        yield transaction if block_given?

        transaction.send_report if host_config and (Puppet[:report] or Puppet[:summarize])

        return transaction
    ensure
        @applying = false
        cleanup()
    end

    # Are we in the middle of applying the catalog?
    def applying?
        @applying
    end

    def clear(remove_resources = true)
        super()
        # We have to do this so that the resources clean themselves up.
        @resource_table.values.each { |resource| resource.remove } if remove_resources
        @resource_table.clear

        if defined?(@relationship_graph) and @relationship_graph
            @relationship_graph.clear
            @relationship_graph = nil
        end
    end

    def classes
        @classes.dup
    end

    # Create a new resource and register it in the catalog.
    def create_resource(type, options)
        unless klass = Puppet::Type.type(type)
            raise ArgumentError, "Unknown resource type %s" % type
        end
        return unless resource = klass.new(options)

        add_resource(resource)
        resource
    end

    def dependent_data_expired?(ts)
        if applying?
            return super
        else
            return true
        end
    end

    # Make sure we support the requested extraction format.
    def extraction_format=(value)
        unless respond_to?("extract_to_%s" % value)
            raise ArgumentError, "Invalid extraction format %s" % value
        end
        @extraction_format = value
    end

    # Turn our catalog graph into whatever the client is expecting.
    def extract
        send("extract_to_%s" % extraction_format)
    end

    # Create the traditional TransBuckets and TransObjects from our catalog
    # graph.  LAK:NOTE(20081211): This is a  pre-0.25 backward compatibility method.
    # It can be removed as soon as xmlrpc is killed.
    def extract_to_transportable
        top = nil
        current = nil
        buckets = {}

        unless main = vertices.find { |res| res.type == "Class" and res.title == :main }
            raise Puppet::DevError, "Could not find 'main' class; cannot generate catalog"
        end

        # Create a proc for examining edges, which we'll use to build our tree
        # of TransBuckets and TransObjects.
        bucket = nil
        walk(main, :out) do |source, target|
            # The sources are always non-builtins.
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

        # Retrieve the bucket for the top-level scope and set the appropriate metadata.
        unless result = buckets[main.to_s]
            # This only happens when the catalog is entirely empty.
            result = buckets[main.to_s] = main.to_trans
        end

        result.classes = classes

        # Clear the cache to encourage the GC
        buckets.clear
        return result
    end

    # Make sure all of our resources are "finished".
    def finalize
        make_default_resources

        @resource_table.values.each { |resource| resource.finish }

        write_graph(:resources)
    end

    def host_config?
        host_config || false
    end

    def initialize(name = nil)
        super()
        @name = name if name
        @extraction_format ||= :transportable
        @classes = []
        @resource_table = {}
        @transient_resources = []
        @applying = false
        @relationship_graph = nil

        @aliases = {}

        if block_given?
            yield(self)
            finalize()
        end
    end

    # Make the default objects necessary for function.
    def make_default_resources
        # We have to add the resources to the catalog, or else they won't get cleaned up after
        # the transaction.

        # First create the default scheduling objects
        Puppet::Type.type(:schedule).mkdefaultschedules.each { |res| add_resource(res) unless resource(res.ref) }

        # And filebuckets
        if bucket = Puppet::Type.type(:filebucket).mkdefaultbucket
            add_resource(bucket) unless resource(bucket.ref)
        end
    end

    # Create a graph of all of the relationships in our catalog.
    def relationship_graph
        unless defined? @relationship_graph and @relationship_graph
            # It's important that we assign the graph immediately, because
            # the debug messages below use the relationships in the
            # relationship graph to determine the path to the resources
            # spitting out the messages.  If this is not set,
            # then we get into an infinite loop.
            @relationship_graph = Puppet::SimpleGraph.new

            # First create the dependency graph
            self.vertices.each do |vertex|
                @relationship_graph.add_vertex vertex
                vertex.builddepends.each do |edge|
                    @relationship_graph.add_edge(edge)
                end
            end

            # Lastly, add in any autorequires
            @relationship_graph.vertices.each do |vertex|
                vertex.autorequire(self).each do |edge|
                    unless @relationship_graph.edge?(edge.source, edge.target) # don't let automatic relationships conflict with manual ones.
                        unless @relationship_graph.edge?(edge.target, edge.source)
                            vertex.debug "Autorequiring %s" % [edge.source]
                            @relationship_graph.add_edge(edge)
                        else
                            vertex.debug "Skipping automatic relationship with %s" % (edge.source == vertex ? edge.target : edge.source)
                        end
                    end
                end
            end
            @relationship_graph.write_graph(:relationships) if host_config?

            # Then splice in the container information
            @relationship_graph.splice!(self, Puppet::Type::Component)

            @relationship_graph.write_graph(:expanded_relationships) if host_config?
        end
        @relationship_graph
    end

    # Remove the resource from our catalog.  Notice that we also call
    # 'remove' on the resource, at least until resource classes no longer maintain
    # references to the resource instances.
    def remove_resource(*resources)
        resources.each do |resource|
            @resource_table.delete(resource.ref)
            if aliases = @aliases[resource.ref]
                aliases.each { |res_alias| @resource_table.delete(res_alias) }
                @aliases.delete(resource.ref)
            end
            remove_vertex!(resource) if vertex?(resource)
            @relationship_graph.remove_vertex!(resource) if @relationship_graph and @relationship_graph.vertex?(resource)
            resource.remove
        end
    end

    # Look a resource up by its reference (e.g., File[/etc/passwd]).
    def resource(type, title = nil)
        # Always create a resource reference, so that it always canonizes how we
        # are referring to them.
        if title
            ref = Puppet::Resource::Reference.new(type, title).to_s
        else
            # If they didn't provide a title, then we expect the first
            # argument to be of the form 'Class[name]', which our
            # Reference class canonizes for us.
            ref = Puppet::Resource::Reference.new(nil, type).to_s
        end
        @resource_table[ref]
    end

    # Return an array of all resources.
    def resources
        @resource_table.keys
    end

    def self.from_pson(data)
        result = new(data['name'])

        if tags = data['tags'] 
            result.tag(*tags)
        end

        if version = data['version'] 
            result.version = version
        end

        if resources = data['resources']
            resources = PSON.parse(resources) if resources.is_a?(String)
            resources.each do |res|
                resource_from_pson(result, res)
            end
        end

        if edges = data['edges']
            edges = PSON.parse(edges) if edges.is_a?(String)
            edges.each do |edge|
                edge_from_pson(result, edge)
            end
        end

        if classes = data['classes']
            result.add_class(*classes)
        end

        result
    end

    def self.edge_from_pson(result, edge)
        # If no type information was presented, we manually find
        # the class.
        edge = Puppet::Relationship.from_pson(edge) if edge.is_a?(Hash)
        unless source = result.resource(edge.source)
            raise ArgumentError, "Could not convert from pson: Could not find relationship source #{edge.source.inspect}"
        end
        edge.source = source

        unless target = result.resource(edge.target)
            raise ArgumentError, "Could not convert from pson: Could not find relationship target #{edge.target.inspect}"
        end
        edge.target = target

        result.add_edge(edge)
    end

    def self.resource_from_pson(result, res)
        res = Puppet::Resource.from_pson(res) if res.is_a? Hash
        result.add_resource(res)
    end

    PSON.register_document_type('Catalog',self)
    def to_pson_data_hash
        {
            'document_type' => 'Catalog',
            'data'       => {
                'tags'      => tags,
                'name'      => name,
                'version'   => version,
                'resources' => vertices.collect { |v| v.to_pson_data_hash },
                'edges'     => edges.   collect { |e| e.to_pson_data_hash },
                'classes'   => classes
                },
            'metadata' => {
                'api_version' => 1
                }
       }
    end

    def to_pson(*args)
       to_pson_data_hash.to_pson(*args)
    end

    # Convert our catalog into a RAL catalog.
    def to_ral
        to_catalog :to_ral
    end

    # Convert our catalog into a catalog of Puppet::Resource instances.
    def to_resource
        to_catalog :to_resource
    end

    # filter out the catalog, applying +block+ to each resource. 
    # If the block result is false, the resource will
    # be kept otherwise it will be skipped
    def filter(&block)
        to_catalog :to_resource, &block
    end

    # Store the classes in the classfile.
    def write_class_file
        begin
            ::File.open(Puppet[:classfile], "w") do |f|
                f.puts classes.join("\n")
            end
        rescue => detail
            Puppet.err "Could not create class file %s: %s" % [Puppet[:classfile], detail]
        end
    end

    # Produce the graph files if requested.
    def write_graph(name)
        # We only want to graph the main host catalog.
        return unless host_config?

        super
    end

    private

    def cleanup
        # Expire any cached data the resources are keeping.
        expire()
    end

    # Verify that the given resource isn't defined elsewhere.
    def fail_unless_unique(resource)
        # Short-curcuit the common case,
        return unless existing_resource = @resource_table[resource.ref]

        # If we've gotten this far, it's a real conflict

        # Either it's a defined type, which are never
        # isomorphic, or it's a non-isomorphic type, so
        # we should throw an exception.
        msg = "Duplicate definition: %s is already defined" % resource.ref

        if existing_resource.file and existing_resource.line
            msg << " in file %s at line %s" %
                [existing_resource.file, existing_resource.line]
        end

        if resource.line or resource.file
            msg << "; cannot redefine"
        end

        raise DuplicateResourceError.new(msg)
    end

    # An abstracted method for converting one catalog into another type of catalog.
    # This pretty much just converts all of the resources from one class to another, using
    # a conversion method.
    def to_catalog(convert)
        result = self.class.new(self.name)

        result.version = self.version

        map = {}
        vertices.each do |resource|
            next if virtual_not_exported?(resource)
            next if block_given? and yield resource

            #This is hackity hack for 1094
            #Aliases aren't working in the ral catalog because the current instance of the resource
            #has a reference to the catalog being converted. . . So, give it a reference to the new one
            #problem solved. . .
            if resource.is_a?(Puppet::Resource)
                resource = resource.dup
                resource.catalog = result
            elsif resource.is_a?(Puppet::TransObject)
                resource = resource.dup
                resource.catalog = result
            elsif resource.is_a?(Puppet::Parser::Resource)
                resource = resource.to_resource
                resource.catalog = result
            end

            if resource.is_a?(Puppet::Resource) and convert.to_s == "to_resource"
                newres = resource
            else
                newres = resource.send(convert)
            end

            # We can't guarantee that resources don't munge their names
            # (like files do with trailing slashes), so we have to keep track
            # of what a resource got converted to.
            map[resource.ref] = newres

            result.add_resource newres
        end

        message = convert.to_s.gsub "_", " "
        edges.each do |edge|
            # Skip edges between virtual resources.
            next if virtual_not_exported?(edge.source)
            next if block_given? and yield edge.source

            next if virtual_not_exported?(edge.target)
            next if block_given? and yield edge.target

            unless source = map[edge.source.ref]
                raise Puppet::DevError, "Could not find resource %s when converting %s resources" % [edge.source.ref, message]
            end

            unless target = map[edge.target.ref]
                raise Puppet::DevError, "Could not find resource %s when converting %s resources" % [edge.target.ref, message]
            end

            result.add_edge(source, target, edge.label)
        end

        map.clear

        result.add_class(*self.classes)
        result.tag(*self.tags)

        return result
    end

    def virtual_not_exported?(resource)
        resource.respond_to?(:virtual?) and resource.virtual? and (resource.respond_to?(:exported?) and not resource.exported?)
    end
end
