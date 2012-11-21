# Bundler and rubygems maintain a set of directories from which to
# load gems. If Bundler is loaded, let it determine what can be
# loaded. If it's not loaded, then use rubygems. But do this before
# loading any puppet code, so that our gem loading system is sane.
if not defined? ::Bundler
  begin
    require 'rubygems'
  rescue LoadError
  end
end

require 'puppet'
require 'puppet/util'
require "puppet/util/plugins"
require "puppet/util/rubygems"

module Puppet
  module Util
    class CommandLine
      OPTION_OR_MANIFEST_FILE = /^-|\.pp$|\.rb$/

      # @param [String] the name of the executable
      # @param [Array<String>] the arguments passed on the command line
      # @param [IO] (unused)
      def initialize(zero = $0, argv = ARGV, stdin = STDIN)
        @subcommand_name, @args = subcommand_and_args(zero, argv)
        Puppet::Plugins.on_commandline_initialization(:command_line_object => self)
      end

      attr :subcommand_name
      attr :args

      def self.available_subcommands
        # Eventually we probably want to replace this with a call to the
        # autoloader.  however, at the moment the autoloader considers the
        # module path when loading, and we don't want to allow apps / faces to
        # load from there.  Once that is resolved, this should be replaced.
        # --cprice 2012-03-06
        #
        # But we do want to load from rubygems --hightower
        search_path = Puppet::Util::RubyGems::Source.new.directories + $LOAD_PATH
        absolute_appdirs = search_path.uniq.collect do |x|
          File.join(x,'puppet','application')
        end.select{ |x| File.directory?(x) }
        absolute_appdirs.inject([]) do |commands, dir|
          commands + Dir[File.join(dir, '*.rb')].map{|fn| File.basename(fn, '.rb')}
        end.uniq
      end

      # available_subcommands was previously an instance method, not a class
      # method, and we have an unknown number of user-implemented applications
      # that depend on that behaviour.  Forwarding allows us to preserve a
      # backward compatible API. --daniel 2011-04-11
      def available_subcommands
        self.class.available_subcommands
      end

      # This is the main entry point for all puppet applications / faces; it
      # is basically where the bootstrapping process / lifecycle of an app
      # begins.
      def execute
        Puppet::Util.exit_on_fail("intialize global default settings") do
          Puppet.initialize_settings(args)
        end

        if subcommand = find_subcommand
          subcommand.run
        elsif args.include? "--version" or args.include? "-V"
          puts Puppet.version
        else
          puts "See 'puppet help' for help on available puppet subcommands"
        end
      end

      def external_subcommand
        Puppet::Util.which("puppet-#{subcommand_name}")
      end

      private

      def find_subcommand
        if subcommand_name.nil?
          nil
        elsif available_subcommands.include?(subcommand_name) then
          ApplicationSubcommand.new(subcommand_name, self)
        elsif path_to_subcommand = external_subcommand then
          ExternalSubcommand.new(path_to_subcommand, self)
        else
          UnknownSubcommand.new(subcommand_name)
        end
      end

      def subcommand_and_args(zero, argv)
        zero = File.basename(zero, '.rb')

        if zero == 'puppet'
          if argv.empty? or argv.first =~ OPTION_OR_MANIFEST_FILE
            [nil, argv]
          else
            [argv.first, argv[1..-1]]
          end
        else
          [zero, argv]
        end
      end

      class ApplicationSubcommand
        def initialize(subcommand_name, command_line)
          @subcommand_name = subcommand_name
          @command_line = command_line
        end

        def run
          app = Puppet::Application.find(@subcommand_name).new(@command_line)
          Puppet::Plugins.on_application_initialization(:application_object => @command_line)

          app.run
        end
      end

      class ExternalSubcommand
        def initialize(path_to_subcommand, command_line)
          @path_to_subcommand = path_to_subcommand
          @command_line = command_line
        end

        def run
          Kernel.exec(@path_to_subcommand, *@command_line.args)
        end
      end

      class UnknownSubcommand
        def initialize(subcommand_name)
          @subcommand_name = subcommand_name
        end

        def run
          puts "Error: Unknown Puppet subcommand '#{@subcommand_name}'"
        end
      end
    end
  end
end
