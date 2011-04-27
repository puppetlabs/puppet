require 'puppet/face'

Puppet::Face.define(:secret_agent, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Provides agent-like behavior, with no plugin downloading or reporting."

  action(:synchronize) do
    summary "run the secret agent, which makes the catalog and system match..."

    when_invoked do |certname, options|
      Puppet::Face[:plugin, '0.0.1'].download

      facts   = Puppet::Face[:facts, '0.0.1'].find(certname)
      catalog = Puppet::Face[:catalog, '0.0.1'].download(certname, facts)
      report  = Puppet::Face[:catalog, '0.0.1'].apply(catalog)

      Puppet::Face[:report, '0.0.1'].submit(report)

      return report
    end
  end
end
