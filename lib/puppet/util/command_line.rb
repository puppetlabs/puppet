# frozen_string_literal: true
# Bundler and rubygems maintain a set of directories from which to
# load gems. If Bundler is loaded, let it determine what can be
# loaded. If it's not loaded, then use rubygems. But do this before
# loading any puppet code, so that our gem loading system is sane.
if not defined? ::Bundler
  begin
    require 'rubygems'
  rescue LoadError # rubocop:disable Lint/SuppressedException
  end
end

require_relative '../../puppet'
require_relative '../../puppet/util'
require_relative '../../puppet/util/rubygems'
require_relative '../../puppet/util/limits'
require_relative '../../puppet/util/colors'
require_relative '../../puppet/gettext/module_translations'

module Puppet
  module Util
    # This is the main entry point for all puppet applications / faces; it
    # is basically where the bootstrapping process / lifecycle of an app
    # begins.
    class CommandLine
      include Puppet::Util::Limits

      OPTION_OR_MANIFEST_FILE = /^-|\.pp$/

      # @param zero [String] the name of the executable
      # @param argv [Array<String>] the arguments passed on the command line
      # @param stdin [IO] (unused)
      def initialize(zero = $0, argv = ARGV, stdin = STDIN)
        @command = File.basename(zero, '.rb')
        @argv = argv
      end

      # @return [String] name of the subcommand is being executed
      # @api public
      def subcommand_name
        return @command if @command != 'puppet'

        if @argv.first =~ OPTION_OR_MANIFEST_FILE
          nil
        else
          @argv.first
        end
      end

      # @return [Array<String>] the command line arguments being passed to the subcommand
      # @api public
      def args
        return @argv if @command != 'puppet'

        if subcommand_name.nil?
          @argv
        else
          @argv[1..-1]
        end
      end

      # Run the puppet subcommand. If the subcommand is determined to be an
      # external executable, this method will never return and the current
      # process will be replaced via {Kernel#exec}.
      #
      # @return [void]
      def execute
        require_config = true
        if @argv.first =~ /help|-h|--help|-V|--version/
          require_config = false
        end
        Puppet::Util.exit_on_fail(_("Could not initialize global default settings")) do
          Puppet.initialize_settings(args, require_config)
        end

        setpriority(Puppet[:priority])

        find_subcommand.run
      end

      # @api private
      def external_subcommand
        Puppet::Util.which("puppet-#{subcommand_name}")
      end

      private

      def find_subcommand
        if subcommand_name.nil?
          if args.include?("--help") || args.include?("-h")
            ApplicationSubcommand.new("help", CommandLine.new("puppet", ["help"]))
          else
            NilSubcommand.new(self)
          end
        elsif Puppet::Application.available_application_names.include?(subcommand_name)
          ApplicationSubcommand.new(subcommand_name, self)
        else
          path_to_subcommand = external_subcommand
          if path_to_subcommand
            ExternalSubcommand.new(path_to_subcommand, self)
          else
            UnknownSubcommand.new(subcommand_name, self)
          end
        end
      end

      # @api private
      class ApplicationSubcommand
        def initialize(subcommand_name, command_line)
          @subcommand_name = subcommand_name
          @command_line = command_line
        end

        def run
          # For most applications, we want to be able to load code from the modulepath,
          # such as apply, describe, resource, and faces.
          # For agent and device in agent mode, we only want to load pluginsync'ed code from libdir.
          # For master, we shouldn't ever be loading per-environment code into the master's
          # ruby process, but that requires fixing (#17210, #12173, #8750). So for now
          # we try to restrict to only code that can be autoloaded from the node's
          # environment.

          # PUP-2114 - at this point in the bootstrapping process we do not
          # have an appropriate application-wide current_environment set.
          # If we cannot find the configured environment, which may not exist,
          # we do not attempt to add plugin directories to the load path.
          unless @subcommand_name == 'master' || @subcommand_name == 'agent' || (@subcommand_name == 'device' && (['--apply', '--facts', '--resource'] - @command_line.args).empty?)
            configured_environment = Puppet.lookup(:environments).get(Puppet[:environment])
            if configured_environment
              configured_environment.each_plugin_directory do |dir|
                $LOAD_PATH << dir unless $LOAD_PATH.include?(dir)
              end

              Puppet::ModuleTranslations.load_from_modulepath(configured_environment.modules)
              Puppet::ModuleTranslations.load_from_vardir(Puppet[:vardir])

              # Puppet requires Facter, which initializes its lookup paths. Reset Facter to
              # pickup the new $LOAD_PATH.
              Puppet.runtime[:facter].reset
            end
          end

          app = Puppet::Application.find(@subcommand_name).new(@command_line)
          app.run
        end
      end

      # @api private
      class ExternalSubcommand
        def initialize(path_to_subcommand, command_line)
          @path_to_subcommand = path_to_subcommand
          @command_line = command_line
        end

        def run
          Kernel.exec(@path_to_subcommand, *@command_line.args)
        end
      end

      # @api private
      class NilSubcommand
        include Puppet::Util::Colors

        def initialize(command_line)
          @command_line = command_line
        end

        def run
          args = @command_line.args
          if args.include? "--version" or args.include? "-V"
            puts Puppet.version
          elsif @command_line.subcommand_name.nil? && args.count > 0
            # If the subcommand is truly nil and there is an arg, it's an option; print out the invalid option message
            puts colorize(:hred, _("Error: Could not parse application options: invalid option: %{opt}") % { opt: args[0] })
            exit 1
          else
            puts _("See 'puppet help' for help on available puppet subcommands")
          end
        end
      end

      # @api private
      class UnknownSubcommand < NilSubcommand
        def initialize(subcommand_name, command_line)
          @subcommand_name = subcommand_name
          super(command_line)
        end

        def run
          puts colorize(:hred, _("Error: Unknown Puppet subcommand '%{cmd}'") % { cmd: @subcommand_name })
          super
          exit 1
        end
      end
    end
  end
end
