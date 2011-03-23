require 'puppet/interface'

Puppet::Interface.interface(:configurer) do
  action(:synchronize) do
    invoke do |certname|
      facts = Puppet::Interface.interface(:facts).find(certname)
      catalog = Puppet::Interface.interface(:catalog).download(certname, facts)
      report = Puppet::Interface.interface(:catalog).apply(catalog)
      report
    end
  end
end
