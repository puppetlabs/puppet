require 'puppet/face/indirector'
require 'puppet/ssl/host'

Puppet::Face::Indirector.define(:certificate, '0.0.1') do
  option "--ca-location LOCATION" do
    before_action do |action, args, options|
      Puppet::SSL::Host.ca_location = options[:ca_location].to_sym
    end
  end

  action :generate do
    summary "Generate a new Certificate Signing Request for HOST"

    when_invoked do |name, options|
      host = Puppet::SSL::Host.new(name)
      host.generate_certificate_request
      host.certificate_request.class.indirection.save(host.certificate_request)
    end
  end

  action :list do
    summary "List all Certificate Signing Requests"

    when_invoked do |options|
      Puppet::SSL::Host.indirection.search("*", {
        :for => :certificate_request,
      }).map { |h| h.inspect }
    end
  end

  action :sign do
    summary "Sign a Certificate Signing Request for HOST"

    when_invoked do |name, options|
      host = Puppet::SSL::Host.new(name)
      host.desired_state = 'signed'
      Puppet::SSL::Host.indirection.save(host)
    end
  end
end
