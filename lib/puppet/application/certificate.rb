require 'puppet/application/indirection_base'

class Puppet::Application::Certificate < Puppet::Application::IndirectionBase

  # Luke used to call this --ca but that's taken by the global boolean --ca.
  # Since these options map CA terminology to indirector terminology, it's
  # now called --ca-location.
  option "--ca-location CA_LOCATION" do |arg|
    handle_terminus({
      :local => :file,
      :remote => :rest,
      :only => :file,
      :none => nil,
    }[arg.to_sym])
  end

end
