require 'puppet/indirector/face'
require 'puppet/node/facts'

Puppet::Indirector::Face.define(:facts, '0.0.1') do
  copyright "Puppet Inc.", 2011
  license   _("Apache 2 license; see COPYING")

  summary _("Retrieve and store facts.")
  description <<-'EOT'
    This subcommand manages facts, which are collections of normalized system
    information used by Puppet. It can read facts directly from the local system
    (with the default `facter` terminus).
  EOT

  find = get_action(:find)
  find.summary _("Retrieve a node's facts.")
  find.arguments _("[<node_certname>]")
  find.returns <<-'EOT'
    A hash containing some metadata and (under the "values" key) the set
    of facts for the requested node. When used from the Ruby API: A
    Puppet::Node::Facts object.

    RENDERING ISSUES: Facts cannot currently be rendered as a string; use yaml
    or json.
  EOT
  find.notes <<-'EOT'
    When using the `facter` terminus, the host argument is ignored.
  EOT
  find.examples <<-'EOT'
    Get facts from the local system:

    $ puppet facts find
  EOT
  find.default = true

  deactivate_action(:destroy)
  deactivate_action(:search)

  action(:upload) do
    summary _("Upload local facts to the puppet master.")
    description <<-'EOT'
      Reads facts from the local system using the `facter` terminus, then
      saves the returned facts using the rest terminus.
    EOT
    returns "Nothing."
    notes <<-'EOT'
      This action requires that the puppet master's `auth.conf` file
      allow `PUT` or `save` access to the `/puppet/v3/facts` API endpoint.

      For details on configuring Puppet Server's `auth.conf`, see:

      <https://puppet.com/docs/puppetserver/latest/config_file_auth.html>

      For legacy Rack-based Puppet Masters, see:

      <https://puppet.com/docs/puppet/latest/config_file_auth.html>
    EOT
    examples <<-'EOT'
      Upload facts:

      $ puppet facts upload
    EOT

    render_as :json

    when_invoked do |options|
      # Use `agent` sections  settings for certificates, Puppet Server URL,
      # etc. instead of `user` section settings.
      Puppet.settings.preferred_run_mode = :agent
      Puppet::Node::Facts.indirection.terminus_class = :facter

      facts = Puppet::Node::Facts.indirection.find(Puppet[:node_name_value])
      unless Puppet[:node_name_fact].empty?
        Puppet[:node_name_value] = facts.values[Puppet[:node_name_fact]]
        facts.name = Puppet[:node_name_value]
      end

      Puppet::Node::Facts.indirection.terminus_class = :rest
      server = Puppet::Node::Facts::Rest.server
      Puppet.notice(_("Uploading facts for '%{node}' to: '%{server}'") % {
                    node: Puppet[:node_name_value],
                    server: server})

      Puppet::Node::Facts.indirection.save(facts)
    end
  end
end
