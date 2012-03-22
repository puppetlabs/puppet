require 'puppet'
require "puppet/util/plugins"
require 'puppet/util/command_line/puppet_option_parser'

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

      # This method is called during application bootstrapping.  It is responsible for parsing all of the
      # command line options and initializing the values in Puppet.settings accordingly.
      #
      # It will ignore options that are not defined in the global puppet settings list, because they may
      # be valid options for the specific application that we are about to launch... however, at this point
      # in the bootstrapping lifecycle, we don't yet know what that application is.
      def parse_global_options
        # Create an option parser
        option_parser = PuppetOptionParser.new
        option_parser.ignore_invalid_options = true

        # Add all global options to it.
        Puppet.settings.optparse_addargs([]).each do |option|
          option_parser.on(*option) do |arg|
            handlearg(option[0], arg)

          end
        end

        option_parser.parse(args)

      end
      private :parse_global_options


      # Private utility method; this is the callback that the OptionParser will use when it finds
      # an option that was defined in Puppet.settings.  All that this method does is a little bit
      # of clanup to get the option into the exact format that Puppet.settings expects it to be in,
      # and then passes it along to Puppet.settings.
      #
      # @param [String] opt the command-line option that was matched
      # @param [String, TrueClass, FalseClass] the value for the setting (as determined by the OptionParser)
      def handlearg(opt, val)
        opt, val = self.class.clean_opt(opt, val)
        Puppet.settings.handlearg(opt, val)
      end
      private :handlearg

      # A utility method (public, is used by application.rb and perhaps elsewhere) that munges a command-line
      # option string into the format that Puppet.settings expects.  (This mostly has to deal with handling the
      # "no-" prefix on flag/boolean options).
      #
      # @param [String] opt the command line option that we are munging
      # @param [String, TrueClass, FalseClass] the value for the setting (as determined by the OptionParser)
      def self.clean_opt(opt, val)
        # rewrite --[no-]option to --no-option if that's what was given
        if opt =~ /\[no-\]/ and !val
          opt = opt.gsub(/\[no-\]/,'no-')
        end
        # otherwise remove the [no-] prefix to not confuse everybody
        opt = opt.gsub(/\[no-\]/, '')
        [opt, val]
      end



      def self.available_subcommands
        # Eventually we probably want to replace this with a call to the autoloader.  however, at the moment
        #  the autoloader considers the module path when loading, and we don't want to allow apps / faces to load
        #  from there.  Once that is resolved, this should be replaced.  --cprice 2012-03-06
        absolute_appdirs = $LOAD_PATH.collect do |x|
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

      def require_application(application)
        require File.join(appdir, application)
      end

      # This is the main entry point for all puppet applications / faces; it is basically where the bootstrapping
      # process / lifecycle of an app begins.
      def execute
        # The first two phases of the lifecycle of a puppet application are:
        #  1) To parse the command line options and handle any of them that are registered, defined "global" puppet
        #     settings (mostly from defaults.rb).)
        #  2) To parse the puppet config file(s).
        #
        # These 2 steps are being handled explicitly here.  If there ever arises a situation where they need to be
        # triggered from outside of this class, without triggering the rest of the lifecycle--we might want to move them
        # out into a separate method that we call from here.  However, this seems to be sufficient for now.
        #  --cprice 2012-03-16

        # Here's step 1.
        Puppet::Util.exit_on_fail("parse global options")     { parse_global_options }

        # Here's step 2.  NOTE: this is a change in behavior where we are now parsing the config file on every run;
        # before, there were several apps that specifically registered themselves as not requiring anything from
        # the config file.  The fact that we're always parsing it now might be a small performance hit, but it was
        # necessary in order to make sure that we can resolve the libdir before we look for the available applications.
        Puppet::Util.exit_on_fail("parse configuration file") { Puppet.settings.parse }

        # OK, now that we've processed the command line options and the config files, we should be able to say that
        # we definitively know where the libdir is... which means that we can now look for our available
        # applications / subcommands / faces.

        if subcommand_name and available_subcommands.include?(subcommand_name) then
          require_application subcommand_name
          # This will need to be cleaned up to do something that is not so application-specific
          #  (i.e.. so that we can load faces).  Longer-term, use the autoloader.  See comments in
          #  #available_subcommands method above.  --cprice 2012-03-06
          app = Puppet::Application.find(subcommand_name).new(self)
          Puppet::Plugins.on_application_initialization(:appliation_object => self)

          app.run
        elsif ! execute_external_subcommand then
          unless subcommand_name.nil? then
            puts "Error: Unknown Puppet subcommand '#{subcommand_name}'"
          end
          puts "See 'puppet help' for help on available puppet subcommands"
        end
      end

      def execute_external_subcommand
        external_command = "puppet-#{subcommand_name}"

        require 'puppet/util'
        path_to_subcommand = Puppet::Util.which(external_command)
        return false unless path_to_subcommand

        exec(path_to_subcommand, *args)
      end

      def legacy_executable_name
        name = CommandLine::LegacyCommandLine::LEGACY_NAMES[ subcommand_name.intern ]
        return name unless name.nil?
        return subcommand_name.intern
      end

      private

      def subcommand_and_args(zero, argv, stdin)
        zero = File.basename(zero, '.rb')

        if zero == 'puppet'
          case argv.first
            # if they didn't pass a command, or passed a help flag, we will fall back to showing a usage message.
            #  we no longer default to 'apply'
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
