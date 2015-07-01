class Puppet::Pops::Evaluator::Collectors::AbstractCollector
  attr_reader :scope

  # The collector's hash of overrides {:parameters => params}
  attr_reader :overrides

  # The set of collected resources
  attr_reader :collected

  # An empty array which will be returned by the unresolved_resources
  # method unless we have a FixSetCollector
  EMPTY_RESOURCES = [].freeze

  # Initialized the instance variables needed by the base
  # collector class to perform evaluation
  #
  # @param [Puppet::Parser::Scope] scope
  #
  # @param [Hash] overrides a hash of optional overrides
  # @options opts [Array] :parameters
  # @options opts [String] :file
  # @options opts [Array] :line
  # @options opts [Puppet::Resource::Type] :source
  # @options opts [Puppet::Parser::Scope] :scope
  def initialize(scope, overrides = nil)
    @collected = {}
    @scope = scope

    if !(overrides.nil? || overrides[:parameters])
      raise ArgumentError, "Exported resource try to override without parameters"
    end

    @overrides = overrides
  end

  # Collects resources and marks collected objects as non-virtual. Also
  # handles overrides.
  #
  # @return [Array] the resources we have collected
  def evaluate
    objects = collect.each do |obj|
      obj.virtual = false
    end

    return false if objects.empty?

    if @overrides and !objects.empty?
      overrides[:source].meta_def(:child_of?) do |klass|
        true
      end

      objects.each do |res|
        unless @collected.include?(res.ref)
          newres = Puppet::Parser::Resource.new(res.type, res.title, @overrides)
          scope.compiler.add_override(newres)
        end
      end
    end

    objects.reject! { |o| @collected.include?(o.ref) }

    return false if objects.empty?

    objects.reduce(@collected) { |c,o| c[o.ref]=o; c }

    objects
  end

  # This should only return an empty array unless we have
  # an FixedSetCollector, in which case it will return the
  # resources that have not yet been realized
  #
  # @return [Array] the resources that have not been resolved
  def unresolved_resources
    EMPTY_RESOURCES
  end

  # Collect the specified resources. The way this is done depends on which type
  # of collector we are dealing with. This method is implemented differently in
  # each of the three child classes
  #
  # @return [Array] the collected resources
  def collect
    raise NotImplementedError, "This method must be implemented by the child class"
  end
end
