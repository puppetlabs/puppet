require 'puppet/interface'

Puppet::Interface.new(:configurer) do
  action(:synchronize) do |certname|
    facts = Puppet::Interface::Facts.find(certname)

    catalog = Puppet::Interface::Catalog.download(certname, facts)

    report = Puppet::Interface::Catalog.apply(catalog)

    report
  end
end
