require 'puppet/interface'

Puppet::Interface.interface(:configurer, 1) do
  action(:synchronize) do
    invoke do |certname|
      facts = Puppet::Interface.interface(:facts, 1).find(certname)
      catalog = Puppet::Interface.interface(:catalog, 1).download(certname, facts)
      report = Puppet::Interface.interface(:catalog, 1).apply(catalog)
      report
    end
  end
end
