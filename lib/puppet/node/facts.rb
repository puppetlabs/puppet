require 'time'

require 'puppet/node'
require 'puppet/indirector'

require 'puppet/util/pson'

# Manage a given node's facts.  This either accepts facts and stores them, or
# returns facts for a given node.
class Puppet::Node::Facts
  # Set up indirection, so that nodes can be looked for in
  # the node sources.
  extend Puppet::Indirector
  extend Puppet::Util::Pson

  # We want to expire any cached nodes if the facts are saved.
  module NodeExpirer
    def save(instance, key = nil)
      Puppet::Node.indirection.expire(instance.name)
      super
    end
  end

  indirects :facts, :terminus_setting => :facts_terminus, :extend => NodeExpirer

  attr_accessor :name, :values

  def add_local_facts
    values["clientcert"] = Puppet.settings[:certname]
    values["clientversion"] = Puppet.version.to_s
    values["environment"] ||= Puppet.settings[:environment]
  end

  def initialize(name, values = {})
    @name = name
    @values = values

    add_timestamp
  end

  def downcase_if_necessary
    return unless Puppet.settings[:downcasefacts]

    Puppet.warning "DEPRECATION NOTICE: Fact downcasing is deprecated; please disable (20080122)"
    values.each do |fact, value|
      values[fact] = value.downcase if value.is_a?(String)
    end
  end

  # Convert all fact values into strings.
  def stringify
    values.each do |fact, value|
      values[fact] = value.to_s
    end
  end

  def ==(other)
    return false unless self.name == other.name
    strip_internal == other.send(:strip_internal)
  end

  def self.from_pson(data)
    result = new(data['name'], data['values'])
    result.timestamp = Time.parse(data['timestamp'])
    result.expiration = Time.parse(data['expiration'])
    result
  end

  def to_pson(*args)
    {
      'expiration' => expiration,
      'name' => name,
      'timestamp' => timestamp,
      'values' => strip_internal,
    }.to_pson(*args)
  end

  # Add internal data to the facts for storage.
  def add_timestamp
    self.timestamp = Time.now
  end

  def timestamp=(time)
    self.values[:_timestamp] = time
  end

  def timestamp
    self.values[:_timestamp]
  end

  private

  # Strip out that internal data.
  def strip_internal
    newvals = values.dup
    newvals.find_all { |name, value| name.to_s =~ /^_/ }.each { |name, value| newvals.delete(name) }
    newvals
  end
end
