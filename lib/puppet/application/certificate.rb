require 'puppet/application/indirection_base'

class Puppet::Application::Certificate < Puppet::Application::IndirectionBase
  def setup
    location = Puppet::SSL::Host.ca_location
    if location == :local && !Puppet::SSL::CertificateAuthority.ca?
      # I'd prefer if this could be dealt with differently; ideally, run_mode
      #  should be set as part of a class definition, and should not be
      #  modifiable beyond that. This is one of the cases where that isn't
      #  currently possible. Perhaps a separate issue, but related, is that
      #  the run_mode probably shouldn't be a normal 'setting' like the rest
      #  of the config stuff; I left some notes in settings.rb and defaults.rb
      #  discussing this. --cprice 2012-03-22
      Puppet.settings.set_value(:run_mode, :master, :application_defaults)
    end

    super
  end
end
