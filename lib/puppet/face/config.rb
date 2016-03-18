require 'puppet/face'
require 'puppet/settings/ini_file'

Puppet::Face.define(:config, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Interact with Puppet's settings."

  description "This subcommand can inspect and modify settings from Puppet's
    'puppet.conf' configuration file. For documentation about individual settings,
    see https://docs.puppetlabs.com/puppet/latest/reference/configuration.html."

  option "--section SECTION_NAME" do
    default_to { "main" }
    summary "The section of the configuration file to interact with."
    description <<-EOT
      The section of the puppet.conf configuration file to interact with.

      The three most commonly used sections are 'main', 'master', and 'agent'.
      'Main' is the default, and is used by all Puppet applications. Other
      sections can override 'main' values for specific applications --- the
      'master' section affects puppet master and puppet cert, and the 'agent'
      section affects puppet agent.

      Less commonly used is the 'user' section, which affects puppet apply. Any
      other section will be treated as the name of a legacy environment
      (a deprecated feature), and can only include the 'manifest' and
      'modulepath' settings.
    EOT
  end

  action(:print) do
    summary "Examine Puppet's current settings."
    arguments "(all | <setting> [<setting> ...]"
    description <<-'EOT'
      Prints the value of a single setting or a list of settings.

      This action is an alternate interface to the information available with
      `puppet <subcommand> --configprint`.
    EOT
    notes <<-'EOT'
      By default, this action reads the general configuration in the 'main'
      section. Use the '--section' and '--environment' flags to examine other
      configuration domains.
    EOT
    examples <<-'EOT'
      Get puppet's runfile directory:

      $ puppet config print rundir

      Get a list of important directories from the master's config:

      $ puppet config print all --section master | grep -E "(path|dir)"
    EOT

    when_invoked do |*args|
      options = args.pop

      args = Puppet.settings.to_a.collect(&:first) if args.empty? || args == ['all']

      values_from_the_selected_section =
        Puppet.settings.values(nil, options[:section].to_sym)

      loader_settings = {
        :environmentpath => values_from_the_selected_section.interpolate(:environmentpath),
        :basemodulepath => values_from_the_selected_section.interpolate(:basemodulepath),
      }

      Puppet.override(Puppet.base_context(loader_settings),
                     "New environment loaders generated from the requested section.") do
        # And now we can lookup values that include those from environments configured from
        # the requested section
        values = Puppet.settings.values(Puppet[:environment].to_sym, options[:section].to_sym)
        if args.length == 1
          puts values.interpolate(args[0].to_sym)
        else
          args.each do |setting_name|
            puts "#{setting_name} = #{values.interpolate(setting_name.to_sym)}"
          end
        end
      end
      nil
    end
  end

  action(:set) do
    summary "Set Puppet's settings."
    arguments "[setting_name] [setting_value]"
    description <<-'EOT'
      Updates values in the `puppet.conf` configuration file.
    EOT
    notes <<-'EOT'
      By default, this action manipulates the configuration in the
      'main' section. Use the '--section' flag to manipulate other
      configuration domains.
    EOT
    examples <<-'EOT'
      Set puppet's runfile directory:

      $ puppet config set rundir /var/run/puppetlabs

      Set the vardir for only the agent:

      $ puppet config set vardir /opt/puppetlabs/puppet/cache --section agent
    EOT

    when_invoked do |name, value, options|
      path = Puppet::FileSystem.pathname(Puppet.settings.which_configuration_file)
      Puppet::FileSystem.touch(path)
      Puppet::FileSystem.open(path, nil, 'r+') do |file|
        Puppet::Settings::IniFile.update(file) do |config|
          config.set(options[:section], name, value)
        end
      end
      nil
    end
  end
end
