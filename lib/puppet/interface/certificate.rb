require 'puppet/interface/indirector'

Puppet::Interface::Indirector.interface(:certificate) do

  action :sign do |name|
    unless indirection.terminus
      raise ArgumentError, "You must have a CA specified; use --ca-location to specify the location (remote, local, only)"
    end

    location = Puppet::SSL::Host.ca_location
    if location == :local && !Puppet::SSL::CertificateAuthority.ca?
      Puppet::Application[:certificate].class.run_mode("master")
      set_run_mode Puppet::Application[:certificate].class.run_mode
    end

    Puppet::SSL::Host.indirection.save(Puppet::SSL::Host.new(name))

  end

end
