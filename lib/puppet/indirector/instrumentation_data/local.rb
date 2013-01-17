require 'puppet/indirector/instrumentation_data'

class Puppet::Indirector::InstrumentationData::Local < Puppet::Indirector::Code

  desc "Undocumented."

  def find(request)
    model.new(request.key)
  end

  def search(request)
    raise Puppet::DevError, "You cannot search for instrumentation data"
  end

  def save(request)
    raise Puppet::DevError, "You cannot save instrumentation data"
  end

  def destroy(request)
    raise Puppet::DevError, "You cannot remove instrumentation data"
  end
end
