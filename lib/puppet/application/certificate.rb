require 'puppet/application/indirection_base'

class Puppet::Application::Certificate < Puppet::Application::IndirectionBase
  def setup
    unless options[:ca_location]
      raise ArgumentError, "You must have a CA location specified;\n" +
        "use --ca-location to specify the location (remote, local, only)"
    end

    location = Puppet::SSL::Host.ca_location
    if location == :local && !Puppet::SSL::CertificateAuthority.ca?
      self.class.run_mode("master")
      self.set_run_mode self.class.run_mode
    end

    super
  end
end
