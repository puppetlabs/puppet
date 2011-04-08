require 'puppet/faces/indirector'
require 'puppet/ssl/host'

Puppet::Faces::Indirector.define(:certificate, '0.0.1') do
  # REVISIT: This should use a pre-invoke hook to run the common code that
  # needs to happen before we invoke any action; that would be much nicer than
  # the "please repeat yourself" stuff found in here right now.
  #
  # option "--ca-location LOCATION" do
  #   type [:whatever, :location, :symbols]
  #   hook :before do |value|
  #     Puppet::SSL::Host.ca_location = value
  #   end
  # end
  #
  # ...but should I pass the arguments as well?
  # --daniel 2011-04-05
  option "--ca-location LOCATION"

  action :generate do
    when_invoked do |name, options|
      Puppet::SSL::Host.ca_location = options[:ca_location].to_sym
      host = Puppet::SSL::Host.new(name)
      host.generate_certificate_request
      host.certificate_request.class.indirection.save(host.certificate_request)
    end
  end

  action :list do
    when_invoked do |options|
      Puppet::SSL::Host.ca_location = options[:ca_location].to_sym
      Puppet::SSL::Host.indirection.search("*", {
        :for => :certificate_request,
      }).map { |h| h.inspect }
    end
  end

  action :sign do
    when_invoked do |name, options|
      Puppet::SSL::Host.ca_location = options[:ca_location].to_sym
      host = Puppet::SSL::Host.new(name)
      host.desired_state = 'signed'
      Puppet::SSL::Host.indirection.save(host)
    end
  end
end
