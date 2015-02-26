class Puppet::Parser::Relationship
  attr_accessor :source, :target, :type

  PARAM_MAP = {:relationship => :before, :subscription => :notify}

  def arrayify(resources)
    # This if statement is needed because the 3x parser cannot load
    # Puppet::Pops. This logic can be removed for 4.0 when the 3x AST
    # is removed (when Pops is always used).
    if !(Puppet.future_parser?)
      case resources
      when Puppet::Parser::Collector
        resources.collected.values
      when Array
        resources
      else
        [resources]
      end
    else
      require 'puppet/pops'
      case resources
      when Puppet::Pops::Evaluator::Collectors::AbstractCollector
        resources.collected.values
      when Array
        resources
      else
        [resources]
      end
    end
  end

  def evaluate(catalog)
    arrayify(source).each do |s|
      arrayify(target).each do |t|
        mk_relationship(s, t, catalog)
      end
    end
  end

  def initialize(source, target, type)
    @source, @target, @type = source, target, type
  end

  def param_name
    PARAM_MAP[type] || raise(ArgumentError, "Invalid relationship type #{type}")
  end

  def mk_relationship(source, target, catalog)
    # REVISIT: In Ruby 1.8 we applied `to_s` to source and target, rather than
    # `join` without an argument.  In 1.9 the behaviour of Array#to_s changed,
    # and it gives a different representation than just concat the stringified
    # elements.
    #
    # This restores the behaviour, but doesn't address the underlying question
    # of what would happen when more than one item was passed in that array.
    # (Hint: this will not end well.)
    #
    # See http://projects.puppetlabs.com/issues/12076 for the ticket tracking
    # the fact that we should dig out the sane version of this behaviour, then
    # implement it - where we don't risk breaking a stable release series.
    # --daniel 2012-01-21
    source = source.is_a?(Array) ? source.join : source.to_s
    target = target.is_a?(Array) ? target.join : target.to_s

    unless source_resource = catalog.resource(source)
      raise ArgumentError, "Could not find resource '#{source}' for relationship on '#{target}'"
    end
    unless catalog.resource(target)
      raise ArgumentError, "Could not find resource '#{target}' for relationship from '#{source}'"
    end
    Puppet.debug "Adding relationship from #{source} to #{target} with '#{param_name}'"
    if source_resource[param_name].class != Array
      source_resource[param_name] = [source_resource[param_name]].compact
    end
    source_resource[param_name] << target
  end
end
