class Puppet::Transaction::AdditionalResourceGenerator
  def initialize(catalog, relationship_graph)
    @catalog = catalog
    @relationship_graph = relationship_graph
  end

  def generate_additional_resources(resource)
    return unless resource.respond_to?(:generate)
    begin
      made = resource.generate
    rescue => detail
      resource.log_exception(detail, "Failed to generate additional resources using 'generate': #{detail}")
    end
    return unless made
    made = [made] unless made.is_a?(Array)
    priority = @relationship_graph.resource_priority(resource)
    made.uniq.collect do |res|
      @catalog.resource(res.ref) || res
    end.each do |res|
      add_resource(res, resource, priority)
      add_conditional_directed_dependency(resource, res)
      generate_additional_resources(res)
    end
  end

  def eval_generate(resource)
    return false unless resource.respond_to?(:eval_generate)
    raise Puppet::DevError,"Depthfirst resources are not supported by eval_generate" if resource.depthfirst?
    begin
      made = resource.eval_generate.uniq
      return false if made.empty?
      made = Hash[made.map(&:name).zip(made)]
    rescue => detail
      resource.log_exception(detail, "Failed to generate additional resources using 'eval_generate: #{detail}")
      return false
    end
    made = replace_duplicates_with_catalog_resources(made)
    add_resources(made.values, resource)

    contain_generated_resources_in(resource, made)
    connect_resources_to_ancestors(resource, made)

    true
  end

  private

  def replace_duplicates_with_catalog_resources(made)
    Hash[made.collect do |name, generated_resource|
      [name, @catalog.resource(generated_resource.ref) || generated_resource]
    end]
  end

  def contain_generated_resources_in(resource, made)
    sentinel = Puppet::Type.type(:whit).new(:name => "completed_#{resource.title}", :catalog => resource.catalog)
    @relationship_graph.add_vertex(sentinel, @relationship_graph.resource_priority(resource))

    redirect_edges_to_sentinel(resource, sentinel, made)

    made.values.each do |res|
      # This resource isn't 'completed' until each child has run
      add_conditional_directed_dependency(res, sentinel, Puppet::RelationshipGraph::Default_label)
    end

    # This edge allows the resource's events to propagate, though it isn't
    # strictly necessary for ordering purposes
    add_conditional_directed_dependency(resource, sentinel, Puppet::RelationshipGraph::Default_label)
  end

  def redirect_edges_to_sentinel(resource, sentinel, made)
    @relationship_graph.adjacent(resource, :direction => :out, :type => :edges).each do |e|
      next if made[e.target.name]

      @relationship_graph.add_relationship(sentinel, e.target, e.label)
      @relationship_graph.remove_edge! e
    end
  end

  def connect_resources_to_ancestors(resource, made)
    made.values.each do |res|
      # Depend on the nearest ancestor we generated, falling back to the
      # resource if we have none
      parent_name = res.ancestors.find { |a| made[a] and made[a] != res }
      parent = made[parent_name] || resource

      add_conditional_directed_dependency(parent, res)
    end
  end

  def add_resources(generated, resource)
    priority = @relationship_graph.resource_priority(resource)
    generated.each do |res|
      add_resource(res, resource, priority)
    end
  end

  def add_resource(res, parent_resource, priority)
    if @catalog.resource(res.ref).nil?
      res.tag(*parent_resource.tags)
      @catalog.add_resource(res)
      @relationship_graph.add_vertex(res, priority)
      res.finish
    end
  end

  # Copy an important relationships from the parent to the newly-generated
  # child resource.
  def add_conditional_directed_dependency(parent, child, label=nil)
    @relationship_graph.add_vertex(child)
    edge = parent.depthfirst? ? [child, parent] : [parent, child]
    if @relationship_graph.edge?(*edge.reverse)
      parent.debug "Skipping automatic relationship to #{child}"
    else
      @relationship_graph.add_relationship(edge[0],edge[1],label)
    end
  end
end
