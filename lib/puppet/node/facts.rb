require 'time'

require 'puppet/node'
require 'puppet/indirector'
require 'puppet/util/psych_support'


# Manage a given node's facts.  This either accepts facts and stores them, or
# returns facts for a given node.
class Puppet::Node::Facts
  include Puppet::Util::PsychSupport

  # Set up indirection, so that nodes can be looked for in
  # the node sources.
  extend Puppet::Indirector

  # We want to expire any cached nodes if the facts are saved.
  module NodeExpirer
    def save(instance, key = nil, options={})
      Puppet::Node.indirection.expire(instance.name, options)
      super
    end
  end

  indirects :facts, :terminus_setting => :facts_terminus, :extend => NodeExpirer

  attr_accessor :name, :values, :timestamp

  def add_local_facts
    values["clientcert"] = Puppet.settings[:certname]
    values["clientversion"] = Puppet.version.to_s
    values["clientnoop"] = Puppet.settings[:noop]
  end

  def initialize(name, values = {})
    @name = name
    @values = values

    add_timestamp
  end

  def initialize_from_hash(data)
    @name = data['name']
    @values = data['values']
    # Timestamp will be here in YAML, e.g. when reading old reports
    timestamp = @values.delete('_timestamp')
    # Timestamp will be here in JSON
    timestamp ||= data['timestamp']

    if timestamp.is_a? String
      @timestamp = Time.parse(timestamp)
    else
      @timestamp = timestamp
    end

    self.expiration = data['expiration']
    if expiration.is_a? String
      self.expiration = Time.parse(expiration)
    end
  end

  # Sanitize fact values by converting everything not a string, boolean
  # numeric, array or hash into strings.
  def sanitize
    values.each do |fact, value|
      values[fact] = sanitize_fact value
    end
  end

  def ==(other)
    return false unless self.name == other.name
    values == other.values
  end

  def self.from_data_hash(data)
    new_facts = allocate
    new_facts.initialize_from_hash(data)
    new_facts
  end

  def to_data_hash
    result = {
      'name' => name,
      'values' => values
    }

    if @timestamp
      if @timestamp.is_a? Time
        result['timestamp'] = @timestamp.iso8601(9)
      else
        result['timestamp'] = @timestamp
      end
    end

    if expiration
      if expiration.is_a? Time
        result['expiration'] = expiration.iso8601(9)
      else
        result['expiration'] = expiration
      end
    end

    result
  end

  def add_timestamp
    @timestamp = Time.now
  end

  # @deprecated Use {#values} instead of this method.
  def strip_internal
    values
  end

  private

  def sanitize_fact(fact)
    if fact.is_a? Hash then
      ret = {}
      fact.each_pair { |k,v| ret[sanitize_fact k]=sanitize_fact v }
      ret
    elsif fact.is_a? Array then
      fact.collect { |i| sanitize_fact i }
    elsif fact.is_a? Numeric \
      or fact.is_a? TrueClass \
      or fact.is_a? FalseClass \
      or fact.is_a? String
      fact
    else
      fact.to_s
    end
  end
end
