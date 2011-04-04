require 'puppet/string/indirector'
require 'puppet/ssl/host'

Puppet::String::Indirector.define(:certificate, '0.0.1') do

  action :generate do
    when_invoked do |name, options|
      host = Puppet::SSL::Host.new(name)
      host.generate_certificate_request
      host.certificate_request.class.indirection.save(host.certificate_request)
    end
  end

  action :list do
    when_invoked do |options|
      Puppet::SSL::Host.indirection.search("*", {
        :for => :certificate_request,
      }).map { |h| h.inspect }
    end
  end

  action :sign do
    when_invoked do |name, options|
      Puppet::SSL::Host.indirection.save(Puppet::SSL::Host.new(name))
    end
  end

end
