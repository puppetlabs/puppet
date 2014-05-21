require 'puppet/face'
require 'puppet/settings/ini_file'

Puppet::Face.define(:config, '0.0.2') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Interact with Puppet's settings."

  description "This subcommand can inspect and modify settings from Puppet's
    'puppet.conf' configuration file. For documentation about individual settings,
    see http://docs.puppetlabs.com/references/latest/configuration.html."

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
          return values.interpolate(args[0].to_sym)
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

      $ puppet config set rundir /var/run/puppet

      Set the vardir for only the agent:

      $ puppet config set vardir /var/lib/puppetagent --section agent
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

  action(:add) do
    summary "Add an item to a Puppet settings as a comma separated list."
    arguments "[setting_name] [setting_value]"
    description <<-'EOT'
      Add an item to a Puppet settings as a comma separated list.
    EOT
    notes <<-'EOT'
      By default, this action manipulates the configuration in the
      'main' section. Use the '--section' flag to manipulate other
      configuration domains.
    EOT
    examples <<-'EOT'
      Add the store report handler:

      $ puppet config add reports store --section master
    EOT

    when_invoked do |name, value, options|
      current = Puppet::Face[:config, '0.0.2'].print(name, options)
      unless current.split(',').include? value
        Puppet::Face[:config, '0.0.2'].set(name, "#{current},#{value}", options)
      end
    end
  end

  action(:del) do
    summary "Remove a Puppet setting."
    arguments "[setting_name] [setting_value]"
    description <<-'EOT'
      If two arguments are given, this will remove an item from a comma separated list Puppet setting.
      If one argument is given, this will remove the setting from the config file completely.
    EOT
    notes <<-'EOT'
      By default, this action manipulates the configuration in the
      'main' section. Use the '--section' flag to manipulate other
      configuration domains.
    EOT
    examples <<-'EOT'
      Remove the store report processors from the list of enabled report processors:

      $ puppet config del reports store --section master

      Remove the reporturl setting from the configuration file:

      $ puppet config del reporturl --section master
    EOT

    when_invoked do |*args|
      options = args.pop
      raise ArgumentError, 'requires one or two arguments' unless args.size < 3
      name, value = args

      if value
        current = Puppet::Face[:config, '0.0.2'].print(name, options).split(',')
        if current.include? value
          current.delete(value)
          Puppet::Face[:config, '0.0.2'].set(name, "#{current.join(',')}", options)
        end
      else
        path = Puppet::FileSystem.pathname(Puppet.settings.which_configuration_file)
        return nil unless File.file? path

        Puppet::FileSystem.open(path, nil, 'r+') do |file|
          Puppet::Settings::IniFile.update(file) do |config|
            config.del(options[:section], name)
          end
        end
      end
      nil
    end
  end

end
