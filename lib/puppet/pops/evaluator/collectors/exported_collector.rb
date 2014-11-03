class Puppet::Pops::Evaluator::Collectors::ExportedCollector < Puppet::Pops::Evaluator::Collectors::AbstractCollector

  def initialize(scope, type, equery, cquery, overrides = nil)
    super(scope, overrides)

    @equery = equery
    @cquery = cquery

    # Canonize the type
    @type = Puppet::Resource.new(type, "whatever").type
  end

  def evaluate
    if Puppet[:storeconfigs] != true
      Puppet.warning "Not collecting exported resources without storeconfigs"
      return false
    end

    super
  end

  # Collect exported objects.
  def collect
    resources = []

    time = Puppet::Util.thinmark do
      # First get everything that is exported from the catalog
      t = @type
      q = @cquery

      scope.compiler.resources.find_all do |resource|
        resource.type == t && resource.exported? && q.call(resource)
      end

      # key is '#{type}/#{name}', and host and filter.
      found = Puppet::Resource.indirection.
        search(@type, :host => @scope.compiler.node.name, :filter => @equery, :scope => @scope)

      found_resources = found.map {|x| x.is_a?(Puppet::Parser::Resource) ? x : x.to_resource(@scope)}

      found_resources.each do |item|
        if existing = @scope.findresource(item.type, item.title)
          unless existing.collector_id == item.collector_id
            # unless this is the one we've already collected
            raise Puppet::ParseError,
              "A duplicate resource was found while collecting exported resources, with the type and title #{item.ref}"
          end
        else
          item.exported = false
          @scope.compiler.add_resource(@scope, item)
          resources << item
        end
      end
    end

    scope.debug("Collected %s %s resource%s in %.2f seconds" %
                [resources.length, @type, resources.length == 1 ? "" : "s", time])

    resources
  end

end
