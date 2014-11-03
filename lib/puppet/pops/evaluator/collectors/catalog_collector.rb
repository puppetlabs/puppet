class Puppet::Pops::Evaluator::Collectors::CatalogCollector < Puppet::Pops::Evaluator::Collectors::AbstractCollector

  def initialize(scope, type, query, overrides = nil)
    super(scope, overrides)

    @query = query

    # Canonize the type
    #TODO: Refactor
    @type = Puppet::Resource.new(type, "whatever").type
  end

  # Collect just virtual objects, from our local compiler.
  def collect
    t = @type
    q = @query

    scope.compiler.resources.find_all do |resource|
      resource.type == t && (q ?  q.call(resource) : true)
    end
  end
end
