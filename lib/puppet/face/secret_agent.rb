require 'puppet/face'

Puppet::Face.define(:secret_agent, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Provides agent-like behavior, with no plugin downloading or reporting"
  description <<-EOT
    This face currently functions as a proof of concept, demonstrating how
    Faces allows the separation of application logic from Puppet's internal
    systems; compare the code for puppet agent. It will eventually replace
    puppet agent entirely, and can provide a template for users who wish to
    implement agent-like functionality with drastically different
    application logic.
  EOT

  action(:synchronize) do
    summary "Retrieve and apply a catalog from the puppet master"
    description <<-EOT
      This action mimics the behavior of the puppet agent application. It does
      not currently daemonize, but can download plugins, submit facts,
      retrieve and apply a catalog, and submit a report to the puppet master.
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
