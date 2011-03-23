require 'puppet/interface/indirector'
require 'puppet/ssl/host'

Puppet::Interface::Indirector.interface(:certificate) do

  action :generate do
    invoke do |name|
      host = Puppet::SSL::Host.new(name)
      host.generate_certificate_request
      host.certificate_request.class.indirection.save(host.certificate_request)
    end
  end

  action :list do
    invoke do
      Puppet::SSL::Host.indirection.search("*").each do |host|
        puts host.inspect
      end
      nil
    end
  end

  action :sign do |name|
    invoke do |name|
      Puppet::SSL::Host.indirection.save(Puppet::SSL::Host.new(name))
    end
  end

end
