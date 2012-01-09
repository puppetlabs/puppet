require 'puppet/indirector/instrumentation_listener'

class Puppet::Indirector::InstrumentationListener::Local < Puppet::Indirector::Code
  def find(request)
    Puppet::Util::Instrumentation[request.key]
  end

  def search(request)
    Puppet::Util::Instrumentation.listeners
  end

  def save(request)
    res = request.instance
    Puppet::Util::Instrumentation[res.name] = res
    nil # don't leak the listener
  end

  def destroy(request)
    listener = Puppet::Util::Instrumentation[request.key]
    raise "Listener #{request.key} hasn't been subscribed" unless listener
    Puppet::Util::Instrumentation.unsubscribe(listener)
  end
end
