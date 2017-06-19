class Puppet::Pops::Evaluator::Collectors::ExportedCollector < Puppet::Pops::Evaluator::Collectors::AbstractCollector

  # Creates an ExportedCollector using the AbstractCollector's
  # constructor to set the scope and overrides
  #
  # param [Puppet::CompilableResourceType] type the resource type to be collected
  # param [Array] equery an array representation of the query (exported query)
  # param [Proc] cquery a proc representation of the query (catalog query)
  def initialize(scope, type, equery, cquery, overrides = nil)
    super(scope, overrides)

    @equery = equery
    @cquery = cquery

    @type = Puppet::Resource.new(type, 'whatever').type
  end

  # Ensures that storeconfigs is present before calling AbstractCollector's
  # evaluate method
  def evaluate
    if Puppet[:storeconfigs] != true
      return false
    end

    super
  end

  # Collect exported resources as defined by an exported
  # collection. Used with PuppetDB
  def collect
    resources = []

    time = Puppet::Util.thinmark do
      t = @type
      q = @cquery

      resources = scope.compiler.resources.find_all do |resource|
        resource.type == t && resource.exported? && (q.nil? || q.call(resource))
      end

      found = Puppet::Resource.indirection.
        search(@type, :host => @scope.compiler.node.name, :filter => @equery, :scope => @scope)

      found_resources = found.map {|x| x.is_a?(Puppet::Parser::Resource) ? x : x.to_resource(@scope)}

      found_resources.each do |item|
        if existing = @scope.findresource(item.resource_type, item.title)
          unless existing.collector_id == item.collector_id
            raise Puppet::ParseError,
              _("A duplicate resource was found while collecting exported resources, with the type and title %{title}") % { title: item.ref }
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

  def to_s
    "Exported-Collector[#{@type.to_s}]"
  end
end
