#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet'
require 'puppet/daemon'
require 'puppet/application/agent'

# The command line flags affecting #20900 and #20919:
#
# --onetime
# --daemonize
# --no-daemonize
# --logdest
# --verbose
# --debug
# (no flags)     (-)
#
# d and nd are mutally exclusive
#
# Combinations without logdest, verbose or debug:
#
# --onetime --daemonize
# --onetime --no-daemonize
# --onetime
# --daemonize
# --no-daemonize
# -
#
# 6 cases X [--logdest=console, --logdest=syslog, --logdest=/some/file, <nothing added>]
# = 24 cases to test
#
# X [--verbose, --debug, <nothing added>]
# = 72 cases to test
#
# Expectations of behavior are defined in the expected_loggers, expected_level methods,
# so adapting to a change in logging behavior should hopefully be mostly a matter of
# adjusting the logic in those methods to define new behavior.
#
# Note that this test does not have anything to say about what happens to logging after
# daemonizing.
describe 'agent logging' do
  ONETIME  = '--onetime'
  DAEMONIZE  = '--daemonize'
  NO_DAEMONIZE  = '--no-daemonize'
  LOGDEST_FILE = '--logdest=/dev/null/foo'
  LOGDEST_SYSLOG = '--logdest=syslog'
  LOGDEST_CONSOLE = '--logdest=console'
  VERBOSE  = '--verbose'
  DEBUG  = '--debug'

  DEFAULT_LOG_LEVEL = :notice
  INFO_LEVEL        = :info
  DEBUG_LEVEL       = :debug
  CONSOLE           = :console
  SYSLOG            = :syslog
  EVENTLOG          = :eventlog
  FILE              = :file

  ONETIME_DAEMONIZE_ARGS = [
    [ONETIME],
    [ONETIME, DAEMONIZE],
    [ONETIME, NO_DAEMONIZE],
    [DAEMONIZE],
    [NO_DAEMONIZE],
    [],
  ]
  LOG_DEST_ARGS = [LOGDEST_FILE, LOGDEST_SYSLOG, LOGDEST_CONSOLE, nil]
  LOG_LEVEL_ARGS = [VERBOSE, DEBUG, nil]

  shared_examples "an agent" do |argv, expected|
    before(:each) do
      # Don't actually run the agent, bypassing cert checks, forking and the puppet run itself
      Puppet::Application::Agent.any_instance.stubs(:run_command)
      # Let exceptions be raised instead of exiting
      Puppet::Application::Agent.any_instance.stubs(:exit_on_fail).yields
    end

    def double_of_bin_puppet_agent_call(argv)
      argv.unshift('agent')
      command_line = Puppet::Util::CommandLine.new('puppet', argv)
      command_line.execute
    end

    if Puppet.features.microsoft_windows? && argv.include?(DAEMONIZE)

      it "should exit on a platform which cannot daemonize if the --daemonize flag is set" do
        expect { double_of_bin_puppet_agent_call(argv) }.to raise_error(SystemExit)
      end

    else
      if no_log_dest_set_in(argv)
        it "when evoked with #{argv}, logs to #{expected[:loggers].inspect} at level #{expected[:level]}" do
          # This logger is created by the Puppet::Settings object which creates and
          # applies a catalog to ensure that configuration files and users are in
          # place.
          #
          # It's not something we are specifically testing here since it occurs
          # regardless of user flags.
          Puppet::Util::Log.expects(:newdestination).with(instance_of(Puppet::Transaction::Report)).at_least_once
          expected[:loggers].each do |logclass|
            Puppet::Util::Log.expects(:newdestination).with(logclass).at_least_once
          end
          double_of_bin_puppet_agent_call(argv)

          expect(Puppet::Util::Log.level).to eq(expected[:level])
        end
      end

    end
  end

  def self.no_log_dest_set_in(argv)
    ([LOGDEST_SYSLOG, LOGDEST_CONSOLE, LOGDEST_FILE] & argv).empty?
  end

  def self.verbose_or_debug_set_in_argv(argv)
    !([VERBOSE, DEBUG] & argv).empty?
  end

  def self.log_dest_is_set_to(argv, log_dest)
    argv.include?(log_dest)
  end

  # @param argv Array of commandline flags
  # @return Set<Symbol> of expected loggers
  def self.expected_loggers(argv)
    loggers = Set.new
    loggers << CONSOLE if verbose_or_debug_set_in_argv(argv)
    loggers << 'console' if log_dest_is_set_to(argv, LOGDEST_CONSOLE)
    loggers << '/dev/null/foo' if log_dest_is_set_to(argv, LOGDEST_FILE)
    if Puppet.features.microsoft_windows?
      # an explicit call to --logdest syslog on windows is swallowed silently with no
      # logger created (see #suitable() of the syslog Puppet::Util::Log::Destination subclass)
      # however Puppet::Util::Log.newdestination('syslog') does get called...so we have
      # to set an expectation
      loggers << 'syslog' if log_dest_is_set_to(argv, LOGDEST_SYSLOG)

      loggers << EVENTLOG if no_log_dest_set_in(argv)
    else
      # posix
      loggers << 'syslog' if log_dest_is_set_to(argv, LOGDEST_SYSLOG)
      loggers << SYSLOG if no_log_dest_set_in(argv)
    end
    return loggers
  end

  # @param argv Array of commandline flags
  # @return Symbol of the expected log level
  def self.expected_level(argv)
    case
      when argv.include?(VERBOSE) then INFO_LEVEL
      when argv.include?(DEBUG) then DEBUG_LEVEL
      else DEFAULT_LOG_LEVEL
    end
  end

  # @param argv Array of commandline flags
  # @return Hash of expected loggers and the expected log level
  def self.with_expectations_based_on(argv)
    {
      :loggers => expected_loggers(argv),
      :level => expected_level(argv),
    }
  end

# For running a single spec (by line number): rspec -l150 spec/integration/agent/logging_spec.rb
#  debug_argv = []
#  it_should_behave_like( "an agent", [debug_argv], with_expectations_based_on([debug_argv]))

  ONETIME_DAEMONIZE_ARGS.each do |onetime_daemonize_args|
    LOG_LEVEL_ARGS.each do |log_level_args|
      LOG_DEST_ARGS.each do |log_dest_args|
        argv = (onetime_daemonize_args + [log_level_args, log_dest_args]).flatten.compact

        describe "for #{argv}" do
          it_should_behave_like( "an agent", argv, with_expectations_based_on(argv))
        end
      end
    end
  end
end
