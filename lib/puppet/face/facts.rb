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
      This action requires that the Puppet Server's `auth.conf` file
      allow `PUT` or `save` access to the `/puppet/v3/facts` API endpoint.

      For details on configuring Puppet Server's `auth.conf`, see:

      <https://puppet.com/docs/puppetserver/latest/config_file_auth.html>
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

      client = Puppet.runtime[:http]
      session = client.create_session
      puppet = session.route_to(:puppet)

      Puppet.notice(_("Uploading facts for '%{node}' to '%{server}'") % {
                    node: Puppet[:node_name_value],
                    server: puppet.url.hostname})

      puppet.put_facts(Puppet[:node_name_value], facts: facts, environment: Puppet.lookup(:current_environment).name.to_s)
      nil
    end
  end

  action(:show) do
    summary _("Facter plugin sync")
    arguments _("[<facts>]")
    description <<-'EOT'
    Reads facts from the local system using facter gem.
    EOT
    returns "The output of facter with added puppet specific facts"
    notes <<-'EOT'

    EOT
    examples <<-'EOT'
    retrieve facts:

    $ puppet facts show os
    EOT

    option("--config-file " + _("<path>")) do
      default_to { nil }
      summary _("The location of the config file for Facter.")
    end

    option("--custom-dir " + _("<path>")) do
      default_to { nil }
      summary _("The path to a directory that contains custom facts.")
    end

    option("--external-dir " + _("<path>")) do
      default_to { nil }
      summary _("The path to a directory that contains external facts.")
    end

    option("--no-block") do
      summary _("Disable fact blocking mechanism.")
    end

    option("--no-cache") do
      summary _("Disable fact caching mechanism.")
    end

    option("--show-legacy") do
      summary _("Show legacy facts when querying all facts.")
    end

    when_invoked do |*args|
      options = args.pop

      Puppet.settings.preferred_run_mode = :agent
      Puppet::Node::Facts.indirection.terminus_class = :facter


      options[:user_query] = args
      options[:resolve_options] = true
      result = Puppet::Node::Facts.indirection.find(Puppet.settings[:certname], options)

      result.values
    end

    when_rendering :console do |result|
      Puppet::Util::Json.dump(result, :pretty => true)
    end
  end
end

