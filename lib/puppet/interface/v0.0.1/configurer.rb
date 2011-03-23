require 'puppet/interface'

Puppet::Interface.interface(:configurer, '0.0.1') do
  action(:synchronize) do
    invoke do |certname|
      facts = Puppet::Interface.interface(:facts, '0.0.1').find(certname)
      catalog = Puppet::Interface.interface(:catalog, '0.0.1').download(certname, facts)
      report = Puppet::Interface.interface(:catalog, '0.0.1').apply(catalog)
      report
    end
  end
end
