require 'puppet/application/indirection_base'

class Puppet::Application::Certificate < Puppet::Application::IndirectionBase

  # Luke used to call this --ca but that's taken by the global boolean --ca.
  # Since these options map CA terminology to indirector terminology, it's
  # now called --ca-location.
  option "--ca-location CA_LOCATION" do |arg|
    Puppet::SSL::Host.ca_location = arg.to_sym
  end

  def setup

    unless Puppet::SSL::Host.ca_location
      raise ArgumentError, "You must have a CA location specified; use --ca-location to specify the location (remote, local, only)"
    end

    location = Puppet::SSL::Host.ca_location
    if location == :local && !Puppet::SSL::CertificateAuthority.ca?
      self.class.run_mode("master")
      self.set_run_mode self.class.run_mode
    end

    super
  end

end
