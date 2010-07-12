class Puppet::Parser::Relationship
  attr_accessor :source, :target, :type

  PARAM_MAP = {:relationship => :before, :subscription => :notify}

  def evaluate(catalog)
    if source.is_a?(Puppet::Parser::Collector)
      sources = source.collected.values
    else
      sources = [source]
    end
    if target.is_a?(Puppet::Parser::Collector)
      targets = target.collected.values
    else
      targets = [target]
    end
    sources.each do |s|
      targets.each do |t|
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
    unless source_resource = catalog.resource(source.to_s)
      raise ArgumentError, "Could not find resource '#{source}' for relationship on '#{target}'"
    end
    unless target_resource = catalog.resource(target.to_s)
      raise ArgumentError, "Could not find resource '#{target}' for relationship from '#{source}'"
    end
    Puppet.debug "Adding relationship from #{source.to_s} to #{target.to_s} with '#{param_name}'"
    source_resource[param_name] ||= []
    source_resource[param_name] << target.to_s
  end
end
