require 'puppet/string'

Puppet::String.define(:configurer, '0.0.1') do
  action(:synchronize) do
    invoke do |certname, options|
      facts = Puppet::String[:facts, '0.0.1'].find(certname)
      catalog = Puppet::String[:catalog, '0.0.1'].download(certname, facts)
      report = Puppet::String[:catalog, '0.0.1'].apply(catalog)
      report
    end
  end
end
