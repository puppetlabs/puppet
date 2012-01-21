require 'puppet/indirector/instrumentation_probe'
require 'puppet/indirector/code'
require 'puppet/util/instrumentation/indirection_probe'

class Puppet::Indirector::InstrumentationProbe::Local < Puppet::Indirector::Code
  def find(request)
  end

  def search(request)
    probes = []
    Puppet::Util::Instrumentation::Instrumentable.each_probe do |probe|
      probes << Puppet::Util::Instrumentation::IndirectionProbe.new("#{probe.klass}.#{probe.method}")
    end
    probes
  end

  def save(request)
    Puppet::Util::Instrumentation::Instrumentable.enable_probes
  end

  def destroy(request)
    Puppet::Util::Instrumentation::Instrumentable.disable_probes
  end
end
