require 'puppet/application/indirection_base'
require 'puppet/ssl/oids'

class Puppet::Application::Certificate < Puppet::Application::IndirectionBase
  def setup
    Puppet::SSL::Oids.register_puppet_oids
    location = Puppet::SSL::Host.ca_location
    if location == :local && !Puppet::SSL::CertificateAuthority.ca?
      # I'd prefer if this could be dealt with differently; ideally, run_mode should be set as
      #  part of a class definition, and should not be modifiable beyond that.  This is one of
      #  the cases where that isn't currently possible.
      Puppet.settings.preferred_run_mode = "master"
    end

    super
  end
end
