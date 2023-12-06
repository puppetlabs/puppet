# frozen_string_literal: true
require_relative '../../puppet/face'
require_relative '../../puppet/settings/ini_file'

module Puppet::Face::Config
  DEFAULT_SECTION_MARKER = Object.new
  DEFAULT_SECTION = "main"
end

Puppet::Face.define(:config, '0.0.1') do
  extend Puppet::Util::Colors
  copyright "Puppet Inc.", 2011
  license   _("Apache 2 license; see COPYING")

  summary _("Interact with Puppet's settings.")

  description "This subcommand can inspect and modify settings from Puppet's
    'puppet.conf' configuration file. For documentation about individual settings,
    see https://puppet.com/docs/puppet/latest/configuration.html."

  # deprecate top-level constants
  DEFAULT_SECTION_MARKER = Puppet::Face::Config::DEFAULT_SECTION_MARKER # rubocop:disable Lint/ConstantDefinitionInBlock
  Object.deprecate_constant(:DEFAULT_SECTION_MARKER)
  DEFAULT_SECTION = Puppet::Face::Config::DEFAULT_SECTION # rubocop:disable Lint/ConstantDefinitionInBlock
  Object.deprecate_constant(:DEFAULT_SECTION)

  option "--section " + _("SECTION_NAME") do
    default_to { Puppet::Face::Config::DEFAULT_SECTION_MARKER } # Sentinel object for default detection during commands
    summary _("The section of the configuration file to interact with.")
    description <<-EOT
      The section of the puppet.conf configuration file to interact with.

      The three most commonly used sections are 'main', 'server', and 'agent'.
      'Main' is the default, and is used by all Puppet applications. Other
      sections can override 'main' values for specific applications --- the
      'server' section affects Puppet Server, and the 'agent'
      section affects puppet agent.

      Less commonly used is the 'user' section, which affects puppet apply. Any
      other section will be treated as the name of a legacy environment
      (a deprecated feature), and can only include the 'manifest' and
      'modulepath' settings.
    EOT
  end

  action(:print) do
    summary _("Examine Puppet's current settings.")
    arguments _("all | <setting> [<setting> ...]")
    description <<-'EOT'
      Prints the value of a single setting or a list of settings.

      This action is a replacement interface to the information available with
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

      Get a list of important directories from the server's config:

      $ puppet config print all --section server | grep -E "(path|dir)"
    EOT

    when_invoked do |*args|
      options = args.pop

      @default_section = false
      if options[:section] == Puppet::Face::Config::DEFAULT_SECTION_MARKER
        options[:section] = Puppet::Face::Config::DEFAULT_SECTION
        @default_section = true
      end

      if Puppet::Util::Log.sendlevel?(:info)
        warn_default_section(options[:section]) if @default_section
        report_section_and_environment(options[:section], Puppet.settings[:environment])
      end

      names = if args.empty? || args == ['all']
                :all
              else
                args
              end

      Puppet.settings.stringify_settings(options[:section], names)
    end

    when_rendering :console do |to_be_rendered|
      output = ''.dup
      if to_be_rendered.keys.length > 1
        to_be_rendered.keys.sort.each do |setting|
          output << "#{setting} = #{to_be_rendered[setting]}\n"
        end
      else
        output << "#{to_be_rendered.to_a[0].last}\n"
      end

      output
    end
  end

  def warn_default_section(section_name)
    messages = []
    messages << _("No section specified; defaulting to '%{section_name}'.") %
      { section_name: section_name }
    #TRANSLATORS '--section' is a command line option and should not be translated
    messages << _("Set the config section by using the `--section` flag.")
    #TRANSLATORS `puppet config --section user print foo` is a command line example and should not be translated
    messages << _("For example, `puppet config --section user print foo`.")
    messages << _("For more information, see https://puppet.com/docs/puppet/latest/configuration.html")

    Puppet.warning(messages.join("\n"))
  end

  def report_section_and_environment(section_name, environment_name)
      $stderr.puts colorize(:hyellow,
        _("Resolving settings from section '%{section_name}' in environment '%{environment_name}'") %
          { section_name: section_name, environment_name: environment_name })
  end

  action(:set) do
    summary _("Set Puppet's settings.")
    arguments _("[setting_name] [setting_value]")
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

      @default_section = false
      if options[:section] == Puppet::Face::Config::DEFAULT_SECTION_MARKER
        options[:section] = Puppet::Face::Config::DEFAULT_SECTION
        @default_section = true
      end

      if name == 'environment' && options[:section] == 'main'
        Puppet.warning _(<<-EOM).chomp
