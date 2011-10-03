require 'puppet/node'
require 'puppet/indirector'
require 'puppet/simple_graph'
require 'puppet/transaction'

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

  # The host name this is a catalog for.
  attr_accessor :name

  # The catalog version.  Used for testing whether a catalog
  # is up to date.
  attr_accessor :version

  # How long this catalog took to retrieve.  Used for reporting stats.
  attr_accessor :retrieval_duration

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

  def title_key_for_ref( ref )
    ref =~ /^([-\w:]+)\[(.*)\]$/m
    [$1, $2]
  end

  # Add a resource to our graph and to our resource table.
  # This is actually a relatively complicated method, because it handles multiple
  # aspects of Catalog behaviour:
  # * Add the resource to the resource table
  # * Add the resource to the resource graph
  # * Add the resource to the relationship graph
  # * Add any aliases that make sense for the resource (e.g., name != title)
  def add_resource(*resource)
    add_resource(*resource[0..-2]) if resource.length > 1
    resource = resource.pop
    raise ArgumentError, "Can only add objects that respond to :ref, not instances of #{resource.class}" unless resource.respond_to?(:ref)
    fail_on_duplicate_type_and_title(resource)
    title_key = title_key_for_ref(resource.ref)

    @transient_resources << resource if applying?
    @resource_table[title_key] = resource

    # If the name and title differ, set up an alias

    if resource.respond_to?(:name) and resource.respond_to?(:title) and resource.respond_to?(:isomorphic?) and resource.name != resource.title
      self.alias(resource, resource.uniqueness_key) if resource.isomorphic?
    end

    resource.catalog = self if resource.respond_to?(:catalog=)
    add_vertex(resource)
    @relationship_graph.add_vertex(resource) if @relationship_graph
  end

  # Create an alias for a resource.
  def alias(resource, key)
    resource.ref =~ /^(.+)\[/
    class_name = $1 || resource.class.name

    newref = [class_name, key].flatten

    if key.is_a? String
      ref_string = "#{class_name}[#{key}]"
      return if ref_string == resource.ref
    end

    # LAK:NOTE It's important that we directly compare the references,
    # because sometimes an alias is created before the resource is
    # added to the catalog, so comparing inside the below if block
    # isn't sufficient.
    if existing = @resource_table[newref]
      return if existing == resource
      resource_definition = " at #{resource.file}:#{resource.line}" if resource.file and resource.line
      existing_definition = " at #{existing.file}:#{existing.line}" if existing.file and existing.line
      msg = "Cannot alias #{resource.ref} to #{key.inspect}#{resource_definition}; resource #{newref.inspect} already defined#{existing_definition}"
      raise ArgumentError, msg
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

    Puppet::Util::Storage.load if host_config?

    transaction = Puppet::Transaction.new(self, options[:report])
    register_report = options[:report].nil?

    transaction.tags = options[:tags] if options[:tags]
    transaction.ignoreschedules = true if options[:ignoreschedules]
    transaction.for_network_device = options[:network_device]

    transaction.add_times :config_retrieval => self.retrieval_duration || 0

    begin
      Puppet::Util::Log.newdestination(transaction.report) if register_report
      begin
        transaction.evaluate
      ensure
        Puppet::Util::Log.close(transaction.report) if register_report
      end
    rescue Puppet::Error => detail
      puts detail.backtrace if Puppet[:trace]
      Puppet.err "Could not apply complete catalog: #{detail}"
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      Puppet.err "Got an uncaught exception of type #{detail.class}: #{detail}"
    ensure
      # Don't try to store state unless we're a host config
      # too recursive.
      Puppet::Util::Storage.store if host_config?
    end

    yield transaction if block_given?

    return transaction
  ensure
    @applying = false
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

    if @relationship_graph
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
      raise ArgumentError, "Unknown resource type #{type}"
    end
    return unless resource = klass.new(options)

    add_resource(resource)
    resource
  end

  # Turn our catalog graph into an old-style tree of TransObjects and TransBuckets.
  # LAK:NOTE(20081211): This is a  pre-0.25 backward compatibility method.
  # It can be removed as soon as xmlrpc is killed.
  def extract
    top = nil
    current = nil
    buckets = {}

    unless main = resource(:stage, "main")
      raise Puppet::DevError, "Could not find 'main' stage; cannot generate catalog"
    end

    if stages = vertices.find_all { |v| v.type == "Stage" and v.title != "main" } and ! stages.empty?
      Puppet.warning "Stages are not supported by 0.24.x client; stage(s) #{stages.collect { |s| s.to_s }.join(', ') } will be ignored"
    end

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
        raise "No bucket created for #{source}" unless bucket
        bucket.push child

        # It's important that we keep a reference to any TransBuckets we've created, so
        # we don't create multiple buckets for children.
        buckets[target.to_s] = child unless target.builtin?
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
    result
  end

  # Make sure all of our resources are "finished".
  def finalize
    make_default_resources

    @resource_table.values.each { |resource| resource.finish }

    write_graph(:resources)
  end

  def host_config?
    host_config
  end

  def initialize(name = nil)
    super()
    @name = name if name
    @classes = []
    @resource_table = {}
    @transient_resources = []
    @applying = false
    @relationship_graph = nil

    @host_config = true

    @aliases = {}

    if block_given?
      yield(self)
      finalize
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
    unless @relationship_graph
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
              vertex.debug "Autorequiring #{edge.source}"
              @relationship_graph.add_edge(edge)
            else
              vertex.debug "Skipping automatic relationship with #{(edge.source == vertex ? edge.target : edge.source)}"
            end
          end
        end
      end
      @relationship_graph.write_graph(:relationships) if host_config?

      # Then splice in the container information
      splice!(@relationship_graph)

      @relationship_graph.write_graph(:expanded_relationships) if host_config?
    end
    @relationship_graph
  end

  # Impose our container information on another graph by using it
  # to replace any container vertices X with a pair of verticies
  # { admissible_X and completed_X } such that that
  #
  #    0) completed_X depends on admissible_X
  #    1) contents of X each depend on admissible_X
  #    2) completed_X depends on each on the contents of X
  #    3) everything which depended on X depens on completed_X
  #    4) admissible_X depends on everything X depended on
  #    5) the containers and their edges must be removed
  #
  # Note that this requires attention to the possible case of containers
  # which contain or depend on other containers, but has the advantage
  # that the number of new edges created scales linearly with the number
  # of contained verticies regardless of how containers are related;
  # alternatives such as replacing container-edges with content-edges
  # scale as the product of the number of external dependences, which is
  # to say geometrically in the case of nested / chained containers.
  #
  Default_label = { :callback => :refresh, :event => :ALL_EVENTS }
  def splice!(other)
    stage_class      = Puppet::Type.type(:stage)
    whit_class       = Puppet::Type.type(:whit)
    component_class  = Puppet::Type.type(:component)
    containers = vertices.find_all { |v| (v.is_a?(component_class) or v.is_a?(stage_class)) and vertex?(v) }
    #
    # These two hashes comprise the aforementioned attention to the possible
    #   case of containers that contain / depend on other containers; they map
    #   containers to their sentinals but pass other verticies through.  Thus we
    #   can "do the right thing" for references to other verticies that may or
    #   may not be containers.
    #
    admissible = Hash.new { |h,k| k }
    completed  = Hash.new { |h,k| k }
    containers.each { |x|
      admissible[x] = whit_class.new(:name => "admissible_#{x.ref}", :catalog => self)
      completed[x]  = whit_class.new(:name => "completed_#{x.ref}",  :catalog => self)
    }
    #
    # Implement the six requierments listed above
    #
    containers.each { |x|
      contents = adjacent(x, :direction => :out)
      other.add_edge(admissible[x],completed[x]) if contents.empty? # (0)
      contents.each { |v|
        other.add_edge(admissible[x],admissible[v],Default_label) # (1)
        other.add_edge(completed[v], completed[x], Default_label) # (2)
      }
      # (3) & (5)
      other.adjacent(x,:direction => :in,:type => :edges).each { |e|
        other.add_edge(completed[e.source],admissible[x],e.label)
        other.remove_edge! e
      }
      # (4) & (5)
      other.adjacent(x,:direction => :out,:type => :edges).each { |e|
        other.add_edge(completed[x],admissible[e.target],e.label)
        other.remove_edge! e
      }
    }
    containers.each { |x| other.remove_vertex! x } # (5)
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
      res = Puppet::Resource.new(type, title)
    else
      # If they didn't provide a title, then we expect the first
      # argument to be of the form 'Class[name]', which our
      # Reference class canonizes for us.
      res = Puppet::Resource.new(nil, type)
    end
    title_key      = [res.type, res.title.to_s]
    uniqueness_key = [res.type, res.uniqueness_key].flatten
    @resource_table[title_key] || @resource_table[uniqueness_key]
  end

  def resource_refs
    resource_keys.collect{ |type, name| name.is_a?( String ) ? "#{type}[#{name}]" : nil}.compact
  end

  def resource_keys
    @resource_table.keys
  end

  def resources
    @resource_table.values.uniq
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
    ::File.open(Puppet[:classfile], "w") do |f|
      f.puts classes.join("\n")
    end
  rescue => detail
    Puppet.err "Could not create class file #{Puppet[:classfile]}: #{detail}"
  end

  # Store the list of resources we manage
  def write_resource_file
    ::File.open(Puppet[:resourcefile], "w") do |f|
      to_print = resources.map do |resource|
        next unless resource.managed?
        "#{resource.type}[#{resource[resource.name_var]}]"
      end.compact
      f.puts to_print.join("\n")
    end
  rescue => detail
    Puppet.err "Could not create resource file #{Puppet[:resourcefile]}: #{detail}"
  end

  # Produce the graph files if requested.
  def write_graph(name)
    # We only want to graph the main host catalog.
    return unless host_config?

    super
  end

  private

  # Verify that the given resource isn't defined elsewhere.
  def fail_on_duplicate_type_and_title(resource)
    # Short-curcuit the common case,
    return unless existing_resource = @resource_table[title_key_for_ref(resource.ref)]

    # If we've gotten this far, it's a real conflict
    msg = "Duplicate definition: #{resource.ref} is already defined"

    msg << " in file #{existing_resource.file} at line #{existing_resource.line}" if existing_resource.file and existing_resource.line

    msg << "; cannot redefine" if resource.line or resource.file

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
      if resource.class == Puppet::Resource
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
        raise Puppet::DevError, "Could not find resource #{edge.source.ref} when converting #{message} resources"
      end

      unless target = map[edge.target.ref]
        raise Puppet::DevError, "Could not find resource #{edge.target.ref} when converting #{message} resources"
      end

      result.add_edge(source, target, edge.label)
    end

    map.clear

    result.add_class(*self.classes)
    result.tag(*self.tags)

    result
  end

  def virtual_not_exported?(resource)
    resource.respond_to?(:virtual?) and resource.virtual? and (resource.respond_to?(:exported?) and not resource.exported?)
  end
end
