# Abstract class
class Puppet::Pops::Evaluator::Collectors::AbstractCollector
  attr_reader :scope
  # The collector's hash of overrides {:parameters => params}
  attr_reader :overrides
  # The set of collected resources
  attr_reader :collected

  EMPTY_RESOURCES = [].frozen

  #:parameters => overrides[:parameters],
  #:file       => overrides[:file],
  #:line       => overrides[:line],
  #:source     => overrides[:source],
  #:scope      => overrides[:scope])
  def initialize(scope, overrides = nil)
    @collected = {}
    @scope = scope

    if !(overrides.nil? || overrides[:parameters])
      raise ArgumentError, "Exported resource try to override without parameters"
    end

    @overrides = overrides
  end

  def evaluate

    objects = collect.each do |obj|
      obj.virtual = false
    end

    return false if objects.empty?

    # we have an override for the collected resources
    if @overrides and !objects.empty?
      # force the resource to be always child of any other resource
      overrides[:source].meta_def(:child_of?) do |klass|
        true
      end

      # tell the compiler we have some override for it unless we already
      # overrided those resources
      objects.each do |res|
        unless @collected.include?(res.ref)
          newres = Puppet::Parser::Resource.new(res.type, res.title, @overrides)
          scope.compiler.add_override(newres)
        end
      end
    end

    # filter out object that this collector has previously found.
    objects.reject! { |o| @collected.include?(o.ref) }

    return false if objects.empty?

    # keep an eye on the resources we have collected
    objects.inject(@collected) { |c,o| c[o.ref]=o; c }

    # return our newly collected resources
    objects
  end

  def unresolved_resources
    EMPTY_RESOURCES
  end

  def collect
    raise NotImplementedError, "This method must be implemented by the child class"
  end
end