The environment should be set in either the `[user]`, `[agent]`, or `[server]`
section. Variables set in the `[agent]` section are used when running
`puppet agent`. Variables set in the `[user]` section are used when running
various other puppet subcommands, like `puppet apply` and `puppet module`; these
require the defined environment directory to exist locally. Set the config
section by using the `--section` flag. For example,
`puppet config --section user set environment foo`. For more information, see
https://puppet.com/docs/puppet/latest/configuration.html#environment
        EOM
      end

      if Puppet::Util::Log.sendlevel?(:info)
        report_section_and_environment(options[:section], Puppet.settings[:environment])
      end

      # only validate settings we recognize
      setting = Puppet.settings.setting(name.to_sym)
      if setting
        # set the value, which will call `on_*_and_write` hooks, if any
        Puppet.settings[setting.name] = value

        # read the value to trigger interpolation and munge validation logic
        Puppet.settings[setting.name]
      end

      path = Puppet::FileSystem.pathname(Puppet.settings.which_configuration_file)
      Puppet::FileSystem.touch(path)
      Puppet::FileSystem.open(path, nil, 'r+:UTF-8') do |file|
        Puppet::Settings::IniFile.update(file) do |config|
          if options[:section] == "master"
            # delete requested master section if it exists,
            # as server section should be used
            setting_string = config.delete("master", name)
            if setting_string

              if Puppet::Util::Log.sendlevel?(:info)
                report_section_and_environment(options[:section], Puppet.settings[:environment])
              end

              puts(_("Deleted setting from '%{section_name}': '%{setting_string}', and adding it to 'server' section") %
                       { section_name: options[:section], name: name, setting_string: setting_string.strip })
            end
            # add the setting to the to server section instead of master section
            config.set("server", name, value)
          else
            config.set(options[:section], name, value)
          end
        end
      end
      nil
    end
  end

  action(:delete) do
    summary _("Delete a Puppet setting.")
    arguments _("<setting>")
    #TRANSLATORS 'main' is a specific section name and should not be translated
    description "Deletes a setting from the specified section. (The default is the section 'main')."
    notes <<-'EOT'
      By default, this action deletes the configuration setting from the 'main'
      configuration domain. Use the '--section' flags to delete settings from other
      configuration domains.
    EOT
    examples <<-'EOT'
      Delete the setting 'setting_name' from the 'main' configuration domain:

      $ puppet config delete setting_name

      Delete the setting 'setting_name' from the 'server' configuration domain:

      $ puppet config delete setting_name --section server
    EOT

    when_invoked do |name, options|

      @default_section = false
      if options[:section] == Puppet::Face::Config::DEFAULT_SECTION_MARKER
        options[:section] = Puppet::Face::Config::DEFAULT_SECTION
        @default_section = true
      end

      path = Puppet::FileSystem.pathname(Puppet.settings.which_configuration_file)
      if Puppet::FileSystem.exist?(path)
        Puppet::FileSystem.open(path, nil, 'r+:UTF-8') do |file|
          Puppet::Settings::IniFile.update(file) do |config|

            # delete from both master section and server section
            if options[:section] == "master" || options[:section] == "server"
              master_setting_string = config.delete("master", name)
              puts(_("Deleted setting from '%{section_name}': '%{setting_string}'") %
              { section_name: 'master', name: name, setting_string: master_setting_string.strip[/[^=]+/] }) if master_setting_string

              server_setting_string = config.delete("server", name)
              puts(_("Deleted setting from '%{section_name}': '%{setting_string}'") %
              { section_name: 'server', name: name, setting_string: server_setting_string.strip[/[^=]+/] }) if server_setting_string

            else
              setting_string = config.delete(options[:section], name)
              if setting_string

                if Puppet::Util::Log.sendlevel?(:info)
                  report_section_and_environment(options[:section], Puppet.settings[:environment])
                end

                puts(_("Deleted setting from '%{section_name}': '%{setting_string}'") %
                         { section_name: options[:section], name: name, setting_string: setting_string.strip })
              else
                Puppet.warning(_("No setting found in configuration file for section '%{section_name}' setting name '%{name}'") %
                                   { section_name: options[:section], name: name })
              end
            end
          end
        end
      else
        #TRANSLATORS the 'puppet.conf' is a specific file and should not be translated
        Puppet.warning(_("The puppet.conf file does not exist %{puppet_conf}") % { puppet_conf: path })
      end
      nil
    end
  end
end
