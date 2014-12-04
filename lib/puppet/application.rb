require 'optparse'
require 'puppet/util/command_line'
require 'puppet/util/constant_inflector'
require 'puppet/error'
require 'puppet/application_support'

module Puppet

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
# class Puppet::Application::Example < Puppet::Application
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
# The default +setup+ behaviour is to: read Puppet configuration and manage log level and destination
#
# === What and how to run
# If the +dispatch+ block is defined it is called. This block should return the name of the registered command
# to be run.
# If it doesn't exist, it defaults to execute the +main+ command if defined.
#
# === Execution state
# The class attributes/methods of Puppet::Application serve as a global place to set and query the execution
# status of the application: stopping, restarting, etc.  The setting of the application status does not directly
# affect its running status; it's assumed that the various components within the application will consult these
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
class Application
  require 'puppet/util'
  include Puppet::Util

  DOCPATTERN = ::File.expand_path(::File.dirname(__FILE__) + "/util/command_line/*" )
  CommandLineArgs = Struct.new(:subcommand_name, :args)

  @loader = Puppet::Util::Autoload.new(self, 'puppet/application')

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

    # used to declare code that handle an option
    def option(*options, &block)
      long = options.find { |opt| opt =~ /^--/ }.gsub(/^--(?:\[no-\])?([^ =]+).*$/, '\1' ).gsub('-','_')
      fname = "handle_#{long}".intern
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

    # @return [Array<String>] the names of available applications
    # @api public
    def available_application_names
      @loader.files_to_load.map do |fn|
        ::File.basename(fn, '.rb')
      end.uniq
    end

    # Finds the class for a given application and loads the class. This does
    # not create an instance of the application, it only gets a handle to the
    # class. The code for the application is expected to live in a ruby file
    # `puppet/application/#{name}.rb` that is available on the `$LOAD_PATH`.
    #
    # @param application_name [String] the name of the application to find (eg. "apply").
    # @return [Class] the Class instance of the application that was found.
    # @raise [Puppet::Error] if the application class was not found.
    # @raise [LoadError] if there was a problem loading the application file.
    # @api public
    def find(application_name)
      begin
        require @loader.expand(application_name.to_s.downcase)
      rescue LoadError => e
        Puppet.log_and_raise(e, "Unable to find application '#{application_name}'. #{e}")
      end

      class_name = Puppet::Util::ConstantInflector.file2constant(application_name.to_s)

      clazz = try_load_class(class_name)

      ################################################################
      #### Begin 2.7.x backward compatibility hack;
      ####  eventually we need to issue a deprecation warning here,
      ####  and then get rid of this stanza in a subsequent release.
      ################################################################
      if (clazz.nil?)
        class_name = application_name.capitalize
        clazz = try_load_class(class_name)
      end
      ################################################################
      #### End 2.7.x backward compatibility hack
      ################################################################

      if clazz.nil?
        raise Puppet::Error.new("Unable to load application class '#{class_name}' from file 'puppet/application/#{application_name}.rb'")
      end

      return clazz
    end

    # Given the fully qualified name of a class, attempt to get the class instance.
    # @param [String] class_name the fully qualified name of the class to try to load
    # @return [Class] the Class instance, or nil? if it could not be loaded.
    def try_load_class(class_name)
        return self.const_defined?(class_name) ? const_get(class_name) : nil
    end
    private :try_load_class

    def [](name)
      find(name).new
    end

    # Sets or gets the run_mode name. Sets the run_mode name if a mode_name is
    # passed. Otherwise, gets the run_mode or a default run_mode
    #
    def run_mode( mode_name = nil)
      if mode_name
        Puppet.settings.preferred_run_mode = mode_name
      end

      return @run_mode if @run_mode and not mode_name

      require 'puppet/util/run_mode'
      @run_mode = Puppet::Util::RunMode[ mode_name || Puppet.settings.preferred_run_mode ]
    end

    # This is for testing only
    def clear_everything_for_tests
      @run_mode = @banner = @run_status = @option_parser_commands = nil
    end
  end

  attr_reader :options, :command_line

  # Every app responds to --version
  # See also `lib/puppet/util/command_line.rb` for some special case early
  # handling of this.
  option("--version", "-V") do |arg|
    puts "#{Puppet.version}"
    exit
  end

  # Every app responds to --help
  option("--help", "-h") do |v|
    puts help
    exit
  end

  def app_defaults()
    Puppet::Settings.app_defaults_for_run_mode(self.class.run_mode).merge(
        :name => name
    )
  end

  def initialize_app_defaults()
    Puppet.settings.initialize_app_defaults(app_defaults)
  end

  # override to execute code before running anything else
  def preinit
  end

  def initialize(command_line = Puppet::Util::CommandLine.new)
    @command_line = CommandLineArgs.new(command_line.subcommand_name, command_line.args.dup)
    @options = {}
  end

  # Execute the application.
  # @api public
  # @return [void]
  def run

    # I don't really like the names of these lifecycle phases.  It would be nice to change them to some more meaningful
    # names, and make deprecated aliases.  --cprice 2012-03-16

    exit_on_fail("get application-specific default settings") do
      initialize_app_defaults
    end

    Puppet::ApplicationSupport.push_application_context(self.class.run_mode)

    exit_on_fail("initialize")                                   { preinit }
    exit_on_fail("parse application options")                    { parse_options }
    exit_on_fail("prepare for execution")                        { setup }
    exit_on_fail("configure routes from #{Puppet[:route_file]}") { configure_indirector_routes }
    exit_on_fail("log runtime debug info")                       { log_runtime_environment }
    exit_on_fail("run")                                          { run_command }
  end

  def main
    raise NotImplementedError, "No valid command or main"
  end

  def run_command
    main
  end

  def setup
    setup_logs
  end

  def setup_logs
    if options[:debug] || options[:verbose]
      Puppet::Util::Log.newdestination(:console)
    end

    set_log_level

    Puppet::Util::Log.setup_default unless options[:setdest]
  end

  def set_log_level(opts = nil)
    opts ||= options
    if opts[:debug]
      Puppet::Util::Log.level = :debug
    elsif opts[:verbose] && !Puppet::Util::Log.sendlevel?(:info)
      Puppet::Util::Log.level = :info
    end
  end

  def handle_logdest_arg(arg)
    begin
      Puppet::Util::Log.newdestination(arg)
      options[:setdest] = true
    rescue => detail
      Puppet.log_exception(detail)
    end
  end

  def configure_indirector_routes
    Puppet::ApplicationSupport.configure_indirector_routes(name.to_s)
  end

  # Output basic information about the runtime environment for debugging
  # purposes.
  #
  # @api public
  #
  # @param extra_info [Hash{String => #to_s}] a flat hash of extra information
  #   to log. Intended to be passed to super by subclasses.
  # @return [void]
  def log_runtime_environment(extra_info=nil)
    runtime_info = {
      'puppet_version' => Puppet.version,
      'ruby_version'   => RUBY_VERSION,
      'run_mode'       => self.class.run_mode.name,
    }
    runtime_info['default_encoding'] = Encoding.default_external
    runtime_info.merge!(extra_info) unless extra_info.nil?

    Puppet.debug 'Runtime environment: ' + runtime_info.map{|k,v| k + '=' + v.to_s}.join(', ')
  end

  def parse_options
    # Create an option parser
    option_parser = OptionParser.new(self.class.banner)

    # Here we're building up all of the options that the application may need to handle.  The main
    # puppet settings defined in "defaults.rb" have already been parsed once (in command_line.rb) by
    # the time we get here; however, our app may wish to handle some of them specially, so we need to
    # make the parser aware of them again.  We might be able to make this a bit more efficient by
    # re-using the parser object that gets built up in command_line.rb.  --cprice 2012-03-16

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

  def handlearg(opt, val)
    opt, val = Puppet::Settings.clean_opt(opt, val)
    send(:handle_unknown, opt, val) if respond_to?(:handle_unknown)
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
end
end
