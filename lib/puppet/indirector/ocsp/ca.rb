require 'puppet/indirector/ocsp'
require 'puppet/indirector/code'
require 'puppet/ssl/ocsp/responder'

class Puppet::Indirector::Ocsp::Ca < Puppet::Indirector::Code
  desc "OCSP request revocation verification through the local CA."

  # Save our file to disk.
  def save(request)
    Puppet::SSL::Ocsp::Responder.respond(request.instance)
  end
end
