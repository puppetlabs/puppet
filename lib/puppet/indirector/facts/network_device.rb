require 'puppet/node/facts'
require 'puppet/indirector/code'

class Puppet::Node::Facts::NetworkDevice < Puppet::Indirector::Code
  desc "Retrieve facts from a network device."

  def allow_remote_requests?
    false
  end

  # Look a device's facts up through the current device.
  def find(request)
    result = Puppet::Node::Facts.new(request.key, Puppet::Util::NetworkDevice.current.facts)

    result.add_local_facts
    result.sanitize
    result
  end

  def destroy(facts)
    raise Puppet::DevError, _("You cannot destroy facts in the code store; it is only used for getting facts from a remote device")
  end

  def save(facts)
    raise Puppet::DevError, _("You cannot save facts to the code store; it is only used for getting facts from a remote device")
  end
end
