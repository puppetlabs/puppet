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

  def initialize_from_hash(data)
    @name = data['name']
    @values = data['values']
    # Timestamp will be here in YAML
    timestamp = data['values']['_timestamp']
    @values.delete_if do |key, val|
      key =~ /^_/
    end

    #Timestamp will be here in pson
    timestamp ||= data['timestamp']
    timestamp = Time.parse(timestamp) if timestamp.is_a? String
    self.timestamp = timestamp

    self.expiration = data['expiration']
    if expiration.is_a? String
      self.expiration = Time.parse(expiration)
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
    new_facts = allocate
    new_facts.initialize_from_hash(data)
    new_facts
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
