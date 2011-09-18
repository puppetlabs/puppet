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

  def to_pson(*args)
    result = {
      :document_type => "Puppet::Util::Instrumentation::IndirectionProbe",
      :data => { :name => probe_name }
    }
    result.to_pson(*args)
  end

  def self.from_pson(data)
    self.new(data["name"])
  end
end