class Puppet::Pops::Evaluator::Collectors::CatalogCollector < Puppet::Pops::Evaluator::Collectors::AbstractCollector

  # Creates a CatalogCollector using the AbstractCollector's 
  # constructor to set the scope and overrides
  #
  # param [Symbol] type the resource type to be collected
  # param [Proc] query the query which defines which resources to match
  def initialize(scope, type, query, overrides = nil)
    super(scope, overrides)

    @query = query

    @type = Puppet::Resource.new(type, "whatever").type
  end

  # Collects virtual resources based off a collection in a manifest
  def collect
    t = @type
    q = @query

    scope.compiler.resources.find_all do |resource|
      resource.type == t && (q ?  q.call(resource) : true)
    end
  end

  def to_s
    "Catalog-Collector[#{@type.to_s}]"
  end
end
