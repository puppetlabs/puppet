require "puppet/util/plugins"

module Puppet
  module Util
    class CommandLine

      LegacyName = Hash.new{|h,k| k}.update(
        'agent'      => 'puppetd',
        'cert'       => 'puppetca',
        'doc'        => 'puppetdoc',
        'filebucket' => 'filebucket',
        'apply'      => 'puppet',
        'describe'   => 'pi',
        'queue'      => 'puppetqd',
        'resource'   => 'ralsh',
        'kick'       => 'puppetrun',
        'master'     => 'puppetmasterd',
        'device'     => 'puppetdevice'
      )

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

      def self.available_subcommands
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

      def execute
        if subcommand_name and available_subcommands.include?(subcommand_name) then
          require_application subcommand_name
          app = Puppet::Application.find(subcommand_name).new(self)
          Puppet::Plugins.on_application_initialization(:appliation_object => self)
          app.run
        elsif execute_external_subcommand then
          # Logically, we shouldn't get here, but we do, so whatever.  We just
          # return to the caller.  How strange we are. --daniel 2011-04-11
        else
          unless subcommand_name.nil? then
            puts "Error: Unknown Puppet subcommand #{subcommand_name}.\n"
          end

          # Doing this at the top of the file is natural, but causes puppet.rb
          # to load too early, which causes things to break.  This is a nasty
          # thing, found in #7065. --daniel 2011-04-11
          require 'puppet/face'
          puts Puppet::Face[:help, :current].help
        end
      end

      def execute_external_subcommand
        external_command = "puppet-#{subcommand_name}"

        require 'puppet/util'
        path_to_subcommand = Puppet::Util.which(external_command)
        return false unless path_to_subcommand

        system(path_to_subcommand, *args)
        true
      end

      def legacy_executable_name
        LegacyName[ subcommand_name ]
      end

      private

      def subcommand_and_args(zero, argv, stdin)
        zero = File.basename(zero, '.rb')

        if zero == 'puppet'
          case argv.first
          when nil;              [ stdin.tty? ? nil : "apply", argv] # ttys get usage info
          when "--help", "-h";         [nil,     argv] # help should give you usage, not the help for `puppet apply`
          when /^-|\.pp$|\.rb$/; ["apply", argv]
          else [ argv.first, argv[1..-1] ]
          end
        else
          [ zero, argv ]
        end
      end

    end
  end
end
