require 'puppet/node'
require 'puppet/indirector'
require 'puppet/transaction'
require 'puppet/util/tagging'
require 'puppet/graph'
require 'securerandom'

require 'puppet/resource/capability_finder'

# This class models a node catalog.  It is the thing meant to be passed
# from server to client, and it contains all of the information in the
# catalog, including the resources and the relationships between them.
#
# @api public

class Puppet::Resource::Catalog < Puppet::Graph::SimpleGraph
  class DuplicateResourceError < Puppet::Error
    include Puppet::ExternalFileError
  end

  extend Puppet::Indirector
  indirects :catalog, :terminus_setting => :catalog_terminus

  include Puppet::Util::Tagging

  # The host name this is a catalog for.
  attr_accessor :name

  # The catalog version.  Used for testing whether a catalog
  # is up to date.
  attr_accessor :version

  # The id of the code input to the compiler.
  attr_accessor :code_id

  # The UUID of the catalog
  attr_accessor :catalog_uuid

  # @return [Integer] catalog format version number. This value is constant
  #  for a given version of Puppet; it is incremented when a new release of
  #  Puppet changes the API for the various objects that make up the catalog.
  attr_accessor :catalog_format

  # Inlined file metadata for non-recursive find
  # A hash of title => metadata
  attr_accessor :metadata

  # Inlined file metadata for recursive search
  # A hash of title => { source => [metadata, ...] }
  attr_accessor :recursive_metadata

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

  # A String representing the environment for this catalog
  attr_accessor :environment

  # The actual environment instance that was used during compilation
  attr_accessor :environment_instance

  # Add classes to our class list.
  def add_class(*classes)
    classes.each do |klass|
      @classes << klass
    end

    # Add the class names as tags, too.
    tag(*classes)
  end

  def title_key_for_ref( ref )
    s = ref.index('[')
    e = ref.rindex(']')
    if s && e && e > s
      a = [ref[0, s], ref[s+1, e-s-1]]
    else
      a = [nil, nil]
    end
    return a
  end

  def add_resource_before(other, *resources)
    resources.each do |resource|
      other_title_key = title_key_for_ref(other.ref)
      idx = @resources.index(other_title_key)
      raise ArgumentError, "Cannot add resource #{resource.ref} before #{other.ref} because #{other.ref} is not yet in the catalog" if idx.nil?
      add_one_resource(resource, idx)
    end
  end

  # Add `resources` to the catalog after `other`. WARNING: adding
  # multiple resources will produce the reverse ordering, e.g. calling
  # `add_resource_after(A, [B,C])` will result in `[A,C,B]`.
  def add_resource_after(other, *resources)
    resources.each do |resource|
      other_title_key = title_key_for_ref(other.ref)
      idx = @resources.index(other_title_key)
      raise ArgumentError, "Cannot add resource #{resource.ref} after #{other.ref} because #{other.ref} is not yet in the catalog" if idx.nil?
      add_one_resource(resource, idx+1)
    end
  end

  def add_resource(*resources)
    resources.each do |resource|
      add_one_resource(resource)
    end
  end

  # @param resource [A Resource] a resource in the catalog
  # @return [A Resource, nil] the resource that contains the given resource
  # @api public
  def container_of(resource)
    adjacent(resource, :direction => :in)[0]
  end

  def add_one_resource(resource, idx=-1)
    title_key = title_key_for_ref(resource.ref)
    if @resource_table[title_key]
      fail_on_duplicate_type_and_title(resource, title_key)
    end

    add_resource_to_table(resource, title_key, idx)
    create_resource_aliases(resource)

    resource.catalog = self if resource.respond_to?(:catalog=)
    add_resource_to_graph(resource)
  end
  private :add_one_resource

  def add_resource_to_table(resource, title_key, idx)
    @resource_table[title_key] = resource
    @resources.insert(idx, title_key)
  end
  private :add_resource_to_table

  def add_resource_to_graph(resource)
    add_vertex(resource)
    @relationship_graph.add_vertex(resource) if @relationship_graph
  end
  private :add_resource_to_graph

  def create_resource_aliases(resource)
    # Skip creating aliases and checking collisions for non-isomorphic resources.
    return unless resource.respond_to?(:isomorphic?) and resource.isomorphic?

    # Add an alias if the uniqueness key is valid and not the title, which has already been checked.
    ukey = resource.uniqueness_key
    if ukey.any? and ukey != [resource.title]
      self.alias(resource, ukey)
    end
  end
  private :create_resource_aliases

  # Create an alias for a resource.
  def alias(resource, key)
    ref = resource.ref
    ref =~ /^(.+)\[/
    class_name = $1 || resource.class.name

    newref = [class_name, key].flatten

    if key.is_a? String
      ref_string = "#{class_name}[#{key}]"
      return if ref_string == ref
    end

    # LAK:NOTE It's important that we directly compare the references,
    # because sometimes an alias is created before the resource is
    # added to the catalog, so comparing inside the below if block
    # isn't sufficient.
    if existing = @resource_table[newref]
      return if existing == resource
      resource_declaration = " at #{resource.file}:#{resource.line}" if resource.file and resource.line
      existing_declaration = " at #{existing.file}:#{existing.line}" if existing.file and existing.line
      msg = "Cannot alias #{ref} to #{key.inspect}#{resource_declaration}; resource #{newref.inspect} already declared#{existing_declaration}"
      raise ArgumentError, msg
    end
    @resource_table[newref] = resource
    @aliases[ref] ||= []
    @aliases[ref] << newref
  end

  # Apply our catalog to the local host.
  # @param options [Hash{Symbol => Object}] a hash of options
  # @option options [Puppet::Transaction::Report] :report
  #   The report object to log this transaction to. This is optional,
  #   and the resulting transaction will create a report if not
  #   supplied.
  # @option options [Array[String]] :tags
  #   Tags used to filter the transaction. If supplied then only
  #   resources tagged with any of these tags will be evaluated.
  # @option options [Boolean] :ignoreschedules
  #   Ignore schedules when evaluating resources
  # @option options [Boolean] :for_network_device
  #   Whether this catalog is for a network device
  #
  # @return [Puppet::Transaction] the transaction created for this
  #   application
  #
  # @api public
  def apply(options = {})
    Puppet::Util::Storage.load if host_config?

    transaction = create_transaction(options)

    begin
      transaction.report.as_logging_destination do
        transaction.evaluate
      end
    ensure
      # Don't try to store state unless we're a host config
      # too recursive.
      Puppet::Util::Storage.store if host_config?
    end

    yield transaction if block_given?

    transaction
  end

  # The relationship_graph form of the catalog. This contains all of the
  # dependency edges that are used for determining order.
  #
  # @param given_prioritizer [Puppet::Graph::Prioritizer] The prioritization
  #   strategy to use when constructing the relationship graph. Defaults the
  #   being determined by the `ordering` setting.
  # @return [Puppet::Graph::RelationshipGraph]
  # @api public
  def relationship_graph(given_prioritizer = nil)
    if @relationship_graph.nil?
      @relationship_graph = Puppet::Graph::RelationshipGraph.new(given_prioritizer || prioritizer)
      @relationship_graph.populate_from(self)
    end
    @relationship_graph
  end

  def clear(remove_resources = true)
    super()
    # We have to do this so that the resources clean themselves up.
    @resource_table.values.each { |resource| resource.remove } if remove_resources
    @resource_table.clear
    @resources = []

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

  # Make sure all of our resources are "finished".
  def finalize
    make_default_resources

    @resource_table.values.each { |resource| resource.finish }

    write_graph(:resources)
  end

  def host_config?
    host_config
  end

  def initialize(name = nil, environment = Puppet::Node::Environment::NONE, code_id = nil)
    super()
    @name = name
    @catalog_uuid = SecureRandom.uuid
    @catalog_format = 1
    @metadata = {}
    @recursive_metadata = {}
    @classes = []
    @resource_table = {}
    @resources = []
    @relationship_graph = nil

    @host_config = true
    @environment_instance = environment
    @environment = environment.to_s
    @code_id = code_id

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

  # Remove the resource from our catalog.  Notice that we also call
  # 'remove' on the resource, at least until resource classes no longer maintain
  # references to the resource instances.
  def remove_resource(*resources)
    resources.each do |resource|
      ref = resource.ref
      title_key = title_key_for_ref(ref)
      @resource_table.delete(title_key)
      if aliases = @aliases[ref]
        aliases.each { |res_alias| @resource_table.delete(res_alias) }
        @aliases.delete(ref)
      end
      remove_vertex!(resource) if vertex?(resource)
      @relationship_graph.remove_vertex!(resource) if @relationship_graph and @relationship_graph.vertex?(resource)
      @resources.delete(title_key)
      # Only Puppet::Type kind of resources respond to :remove, not Puppet::Resource
      resource.remove if resource.respond_to?(:remove)
    end
  end

  # Look a resource up by its reference (e.g., File[/etc/passwd]).
  def resource(type, title = nil)
    type, title = Puppet::Resource.type_and_title(type, title)
    title_key   = [type, title.to_s]
    result = @resource_table[title_key]
    if result.nil?
      # an instance has to be created in order to construct the unique key used when
      # searching for aliases.
      unless @aliases.empty? && !Puppet[:app_management]
        res = Puppet::Resource.new(type, title, { :environment => @environment_instance })
        result = @resource_table[[type, res.uniqueness_key].flatten]
      end

      if result.nil? && Puppet[:app_management]
        resource_type = res.resource_type
        if resource_type && resource_type.is_capability?
          # @todo lutter 2015-03-10: this assumes that it is legal to just
          # mention a capability resource in code and have it automatically
          # made available, even if the current component does not require it
          result = Puppet::Resource::CapabilityFinder.find(environment, code_id, res)
          add_resource(result) if result
        end
      end
    end
    result
  end

  def resource_refs
    resource_keys.collect{ |type, name| name.is_a?( String ) ? "#{type}[#{name}]" : nil}.compact
  end

  def resource_keys
    @resource_table.keys
  end

  def resources
    @resources.collect do |key|
      @resource_table[key]
    end
  end

  def self.from_data_hash(data)
    result = new(data['name'], Puppet::Node::Environment::NONE)

    if tags = data['tags']
      result.tag(*tags)
    end

    if version = data['version']
      result.version = version
    end

    if code_id = data['code_id']
      result.code_id = code_id
    end

    if catalog_uuid = data['catalog_uuid']
      result.catalog_uuid = catalog_uuid
    end

    result.catalog_format = data['catalog_format'] || 0

    if environment = data['environment']
      result.environment = environment
      result.environment_instance = Puppet::Node::Environment.remote(environment.to_sym)
    end

    if resources = data['resources']
      result.add_resource(*resources.collect do |res|
        Puppet::Resource.from_data_hash(res)
      end)
    end

    if edges = data['edges']
      edges.each do |edge_hash|
        edge = Puppet::Relationship.from_data_hash(edge_hash)
        unless source = result.resource(edge.source)
          raise ArgumentError, "Could not intern from data: Could not find relationship source #{edge.source.inspect} for #{edge.target.to_s}"
        end
        edge.source = source

        unless target = result.resource(edge.target)
          raise ArgumentError, "Could not intern from data: Could not find relationship target #{edge.target.inspect} for #{edge.source.to_s}"
        end
        edge.target = target

        result.add_edge(edge)
      end
    end

    if classes = data['classes']
      result.add_class(*classes)
    end

    if metadata = data['metadata']
      result.metadata = metadata.inject({}) { |h, (k, v)| h[k] = Puppet::FileServing::Metadata.from_data_hash(v); h }
    end

    if recursive_metadata = data['recursive_metadata']
      result.recursive_metadata = recursive_metadata.inject({}) do |h, (title, source_to_meta_hash)|
        h[title] = source_to_meta_hash.inject({}) do |inner_h, (source, metas)|
          inner_h[source] = metas.map {|meta| Puppet::FileServing::Metadata.from_data_hash(meta)}
          inner_h
        end
        h
      end
    end

    result
  end

  def to_data_hash
    metadata_hash = metadata.inject({}) { |h, (k, v)| h[k] = v.to_data_hash; h }
    recursive_metadata_hash = recursive_metadata.inject({}) do |h, (title, source_to_meta_hash)|
      h[title] = source_to_meta_hash.inject({}) do |inner_h, (source, metas)|
        inner_h[source] = metas.map {|meta| meta.to_data_hash}
        inner_h
      end
      h
    end

    {
      'tags'      => tags,
      'name'      => name,
      'version'   => version,
      'code_id'   => code_id,
      'catalog_uuid' => catalog_uuid,
      'catalog_format' => catalog_format,
      'environment'  => environment.to_s,
      'resources' => @resources.collect { |v| @resource_table[v].to_data_hash },
      'edges'     => edges.   collect { |e| e.to_data_hash },
      'classes'   => classes,
    }.merge(metadata_hash.empty? ? {} : {'metadata' => metadata_hash})
     .merge(recursive_metadata_hash.empty? ? {} : {'recursive_metadata' => recursive_metadata_hash})
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
    # to_catalog must take place in a context where current_environment is set to the same env as the
    # environment set in the catalog (if it is set)
    # See PUP-3755
    if environment_instance
      Puppet.override({:current_environment => environment_instance}) do
        to_catalog :to_resource, &block
      end
    else
      # If catalog has no environment_instance, hope that the caller has made sure the context has the
      # correct current_environment
      to_catalog :to_resource, &block
    end
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
        if resource.name_var
          "#{resource.type}[#{resource[resource.name_var]}]"
        else
          "#{resource.ref.downcase}"
        end
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

  def prioritizer
    @prioritizer ||= case Puppet[:ordering]
                     when "title-hash"
                       Puppet::Graph::TitleHashPrioritizer.new
                     when "manifest"
                       Puppet::Graph::SequentialPrioritizer.new
                     when "random"
                       Puppet::Graph::RandomPrioritizer.new
                     else
                       raise Puppet::DevError, "Unknown ordering type #{Puppet[:ordering]}"
                     end
  end

  def create_transaction(options)
    transaction = Puppet::Transaction.new(self, options[:report], prioritizer)
    transaction.tags = options[:tags] if options[:tags]
    transaction.ignoreschedules = true if options[:ignoreschedules]
    transaction.for_network_device = options[:network_device]

    transaction
  end

  # Verify that the given resource isn't declared elsewhere.
  def fail_on_duplicate_type_and_title(resource, title_key)
    # Short-circuit the common case,
    return unless existing_resource = @resource_table[title_key]

    # If we've gotten this far, it's a real conflict
    msg = "Duplicate declaration: #{resource.ref} is already declared"

    msg << " in file #{existing_resource.file}:#{existing_resource.line}" if existing_resource.file and existing_resource.line

    msg << "; cannot redeclare"

    raise DuplicateResourceError.new(msg, resource.file, resource.line)
  end

  # An abstracted method for converting one catalog into another type of catalog.
  # This pretty much just converts all of the resources from one class to another, using
  # a conversion method.
  def to_catalog(convert)
    result = self.class.new(self.name, self.environment_instance)

    result.version = self.version
    result.code_id = self.code_id
    result.catalog_uuid = self.catalog_uuid
    result.catalog_format = self.catalog_format
    result.metadata = self.metadata
    result.recursive_metadata = self.recursive_metadata

    map = {}
    resources.each do |resource|
      next if virtual_not_exported?(resource)
      next if block_given? and yield resource

      newres = resource.copy_as_resource
      newres.catalog = result

      if convert != :to_resource
        newres = newres.to_ral
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
    resource.virtual && !resource.exported
  end
end
