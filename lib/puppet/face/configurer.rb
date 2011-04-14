require 'puppet/face'

Puppet::Face.define(:configurer, '0.0.1') do
  summary "Provides agent-like behavior, with no plugin downloading or reporting."

  action(:synchronize) do
    when_invoked do |certname, options|
      facts = Puppet::Face[:facts, '0.0.1'].find(certname)
      catalog = Puppet::Face[:catalog, '0.0.1'].download(certname, facts)
      report = Puppet::Face[:catalog, '0.0.1'].apply(catalog)
      report
    end
  end
end
