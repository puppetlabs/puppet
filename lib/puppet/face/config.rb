require 'puppet/face'
require 'puppet/settings/ini_file'

Puppet::Face.define(:config, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Interact with Puppet's configuration options."

  option "--section SECTION_NAME" do
    default_to { "main" }
    summary "The section of the configuration file to interact with."
  end

  action(:print) do
    summary "Examine Puppet's current configuration settings."
    arguments "(all | <setting> [<setting> ...]"
    description <<-'EOT'
      Prints the value of a single configuration option or a list of
      configuration options.

      This action is an alternate interface to the information available with
      `puppet <subcommand> --configprint`.
    EOT
    notes <<-'EOT'
      By default, this action reads the general configuration in in the 'main'
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

      args = Puppet.settings.to_a.collect(&:first) if args.empty?

      values = Puppet.settings.values(Puppet[:environment].to_sym, options[:section].to_sym)
      if args.length == 1
        puts values.interpolate(args[0].to_sym)
      else
        args.each do |setting_name|
          puts "#{setting_name} = #{values.interpolate(setting_name.to_sym)}"
        end
      end
      nil
    end
  end

  action(:set) do
    summary "Set Puppet's configuration settings."
    arguments "[setting_name] [setting_value]"
    description <<-'EOT'
      Update values in the `puppet.conf` configuration file.
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
      file = Puppet::FileSystem::File.new(Puppet.settings.which_configuration_file)
      file.touch
      file.open(nil, 'r+') do |file|
        Puppet::Settings::IniFile.update(file) do |config|
          config.set(options[:section], name, value)
        end
      end
      nil
    end
  end
end
