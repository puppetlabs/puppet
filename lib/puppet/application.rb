require 'optparse'
require 'puppet/util/plugins'

# This class handles all the aspects of a Puppet application/executable
# * setting up options
# * setting up logs
# * choosing what to run
# * representing execution status
#
# === Usage
# An application is a subclass of Puppet::Application.
#
# For legacy compatibility,
#      Puppet::Application[:example].run
# is equivalent to
#      Puppet::Application::Example.new.run
#
#
# class Puppet::Application::Example << Puppet::Application
#
#     def preinit
#         # perform some pre initialization
#         @all = false
#     end
#
#     # run_command is called to actually run the specified command
#     def run_command
#         send Puppet::Util::CommandLine.new.args.shift
#     end
#
#     # option uses metaprogramming to create a method
#     # and also tells the option parser how to invoke that method
#     option("--arg ARGUMENT") do |v|
#         @args << v
#     end
#
#     option("--debug", "-d") do |v|
#         @debug = v
#     end
#
#     option("--all", "-a:) do |v|
#         @all = v
#     end
#
#     def handle_unknown(opt,arg)
#         # last chance to manage an option
#         ...
#         # let's say to the framework we finally handle this option
#         true
#     end
#
#     def read
#         # read action
#     end
#
#     def write
#         # writeaction
#     end
#
# end
#
# === Preinit
# The preinit block is the first code to be called in your application, before option parsing,
# setup or command execution.
#
# === Options
# Puppet::Application uses +OptionParser+ to manage the application options.
# Options are defined with the +option+ method to which are passed various
# arguments, including the long option, the short option, a description...
# Refer to +OptionParser+ documentation for the exact format.
# * If the option method is given a block, this one will be called whenever
# the option is encountered in the command-line argument.
# * If the option method has no block, a default functionnality will be used, that
# stores the argument (or true/false if the option doesn't require an argument) in
# the global (to the application) options array.
# * If a given option was not defined by a the +option+ method, but it exists as a Puppet settings:
#  * if +unknown+ was used with a block, it will be called with the option name and argument
#  * if +unknown+ wasn't used, then the option/argument is handed to Puppet.settings.handlearg for
#    a default behavior
#
# --help is managed directly by the Puppet::Application class, but can be overriden.
#
# === Setup
# Applications can use the setup block to perform any initialization.
# The defaul +setup+ behaviour is to: read Puppet configuration and manage log level and destination
#
# === What and how to run
# If the +dispatch+ block is defined it is called. This block should return the name of the registered command
# to be run.
# If it doesn't exist, it defaults to execute the +main+ command if defined.
#
# === Execution state
# The class attributes/methods of Puppet::Application serve as a global place to set and query the execution
# status of the application: stopping, restarting, etc.  The setting of the application status does not directly
# aftect its running status; it's assumed that the various components within the application will consult these
# settings appropriately and affect their own processing accordingly.  Control operations (signal handlers and
# the like) should set the status appropriately to indicate to the overall system that it's the process of
# stopping or restarting (or just running as usual).
#
# So, if something in your application needs to stop the process, for some reason, you might consider:
#
#  def stop_me!
#      # indicate that we're stopping
#      Puppet::Application.stop!
#      # ...do stuff...
#  end
#
# And, if you have some component that involves a long-running process, you might want to consider:
#
#  def my_long_process(giant_list_to_munge)
#      giant_list_to_munge.collect do |member|
#          # bail if we're stopping
#          return if Puppet::Application.stop_requested?
#          process_member(member)
#      end
#  end
module Puppet
class Application
  require 'puppet/util'
  include Puppet::Util

  DOCPATTERN = File.expand_path(File.dirname(__FILE__) + "/util/command_line/*" )

  class << self
    include Puppet::Util

    attr_accessor :run_status

    def clear!
      self.run_status = nil
    end

    def stop!
      self.run_status = :stop_requested
    end

    def restart!
      self.run_status = :restart_requested
    end

    # Indicates that Puppet::Application.restart! has been invoked and components should
    # do what is necessary to facilitate a restart.
    def restart_requested?
      :restart_requested == run_status
    end

    # Indicates that Puppet::Application.stop! has been invoked and components should do what is necessary
    # for a clean stop.
    def stop_requested?
      :stop_requested == run_status
    end

    # Indicates that one of stop! or start! was invoked on Puppet::Application, and some kind of process
    # shutdown/short-circuit may be necessary.
    def interrupted?
      [:restart_requested, :stop_requested].include? run_status
    end

    # Indicates that Puppet::Application believes that it's in usual running run_mode (no stop/restart request
    # currently active).
    def clear?
      run_status.nil?
    end

    # Only executes the given block if the run status of Puppet::Application is clear (no restarts, stops,
    # etc. requested).
    # Upon block execution, checks the run status again; if a restart has been requested during the block's
    # execution, then controlled_run will send a new HUP signal to the current process.
    # Thus, long-running background processes can potentially finish their work before a restart.
    def controlled_run(&block)
      return unless clear?
      result = block.call
      Process.kill(:HUP, $PID) if restart_requested?
      result
    end

    def should_parse_config
      @parse_config = true
    end

    def should_not_parse_config
      @parse_config = false
    end

    def should_parse_config?
      @parse_config = true if ! defined?(@parse_config)
      @parse_config
    end

    # used to declare code that handle an option
    def option(*options, &block)
      long = options.find { |opt| opt =~ /^--/ }.gsub(/^--(?:\[no-\])?([^ =]+).*$/, '\1' ).gsub('-','_')
      fname = symbolize("handle_#{long}")
      if (block_given?)
        define_method(fname, &block)
      else
        define_method(fname) do |value|
          self.options["#{long}".to_sym] = value
        end
      end
      self.option_parser_commands << [options, fname]
    end

    def banner(banner = nil)
      @banner ||= banner
    end

    def option_parser_commands
      @option_parser_commands ||= (
        superclass.respond_to?(:option_parser_commands) ? superclass.option_parser_commands.dup : []
      )
      @option_parser_commands
    end

    def find(name)
      klass = name.to_s.capitalize

      begin
        require File.join('puppet', 'application', name.to_s.downcase)
      rescue LoadError => e
        puts "Unable to find application '#{name}'.  #{e}"
        Kernel::exit(1)
      end

      self.const_get(klass)
    end

    def [](name)
      find(name).new
    end

    # Sets or gets the run_mode name. Sets the run_mode name if a mode_name is
    # passed. Otherwise, gets the run_mode or a default run_mode
    #
    def run_mode( mode_name = nil)
      return @run_mode if @run_mode and not mode_name

      require 'puppet/util/run_mode'
      @run_mode = Puppet::Util::RunMode[ mode_name || :user ]
    end
  end

  attr_reader :options, :command_line

  # Every app responds to --version
  option("--version", "-V") do |arg|
    puts "#{Puppet.version}"
    exit
  end

  # Every app responds to --help
  option("--help", "-h") do |v|
    puts help
    exit
  end

  def should_parse_config?
    self.class.should_parse_config?
  end

  # override to execute code before running anything else
  def preinit
  end

  def initialize(command_line = nil)

    require 'puppet/util/command_line'
    @command_line = command_line || Puppet::Util::CommandLine.new
    set_run_mode self.class.run_mode
    @options = {}

    require 'puppet'
    require 'puppet/util/instrumentation'
    Puppet::Util::Instrumentation.init
  end

  # WARNING: This is a totally scary, frightening, and nasty internal API.  We
  # strongly advise that you do not use this, and if you insist, we will
  # politely allow you to keep both pieces of your broken code.
  #
  # We plan to provide a supported, long-term API to deliver this in a way
  # that you can use.  Please make sure that you let us know if you do require
  # this, and this message is still present in the code. --daniel 2011-02-03
  def set_run_mode(mode)
    @run_mode = mode
    $puppet_application_mode = @run_mode
    $puppet_application_name = name

    if Puppet.respond_to? :settings
      # This is to reduce the amount of confusion in rspec
      # because it might have loaded defaults.rb before the globals were set
      # and thus have the wrong defaults for the current application
      Puppet.settings.set_value(:confdir, Puppet.run_mode.conf_dir, :mutable_defaults)
      Puppet.settings.set_value(:vardir, Puppet.run_mode.var_dir, :mutable_defaults)
      Puppet.settings.set_value(:name, Puppet.application_name.to_s, :mutable_defaults)
      Puppet.settings.set_value(:logdir, Puppet.run_mode.logopts, :mutable_defaults)
      Puppet.settings.set_value(:rundir, Puppet.run_mode.run_dir, :mutable_defaults)
      Puppet.settings.set_value(:run_mode, Puppet.run_mode.name.to_s, :mutable_defaults)
    end
  end

  # This is the main application entry point
  def run
    exit_on_fail("initialize")                                   { hook('preinit')       { preinit } }
    exit_on_fail("parse options")                                { hook('parse_options') { parse_options } }
    exit_on_fail("parse configuration file")                     { Puppet.settings.parse } if should_parse_config?
    exit_on_fail("prepare for execution")                        { hook('setup')         { setup } }
    exit_on_fail("configure routes from #{Puppet[:route_file]}") { configure_indirector_routes }
    exit_on_fail("run")                                          { hook('run_command')   { run_command } }
  end

  def main
    raise NotImplementedError, "No valid command or main"
  end

  def run_command
    main
  end

  def setup
    # Handle the logging settings
    if options[:debug] or options[:verbose]
      Puppet::Util::Log.newdestination(:console)
      if options[:debug]
        Puppet::Util::Log.level = :debug
      else
        Puppet::Util::Log.level = :info
      end
    end

    Puppet::Util::Log.newdestination(:syslog) unless options[:setdest]
  end

  def configure_indirector_routes
    route_file = Puppet[:route_file]
    if ::File.exists?(route_file)
      routes = YAML.load_file(route_file)
      application_routes = routes[name.to_s]
      Puppet::Indirector.configure_routes(application_routes) if application_routes
    end
  end

  def parse_options
    # Create an option parser
    option_parser = OptionParser.new(self.class.banner)

    # Add all global options to it.
    Puppet.settings.optparse_addargs([]).each do |option|
      option_parser.on(*option) do |arg|
        handlearg(option[0], arg)
      end
    end

    # Add options that are local to this application, which were
    # created using the "option()" metaprogramming method.  If there
    # are any conflicts, this application's options will be favored.
    self.class.option_parser_commands.each do |options, fname|
      option_parser.on(*options) do |value|
        # Call the method that "option()" created.
        self.send(fname, value)
      end
    end

    # Scan command line.  We just hand any exceptions to our upper levels,
    # rather than printing help and exiting, so that we can meaningfully
    # respond with context-sensitive help if we want to. --daniel 2011-04-12
    option_parser.parse!(self.command_line.args)
  end

  def handlearg(opt, arg)
    # rewrite --[no-]option to --no-option if that's what was given
    if opt =~ /\[no-\]/ and !arg
      opt = opt.gsub(/\[no-\]/,'no-')
    end
    # otherwise remove the [no-] prefix to not confuse everybody
    opt = opt.gsub(/\[no-\]/, '')
    unless respond_to?(:handle_unknown) and send(:handle_unknown, opt, arg)
      # Puppet.settings.handlearg doesn't handle direct true/false :-)
      if arg.is_a?(FalseClass)
        arg = "false"
      elsif arg.is_a?(TrueClass)
        arg = "true"
      end
      Puppet.settings.handlearg(opt, arg)
    end
  end

  # this is used for testing
  def self.exit(code)
    exit(code)
  end

  def name
    self.class.to_s.sub(/.*::/,"").downcase.to_sym
  end

  def help
    "No help available for puppet #{name}"
  end

  private

  def exit_on_fail(message, code = 1)
    yield
  rescue ArgumentError, RuntimeError, NotImplementedError => detail
    puts detail.backtrace if Puppet[:trace]
    $stderr.puts "Could not #{message}: #{detail}"
    exit(code)
  end

  def hook(step,&block)
    Puppet::Plugins.send("before_application_#{step}",:application_object => self)
    x = yield
    Puppet::Plugins.send("after_application_#{step}",:application_object => self, :return_value => x)
    x
  end
end
end
