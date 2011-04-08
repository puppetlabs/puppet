require 'puppet/faces'

Puppet::Faces.define(:configurer, '0.0.1') do
  action(:synchronize) do
    when_invoked do |certname, options|
      facts = Puppet::Faces[:facts, '0.0.1'].find(certname)
      catalog = Puppet::Faces[:catalog, '0.0.1'].download(certname, facts)
      report = Puppet::Faces[:catalog, '0.0.1'].apply(catalog)
      report
    end
  end
end
