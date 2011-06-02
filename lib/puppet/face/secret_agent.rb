require 'puppet/face'

Puppet::Face.define(:secret_agent, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Mimics puppet agent."
  description <<-'EOT'
    This face currently functions as a proof of concept, demonstrating
    how Faces allows the separation of application logic from Puppet's
    internal systems; compare the actual code for puppet agent. It will
    eventually replace puppet agent entirely, and can provide a template
    for users who wish to implement agent-like functionality with
    non-standard application logic.
  EOT

  action(:synchronize) do
    summary "Run secret_agent once."
    arguments "[-v | --verbose] [-d | --debug]" # Remove this once options are introspectible
    description <<-'EOT'
      This action mimics a single run of the puppet agent application.
      It does not currently daemonize, but can download plugins, submit
      facts, retrieve and apply a catalog, and submit a report to the
      puppet master.
    EOT
    returns "A Puppet::Transaction::Report object."
    examples <<-'EOT'
      Trigger a Puppet run with the configured puppet master:

      $ puppet secret_agent
    EOT
    notes <<-'EOT'
      This action requires that the puppet master's `auth.conf` file
      allow save access to the `facts` REST terminus. Puppet agent does
      not use this facility, and it is turned off by default. See
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
