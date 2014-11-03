class Puppet::Pops::Evaluator::Collectors::FixedSetCollector < Puppet::Pops::Evaluator::Collectors::AbstractCollector

  def initialize(scope, resources)
    super(scope)
    @resources = resources.is_a?(Array)? resources.dup : [resources]
  end

  def collect
    resolved = []
    result = @resources.reduce([]) do |memo, ref|
      if res = @scope.findresource(ref.to_s)
        res.virtual = false
        memo << res
        resolved << ref
      end
      memo
    end

    @resources = @resources - resolved

    # If there are no more resources to find, delete this from the list
    # of collections.
    @scope.compiler.delete_collection(self) if @resources.empty?

    result
  end

  def unresolved_resources
    @resources
  end
end
