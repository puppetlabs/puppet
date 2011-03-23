require 'puppet/interface/indirector'

Puppet::Interface::Indirector.interface(:certificate) do
  action :generate do
    invoke do |name|
      require 'puppet/ssl/host'

      host = Puppet::SSL::Host.new(name)
      host.generate
    end
  end

  action :sign do |name|
    invoke do |name|
      unless Puppet::SSL::Host.ca_location
        raise ArgumentError, "You must have a CA location specified; use --ca-location to specify the location (remote, local, only)"
      end

      location = Puppet::SSL::Host.ca_location
      if location == :local && !Puppet::SSL::CertificateAuthority.ca?
        app = Puppet::Application[:certificate]
        app.class.run_mode("master")
        app.set_run_mode Puppet::Application[:certificate].class.run_mode
      end

      Puppet::SSL::Host.indirection.save(Puppet::SSL::Host.new(name))

    end
  end
end
