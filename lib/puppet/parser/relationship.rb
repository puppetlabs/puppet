class Puppet::Parser::Relationship
  attr_accessor :source, :target, :type

  PARAM_MAP = {:relationship => :before, :subscription => :notify}

  def arrayify(resources, left)
    case resources
    when Puppet::Pops::Evaluator::Collectors::AbstractCollector
      # on the LHS, go as far left as possible, else whatever the collected result is
      left ? leftmost_alternative(resources) : resources.collected.values
    when Array
      resources
    else
      [resources]
    end
  end

  def evaluate(catalog)
    arrayify(source, true).each do |s|
      arrayify(target, false).each do |t|
        mk_relationship(s, t, catalog)
      end
    end
  end

  def initialize(source, target, type)
    @source, @target, @type = source, target, type
  end

  def param_name
    PARAM_MAP[type] || raise(ArgumentError, _("Invalid relationship type %{relationship_type}") % { relationship_type: type })
  end

  def mk_relationship(source, target, catalog)
    source_ref = canonical_ref(source)
    target_ref = canonical_ref(target)
    rel_param = param_name

    unless source_resource = catalog.resource(*source_ref)
      raise ArgumentError, _("Could not find resource '%{source}' for relationship on '%{target}'") % { source: source.to_s, target: target.to_s }
    end
    unless catalog.resource(*target_ref)
      raise ArgumentError, _("Could not find resource '%{target}' for relationship from '%{source}'") % { target: target.to_s, source: source.to_s }
    end
    Puppet.debug {"Adding relationship from #{source} to #{target} with '#{param_name}'"}
    if source_resource[rel_param].class != Array
      source_resource[rel_param] = [source_resource[rel_param]].compact
    end
    source_resource[rel_param] << (target_ref[1].nil? ? target_ref[0] : "#{target_ref[0]}[#{target_ref[1]}]")
  end

  private

  # Finds the leftmost alternative for a collector (if it is empty, try its empty alternative recursively until there is
  # either nothing left, or a non empty set is found.
  #
  def leftmost_alternative(x)
    if x.is_a?(Puppet::Pops::Evaluator::Collectors::AbstractCollector)
      collected = x.collected
      return collected.values unless collected.empty?
      adapter = Puppet::Pops::Adapters::EmptyAlternativeAdapter.get(x)
      adapter.nil? ? [] : leftmost_alternative(adapter.empty_alternative)
    elsif x.is_a?(Array) && x.size == 1 && x[0].is_a?(Puppet::Pops::Evaluator::Collectors::AbstractCollector)
      leftmost_alternative(x[0])
    else
      x
    end
  end

  # Turns a PResourceType or PClassType into an array [type, title] and all other references to [ref, nil]
  # This is needed since it is not possible to find resources in the catalog based on the type system types :-(
  # (note, the catalog is also used on the agent side)
  def canonical_ref(ref)
    case ref
    when Puppet::Pops::Types::PResourceType
      [ref.type_name, ref.title]
    when Puppet::Pops::Types::PClassType
      ['class', ref.class_name]
    else
      [ref.to_s, nil]
    end
  end
end
