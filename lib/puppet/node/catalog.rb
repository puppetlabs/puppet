require 'puppet/indirector'
require 'puppet/pgraph'
require 'puppet/transaction'

require 'puppet/util/tagging'

# This class models a node catalog.  It is the thing
# meant to be passed from server to client, and it contains all
# of the information in the catalog, including the resources
# and the relationships between them.
class Puppet::Node::Catalog < Puppet::PGraph
    extend Puppet::Indirector
    indirects :catalog, :terminus_class => :compiler

    include Puppet::Util::Tagging

    # The host name this is a catalog for.
    attr_accessor :name

    # The catalog version.  Used for testing whether a catalog
    # is up to date.
    attr_accessor :version

    # How long this catalog took to retrieve.  Used for reporting stats.
    attr_accessor :retrieval_duration

    # How we should extract the catalog for sending to the client.
    attr_reader :extraction_format

    # We need the ability to set this externally, so we can yaml-dump the
    # catalog.
    attr_accessor :edgelist_class

    # Whether this is a host catalog, which behaves very differently.
    # In particular, reports are sent, graphs are made, and state is
    # stored in the state database.  If this is set incorrectly, then you often
    # end up in infinite loops, because catalogs are used to make things
    # that the host catalog needs.
    attr_accessor :host_config

    # Whether this graph is another catalog's relationship graph.
    # We don't want to accidentally create a relationship graph for another
    # relationship graph.
    attr_accessor :is_relationship_graph

    # Whether this catalog was retrieved from the cache, which affects
    # whether it is written back out again.
    attr_accessor :from_cache

    # Add classes to our class list.
    def add_class(*classes)
        classes.each do |klass|
            @classes << klass
        end

        # Add the class names as tags, too.
        tag(*classes)
    end

    # Add one or more resources to our graph and to our resource table.
    def add_resource(*resources)
        resources.each do |resource|
            unless resource.respond_to?(:ref)
                raise ArgumentError, "Can only add objects that respond to :ref"
            end

            fail_unless_unique(resource)

            ref = resource.ref

            @resource_table[ref] = resource

            # If the name and title differ, set up an alias
            #self.alias(resource, resource.name) if resource.respond_to?(:name) and resource.respond_to?(:title) and resource.name != resource.title
            if resource.respond_to?(:name) and resource.respond_to?(:title) and resource.name != resource.title
                self.alias(resource, resource.name) if resource.isomorphic?
            end

            resource.catalog = self if resource.respond_to?(:catalog=) and ! is_relationship_graph

            add_vertex(resource)
        end
    end

    # Create an alias for a resource.
    def alias(resource, name)
        resource.ref =~ /^(.+)\[/

        newref = "%s[%s]" % [$1 || resource.class.name, name]
        if existing = @resource_table[newref]
            return if existing == resource
            raise(ArgumentError, "Cannot alias %s to %s; resource %s already exists" % [resource.ref, name, newref])
        end
        @resource_table[newref] = resource
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

        Puppet::Util::Storage.load if host_config?
        transaction = Puppet::Transaction.new(self)

        transaction.tags = options[:tags] if options[:tags]
        transaction.ignoreschedules = true if options[:ignoreschedules]

        transaction.addtimes :config_retrieval => @retrieval_duration


        begin
            transaction.evaluate
        rescue Puppet::Error => detail
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
        transaction.cleanup if defined? transaction and transaction
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
            @relationship_graph.clear(false)
            @relationship_graph = nil
        end
    end

    def classes
        @classes.dup
    end

    # Create an implicit resource, meaning that it will lose out
    # to any explicitly defined resources.  This method often returns
    # nil.
    #  The quirk of this method is that it's not possible to create
    # an implicit resource before an explicit resource of the same name,
    # because all explicit resources are created before any generate()
    # methods are called on the individual resources.  Thus, this
    # method can safely just check if an explicit resource already exists
    # and toss this implicit resource if so.
    def create_implicit_resource(type, options)
        unless options.include?(:implicit)
            options[:implicit] = true
        end

        # This will return nil if an equivalent explicit resource already exists.
        # When resource classes no longer retain references to resource instances,
        # this will need to be modified to catch that conflict and discard
        # implicit resources.
        if resource = create_resource(type, options)
            resource.implicit = true

            return resource
        else
            return nil
        end
    end

    # Create a new resource and register it in the catalog.
    def create_resource(type, options)
        unless klass = Puppet::Type.type(type)
            raise ArgumentError, "Unknown resource type %s" % type
        end
        return unless resource = klass.create(options)

        @transient_resources << resource if applying?
        add_resource(resource)
        if @relationship_graph
            @relationship_graph.add_resource(resource) unless @relationship_graph.resource(resource.ref)
        end
        resource
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
    # graph.  This will hopefully be deprecated soon.
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

        @aliases = Hash.new { |hash, key| hash[key] = [] }

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
            add_resource(bucket)
        end
    end
    
    # Create a graph of all of the relationships in our catalog.
    def relationship_graph
        raise(Puppet::DevError, "Tried get a relationship graph for a relationship graph") if self.is_relationship_graph

        unless defined? @relationship_graph and @relationship_graph
            # It's important that we assign the graph immediately, because
            # the debug messages below use the relationships in the
            # relationship graph to determine the path to the resources
            # spitting out the messages.  If this is not set,
            # then we get into an infinite loop.
            @relationship_graph = Puppet::Node::Catalog.new
            @relationship_graph.host_config = host_config?
            @relationship_graph.is_relationship_graph = true
            
            # First create the dependency graph
            self.vertices.each do |vertex|
                @relationship_graph.add_vertex vertex
                vertex.builddepends.each do |edge|
                    @relationship_graph.add_edge(edge)
                end
            end
            
            # Lastly, add in any autorequires
            @relationship_graph.vertices.each do |vertex|
                vertex.autorequire.each do |edge|
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
            
            @relationship_graph.write_graph(:relationships)
            
            # Then splice in the container information
            @relationship_graph.splice!(self, Puppet::Type::Component)

            @relationship_graph.write_graph(:expanded_relationships)
        end
        @relationship_graph
    end

    # Remove the resource from our catalog.  Notice that we also call
    # 'remove' on the resource, at least until resource classes no longer maintain
    # references to the resource instances.
    def remove_resource(*resources)
        resources.each do |resource|
            @resource_table.delete(resource.ref)
            @aliases[resource.ref].each { |res_alias| @resource_table.delete(res_alias) }
            @aliases[resource.ref].clear
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
            ref = Puppet::ResourceReference.new(type, title).to_s
        else
            # If they didn't provide a title, then we expect the first
            # argument to be of the form 'Class[name]', which our
            # Reference class canonizes for us.
            ref = Puppet::ResourceReference.new(nil, type).to_s
        end
        if resource = @resource_table[ref]
            return resource
        elsif defined?(@relationship_graph) and @relationship_graph
            @relationship_graph.resource(ref)
        end
    end

    # Return an array of all resources.
    def resources
        @resource_table.keys
    end

    # Convert our catalog into a RAL catalog.
    def to_ral
        to_catalog :to_type
    end

    # Turn our parser catalog into a transportable catalog.
    def to_transportable
        to_catalog :to_transobject
    end

    # Produce the graph files if requested.
    def write_graph(name)
        # We only want to graph the main host catalog.
        return unless host_config?
        
        return unless Puppet[:graph]

        Puppet.settings.use(:graphing)

        file = File.join(Puppet[:graphdir], "%s.dot" % name.to_s)
        File.open(file, "w") { |f|
            f.puts to_dot("name" => name.to_s.capitalize)
        }
    end

    # LAK:NOTE We cannot yaml-dump the class in the edgelist_class, because classes cannot be
    # dumped by default, nor does yaml-dumping # the edge-labels work at this point (I don't
    # know why).
    #  Neither of these matters right now, but I suppose it could at some point.
    # We also have to have the vertex_dict dumped after the resource table, because yaml can't
    # seem to handle the output of yaml-dumping the vertex_dict.
    def to_yaml_properties
        props = instance_variables.reject { |v| %w{@edgelist_class @edge_labels @vertex_dict}.include?(v) }
        props << "@vertex_dict"
        props
    end

    private

    def cleanup
        unless @transient_resources.empty?
            remove_resource(*@transient_resources)
            @transient_resources.clear
            @relationship_graph = nil
        end
    end

    # Verify that the given resource isn't defined elsewhere.
    def fail_unless_unique(resource)
        # Short-curcuit the common case, 
        return unless existing_resource = @resource_table[resource.ref]

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

        raise ArgumentError.new(msg)
    end

    # An abstracted method for converting one catalog into another type of catalog.
    # This pretty much just converts all of the resources from one class to another, using
    # a conversion method.
    def to_catalog(convert)
        result = self.class.new(self.name)

        map = {}
        vertices.each do |resource|
            next if resource.respond_to?(:virtual?) and resource.virtual?

            newres = resource.send(convert)

            # We can't guarantee that resources don't munge their names
            # (like files do with trailing slashes), so we have to keep track
            # of what a resource got converted to.
            map[resource.ref] = newres

            result.add_resource newres
        end

        message = convert.to_s.gsub "_", " "
        edges.each do |edge|
            # Skip edges between virtual resources.
            next if edge.source.respond_to?(:virtual?) and edge.source.virtual?
            next if edge.target.respond_to?(:virtual?) and edge.target.virtual?

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
end
