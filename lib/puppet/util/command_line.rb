require 'puppet'
require "puppet/util/plugins"
require "puppet/util/rubygems"

module Puppet
  module Util
    class CommandLine

      def initialize(zero = $0, argv = ARGV, stdin = STDIN)
        @zero  = zero
        @argv  = argv.dup
        @stdin = stdin

        @subcommand_name, @args = subcommand_and_args(@zero, @argv, @stdin)
        Puppet::Plugins.on_commandline_initialization(:command_line_object => self)
      end

      attr :subcommand_name
      attr :args

      def appdir
        File.join('puppet', 'application')
      end

      ##
      # Search through the Puppet modulepath and find all legacy application
      # stubs that match `<modulepath>/*/lib/puppet/application/*.rb`
      #
      # @param [String] modulepath modulepaths separated by
      #   `File::PATH_SEPARATOR` often simply `Puppet.settings[:modulepath]`.
      #
      # @return [Hash] of application names available in modules from the
      #   modulepath.  The key is the application name, the value is a nested
      #   hash for the app file and the face file, both fully qualified path to
      #   the ruby file intended to be used with require or load because the
      #   module lib directories are not available on the $LOAD_PATH.
      #
      #     { 'minicat' => {
      #         'app'  => '/etc/puppet/modules/minicat/lib/puppet/application/minicat.rb',
      #         'face' => '/etc/puppet/modules/minicat/lib/puppet/face/minicat.rb', }
      #     }
      def self.module_applications(modulepath)
        ## Load applications from the modulepath
        # We would like to use Puppet::Util::Autoload.module_directories to
        # obtain a list of all module lib directories, but we cannot with the
        # current design because that method explicitly returns an empty set if
        # Puppet.settings.app_defaults_initialized? is not truthy.
        app_files = modulepath.split(File::PATH_SEPARATOR).map do |mp|
          Dir["#{mp}/*/lib/puppet/application/*.rb"]
        end.flatten

        return_hash = app_files.inject(Hash.new({})) do |memo, fn|
          appname = File.basename(fn, '.rb')
          memo[appname] = {
            'app'  => fn,
            'face' => fn.gsub(%r{/application/([^/]+)$}) { "/face/#{$1}" },
          }
          memo
        end
        return_hash
      end

      ##
      # Locate all available subcommands, legacy and faces based, along the
      # Ruby $LOAD_PATH, RubyGems $GEM_PATH, and Puppet modulepath.
      #
      # @return [Array] of unique subcommand string names.
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

        load_path_apps = absolute_appdirs.inject([]) do |commands, dir|
          commands + Dir[File.join(dir, '*.rb')].map{|fn| File.basename(fn, '.rb')}
        end.uniq

        module_path_apps = module_applications(Puppet.settings[:modulepath]).keys

        # We load applications from the $LOAD_PATH or from the
        # Puppet[:modulepath].  We're using uniq because it might be the case
        # the user has explicitly put a module on the $LOAD_PATH using RUBYLIB.
        # In this situation an application will be listed twice and it
        # shouldn't be.
        return_array = (load_path_apps + module_path_apps).sort.uniq
        return_array
      end

      # available_subcommands was previously an instance method, not a class
      # method, and we have an unknown number of user-implemented applications
      # that depend on that behaviour.  Forwarding allows us to preserve a
      # backward compatible API. --daniel 2011-04-11
      def available_subcommands
        self.class.available_subcommands
      end

      def require_application(application)
        require File.join(appdir, application)
      end

      # This is the main entry point for all puppet applications / faces; it
      # is basically where the bootstrapping process / lifecycle of an app
      # begins.
      def execute
        # Build up our settings - we don't need that until after version check.
        Puppet::Util.exit_on_fail("intialize global default settings") do
          Puppet.settings.initialize_global_settings(args)
        end

        # OK, now that we've processed the command line options and the config
        # files, we should be able to say that we definitively know where the
        # libdir is... which means that we can now look for our available
        # applications / subcommands / faces.

        if subcommand_name and available_subcommands.include?(subcommand_name) then
          # This will need to be cleaned up to do something that is not so
          #  application-specific (i.e.. so that we can load faces).
          #  Longer-term, use the autoloader.  See comments in
          #  #available_subcommands method above.  --cprice 2012-03-06
          app = Puppet::Application.find(subcommand_name).new(self)
          Puppet::Plugins.on_application_initialization(:application_object => self)

          app.run
        elsif ! execute_external_subcommand then
          unless subcommand_name.nil? then
            puts "Error: Unknown Puppet subcommand '#{subcommand_name}'"
          end

          # If the user is just checking the version, print that and exit
          if @argv.include? "--version" or @argv.include? "-V"
            puts Puppet.version
          else
            puts "See 'puppet help' for help on available puppet subcommands"
          end
        end
      end

      def execute_external_subcommand
        external_command = "puppet-#{subcommand_name}"

        require 'puppet/util'
        path_to_subcommand = Puppet::Util.which(external_command)
        return false unless path_to_subcommand

        exec(path_to_subcommand, *args)
      end

      private

      def subcommand_and_args(zero, argv, stdin)
        zero = File.basename(zero, '.rb')

        if zero == 'puppet'
          case argv.first
            # if they didn't pass a command, or passed a help flag, we will
            # fall back to showing a usage message.  we no longer default to
            # 'apply'
            when nil, "--help", "-h", /^-|\.pp$|\.rb$/
              [nil, argv]
            else
              [argv.first, argv[1..-1]]
          end
        else
          [zero, argv]
        end
      end

    end
  end
end
