require 'puppet/interface'

Puppet::Interface.define(:configurer, '0.0.1') do
  action(:synchronize) do
    invoke do |certname|
      facts = Puppet::Interface[:facts, '0.0.1'].find(certname)
      catalog = Puppet::Interface[:catalog, '0.0.1'].download(certname, facts)
      report = Puppet::Interface[:catalog, '0.0.1'].apply(catalog)
      report
    end
  end
end
