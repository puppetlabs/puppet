require 'puppet/indirector/face'
require 'puppet/node/facts'
require 'puppet/util/fact_dif'

EXCLUDE_LIST = %w[ facterversion
  load_averages\..*
  processors\.speed
  swapfree swapfree_mb
  memoryfree memoryfree_mb
  memory\.swap\.available_bytes memory\.swap\.used_bytes
  memory\.swap\.available memory\.swap\.capacity memory\.swap\.used
  memory\.system\.available_bytes memory\.system\.used_bytes
  memory\.system\.available memory\.system\.capacity memory\.system\.used
  mountpoints\..*\.available.* mountpoints\..*\.capacity mountpoints\..*\.used.*
  sp_uptime system_profiler\.uptime
  uptime uptime_days uptime_hours uptime_seconds
  system_uptime\.uptime system_uptime\.days system_uptime\.hours system_uptime\.seconds
]

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

  action(:diff) do
    summary _("Compare Facter 3 output with Facter 4 output")
    description <<-'EOT'
    Compares output from facter 3 with Facter 4 and prints the differences
    EOT
    returns "Differences between Facter 3 and Facter 4 output as an array."
    notes <<-'EOT'
    EOT
    examples <<-'EOT'
    get differences between facter versions:
    $ puppet facts diff
    EOT

    render_as :json

    when_invoked do |*args|
      Puppet.settings.preferred_run_mode = :agent
      Puppet::Node::Facts.indirection.terminus_class = :facter

      if Puppet::Util::Package.versioncmp(Facter.value('facterversion'), '4.0.0') < 0
        cmd_flags = '--render-as json --show-legacy'

        # puppet/ruby are in PATH since it was updated in the wrapper script
        puppet_show_cmd  = "puppet facts show"
        if Puppet::Util::Platform.windows?
          puppet_show_cmd = "ruby -S -- #{puppet_show_cmd}"
        end

        facter_3_result = Puppet::Util::Execution.execute("#{puppet_show_cmd} --no-facterng #{cmd_flags}")
        facter_ng_result = Puppet::Util::Execution.execute("#{puppet_show_cmd} --facterng #{cmd_flags}")

        fact_diff = FactDif.new(facter_3_result, facter_ng_result, EXCLUDE_LIST)
        fact_diff.difs
      else
        Puppet.warning _("Already using Facter 4. To use `puppet facts diff` remove facterng from the .conf file or run `puppet config set facterng false`.")
        exit 0
      end
    end
  end

  action(:show) do
    summary _("Retrieve current node's facts.")
    arguments _("[<facts>]")
    description <<-'EOT'
    Reads facts from the local system using `facter` terminus.
    A query can be provided to retrieve just a specific fact or a set of facts.
    EOT
    returns "The output of facter with added puppet specific facts."
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

    option("--value-only") do
      summary _("Show only the value when the action is called with a single query")
    end

    when_invoked do |*args|
      options = args.pop

      Puppet.settings.preferred_run_mode = :agent
      Puppet::Node::Facts.indirection.terminus_class = :facter

      if options[:value_only] && !args.count.eql?(1)
        options[:value_only] = nil
        Puppet.warning("Incorrect use of --value-only argument; it can only be used when querying for a single fact!")
      end

      options[:user_query] = args
      options[:resolve_options] = true
      result = Puppet::Node::Facts.indirection.find(Puppet.settings[:certname], options)

      if options[:value_only]
        result.values.values.first
      else
        result.values
      end
    end

    when_rendering :console do |result|
      # VALID_TYPES = [Integer, Float, TrueClass, FalseClass, NilClass, Symbol, String, Array, Hash].freeze
      # from https://github.com/puppetlabs/facter/blob/4.0.49/lib/facter/custom_facts/util/normalization.rb#L8

      case result
      when Array, Hash
        Puppet::Util::Json.dump(result, :pretty => true)
      else # one of VALID_TYPES above
        result
      end
    end
  end
end

