require 'puppet/face'

Puppet::Face.define(:secret_agent, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Mimics puppet agent."
  description <<-'EOT'
    This subcommand currently functions as a proof of concept, demonstrating how
    the Faces API exposes Puppet's internal systems to application logic;
    compare the actual code for puppet agent. It will eventually replace puppet
    agent entirely, and can provide a template for users who wish to implement
    agent-like functionality with non-standard application logic.
  EOT

  action(:synchronize) do
    default
    summary "Run secret_agent once."
    description <<-'EOT'
      Mimics a single run of puppet agent. This action does not currently
      daemonize, but can download plugins, submit facts, retrieve and apply a
      catalog, and submit a report to the puppet master.
    EOT
    returns <<-'EOT'
      Verbose logging from the completed run. When used from the Ruby API:
      returns a Puppet::Transaction::Report object.
    EOT
    examples <<-'EOT'
      Trigger a Puppet run with the configured puppet master:

      $ puppet secret_agent
    EOT
    notes <<-'EOT'
      This action requires that the puppet master's `auth.conf` file allow save
      access to the `facts` REST terminus. Puppet agent does not use this
      facility, and it is turned off by default. See
      <http://docs.puppetlabs.com/guides/rest_auth_conf.html> for more details.
    EOT

    when_invoked do |options|
      Puppet::Face[:plugin, '0.0.1'].download

      Puppet::Face[:facts, '0.0.1'].upload

      Puppet::Face[:catalog, '0.0.1'].download

      report  = Puppet::Face[:catalog, '0.0.1'].apply

      Puppet::Face[:report, '0.0.1'].submit(report)

      return report
    end
  end
end
