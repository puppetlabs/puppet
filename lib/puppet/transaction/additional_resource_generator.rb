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
    made.uniq.each do |res|
      begin
        res.tag(*resource.tags)
        @catalog.add_resource(res)
        res.finish
        add_conditional_directed_dependency(resource, res)
        generate_additional_resources(res)
      rescue Puppet::Resource::Catalog::DuplicateResourceError
        res.info "Duplicate generated resource; skipping"
      end
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
    made.values.each do |res|
      begin
        res.tag(*resource.tags)
        @catalog.add_resource(res)
        res.finish
      rescue Puppet::Resource::Catalog::DuplicateResourceError
        res.info "Duplicate generated resource; skipping"
      end
    end
    sentinel = Puppet::Type.type(:whit).new(:name => "completed_#{resource.title}", :catalog => resource.catalog)

    # The completed whit is now the thing that represents the resource is done
    @relationship_graph.adjacent(resource,:direction => :out,:type => :edges).each { |e|
      # But children run as part of the resource, not after it
      next if made[e.target.name]

      add_conditional_directed_dependency(sentinel, e.target, e.label)
      @relationship_graph.remove_edge! e
    }

    default_label = Puppet::RelationshipGraph::Default_label
    made.values.each do |res|
      # Depend on the nearest ancestor we generated, falling back to the
      # resource if we have none
      parent_name = res.ancestors.find { |a| made[a] and made[a] != res }
      parent = made[parent_name] || resource

      add_conditional_directed_dependency(parent, res)

      # This resource isn't 'completed' until each child has run
      add_conditional_directed_dependency(res, sentinel, default_label)
    end

    # This edge allows the resource's events to propagate, though it isn't
    # strictly necessary for ordering purposes
    add_conditional_directed_dependency(resource, sentinel, default_label)
    true
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
