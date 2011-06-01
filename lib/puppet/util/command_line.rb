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
          when nil then
            if stdin.tty? then
              [nil, argv]       # ttys get usage info
            else
              # Killed for 2.7.0 --daniel 2011-06-01
              Puppet.deprecation_warning <<EOM
Implicit invocation of 'puppet apply' by redirection into 'puppet' is deprecated,
and will be removed in the 2.8 series. Please invoke 'puppet apply' directly
in the future.
EOM
              ["apply", argv]
            end
          when "--help", "-h" then
            # help should give you usage, not the help for `puppet apply`
            [nil, argv]
          when /^-|\.pp$|\.rb$/ then
            # Killed for 2.7.0 --daniel 2011-06-01
            Puppet.deprecation_warning <<EOM
Implicit invocation of 'puppet apply' by passing files (or flags) directly
to 'puppet' is deprecated, and will be removed in the 2.8 series.  Please
invoke 'puppet apply' directly in the future.
EOM
            ["apply", argv]
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

# REVISIT: Without this, we can't use the full Puppet suite inside the code,
# but we can't include it before we get this far through defining things as
# this code is the product of incestuous union with the global code; global
# code at load scope depends on methods we define, while we only depend on
# them at runtime scope.  --daniel 2011-06-01
require 'puppet'
