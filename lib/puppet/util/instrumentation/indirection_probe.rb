require 'puppet/indirector'
require 'puppet/util/instrumentation'

# We need to use a class other than Probe for the indirector because
# the Indirection class might declare some probes, and this would be a huge unbreakable
# dependency cycle.
class Puppet::Util::Instrumentation::IndirectionProbe
  extend Puppet::Indirector

  indirects :instrumentation_probe, :terminus_class => :local

  attr_reader :probe_name

  def initialize(probe_name)
    @probe_name = probe_name
  end

  def to_data_hash
    { :name => probe_name }
  end

  def to_pson_data_hash
    {
      :document_type => "Puppet::Util::Instrumentation::IndirectionProbe",
      :data => to_data_hash,
    }
  end

  def to_pson(*args)
    to_pson_data_hash.to_pson(*args)
  end

  def self.from_data_hash(data)
    self.new(data["name"])
  end

  def self.from_pson(data)
    Puppet.deprecation_warning("from_pson is being removed in favour of from_data_hash.")
    self.from_data_hash(data)
  end
end
