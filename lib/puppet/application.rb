# frozen_string_literal: true

require 'optparse'
require_relative '../puppet/util/command_line'
require_relative '../puppet/util/constant_inflector'
require_relative '../puppet/error'
require_relative '../puppet/application_support'

module Puppet
# Defines an abstract Puppet application.
#
# # Usage
#
# To create a new application extend `Puppet::Application`. Derived applications
# must implement the `main` method and should implement the `summary` and
# `help` methods in order to be included in `puppet help`, and should define
# application-specific options. For example:
#
# ```
# class Puppet::Application::Example < Puppet::Application
#
#   def summary
#     "My puppet example application"
#   end
#
#   def help
#     <<~HELP
#     puppet-example(8) -- #{summary}
#     ...
#     HELP
#   end
#
#   # define arg with a required option
#   option("--arg ARGUMENT") do |v|
#     options[:arg] = v
#   end
#
#   # define arg with an optional option
#   option("--maybe [ARGUMENT]") do |v|
#     options[:maybe] = v
#   end
#
#   # define long and short arg
#   option("--all", "-a")
#
#   def initialize(command_line = Puppet::Util::CommandLine.new)
#     super
#     @data = {}
#   end
#
#   def main
#     # call action
#     send(@command_line.args.shift)
#   end
#
#   def read
#     # read action
#   end
#
#   def write
#     # write action
#   end
#
# end
# ```
#
# Puppet defines the following application lifecycle methods that are called in
# the following order:
#
# * {#initialize}
# * {#initialize_app_defaults}
# * {#preinit}
# * {#parse_options}
# * {#setup}
# * {#main}
#
# ## Execution state
# The class attributes/methods of Puppet::Application serve as a global place to set and query the execution
# status of the application: stopping, restarting, etc.  The setting of the application status does not directly
# affect its running status; it's assumed that the various components within the application will consult these
# settings appropriately and affect their own processing accordingly.  Control operations (signal handlers and
# the like) should set the status appropriately to indicate to the overall system that it's the process of
# stopping or restarting (or just running as usual).
#
# So, if something in your application needs to stop the process, for some reason, you might consider:
#
# ```
#  def stop_me!
#    # indicate that we're stopping
#    Puppet::Application.stop!
#    # ...do stuff...
#  end
# ```
#
# And, if you have some component that involves a long-running process, you might want to consider:
#
# ```
#  def my_long_process(giant_list_to_munge)
#    giant_list_to_munge.collect do |member|
#      # bail if we're stopping
#      return if Puppet::Application.stop_requested?
#      process_member(member)
#    end
#  end
# ```
# @abstract
# @api public
class Application
  require_relative '../puppet/util'
  include Puppet::Util

  DOCPATTERN = ::File.expand_path(::File.dirname(__FILE__) + "/util/command_line/*")
  CommandLineArgs = Struct.new(:subcommand_name, :args)

  @loader = Puppet::Util::Autoload.new(self, 'puppet/application')

  class << self
    include Puppet::Util

    attr_accessor :run_status

    def clear!
      self.run_status = nil
    end

    # Signal that the application should stop.
    # @api public
    def stop!
      self.run_status = :stop_requested
    end

    # Signal that the application should restart.
    # @api public
    def restart!
      self.run_status = :restart_requested
    end

    # Indicates that Puppet::Application.restart! has been invoked and components should
    # do what is necessary to facilitate a restart.
    # @api public
    def restart_requested?
      :restart_requested == run_status
    end

    # Indicates that Puppet::Application.stop! has been invoked and components should do what is necessary
    # for a clean stop.
    # @api public
    def stop_requested?
      :stop_requested == run_status
    end

    # Indicates that one of stop! or start! was invoked on Puppet::Application, and some kind of process
    # shutdown/short-circuit may be necessary.
    # @api public
    def interrupted?
      [:restart_requested, :stop_requested].include? run_status
    end

    # Indicates that Puppet::Application believes that it's in usual running run_mode (no stop/restart request
    # currently active).
    # @api public
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
      long = options.find { |opt| opt =~ /^--/ }.gsub(/^--(?:\[no-\])?([^ =]+).*$/, '\1').tr('-', '_')
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
      # Use our configured environment to load the application, as it may
      # be in a module we installed locally, otherwise fallback to our
      # current environment (*root*). Once we load the application the
      # current environment will change from *root* to the application
      # specific environment.
      environment = Puppet.lookup(:environments).get(Puppet[:environment]) ||
                    Puppet.lookup(:current_environment)
      @loader.files_to_load(environment).map do |fn|
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
        Puppet.log_and_raise(e, _("Unable to find application '%{application_name}'. %{error}") % { application_name: application_name, error: e })
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
        raise Puppet::Error.new(_("Unable to load application class '%{class_name}' from file 'puppet/application/%{application_name}.rb'") % { class_name: class_name, application_name: application_name })
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

    # Return an instance of the specified application.
    #
    # @param [Symbol] name the lowercase name of the application
    # @return [Puppet::Application] an instance of the specified name
    # @raise [Puppet::Error] if the application class was not found.
    # @raise [LoadError] if there was a problem loading the application file.
    # @api public
    def [](name)
      find(name).new
    end

    # Sets or gets the run_mode name. Sets the run_mode name if a mode_name is
    # passed. Otherwise, gets the run_mode or a default run_mode
    # @api public
    def run_mode(mode_name = nil)
      if mode_name
        Puppet.settings.preferred_run_mode = mode_name
      end

      return @run_mode if @run_mode and !mode_name

      require_relative '../puppet/util/run_mode'
      @run_mode = Puppet::Util::RunMode[mode_name || Puppet.settings.preferred_run_mode]
    end

    # Sets environment_mode name. When acting as a compiler, the environment mode
    # should be `:local` since the directory must exist to compile the catalog.
    # When acting as an agent, the environment mode should be `:remote` since
    # the Puppet[:environment] setting refers to an environment directoy on a remote
    # system. The `:not_required` mode is for cases where the application does not
    # need an environment to run.
    #
    # @param mode_name [Symbol] The name of the environment mode to run in. May
    #   be one of `:local`, `:remote`, or `:not_required`. This impacts where the
    #   application looks for its specified environment. If `:not_required` or
    #   `:remote` are set, the application will not fail if the environment does
    #   not exist on the local filesystem.
    # @api public
    def environment_mode(mode_name)
      raise Puppet::Error, _("Invalid environment mode '%{mode_name}'") % { mode_name: mode_name } unless [:local, :remote, :not_required].include?(mode_name)

      @environment_mode = mode_name
    end

    # Gets environment_mode name. If none is set with `environment_mode=`,
    # default to :local.
    # @return [Symbol] The current environment mode
    # @api public
    def get_environment_mode
      @environment_mode || :local
    end

    # This is for testing only
    # @api public
    def clear_everything_for_tests
      @run_mode = @banner = @run_status = @option_parser_commands = nil
    end
  end

  attr_reader :options, :command_line

  # Every app responds to --version
  # See also `lib/puppet/util/command_line.rb` for some special case early
  # handling of this.
  option("--version", "-V") do |_arg|
    puts "#{Puppet.version}"
    exit(0)
  end

  # Every app responds to --help
  option("--help", "-h") do |_v|
    puts help
    exit(0)
  end

  # Initialize the application receiving the {Puppet::Util::CommandLine} object
  # containing the application name and arguments.
  #
  # @param command_line [Puppet::Util::CommandLine] An instance of the command line to create the application with
  # @api public
  def initialize(command_line = Puppet::Util::CommandLine.new)
    @command_line = CommandLineArgs.new(command_line.subcommand_name, command_line.args.dup)
    @options = {}
  end

  # Now that the `run_mode` has been resolved, return default settings for the
  # application. Note these values may be overridden when puppet's configuration
  # is loaded later.
  #
  # @example To override the facts terminus:
  #   def app_defaults
  #     super.merge({
  #       :facts_terminus => 'yaml'
  #     })
  #   end
  #
  # @return [Hash<String, String>] default application settings
  # @api public
  def app_defaults
    Puppet::Settings.app_defaults_for_run_mode(self.class.run_mode).merge(
      :name => name
    )
  end

  # Initialize application defaults. It's usually not necessary to override this method.
  # @return [void]
  # @api public
  def initialize_app_defaults
    Puppet.settings.initialize_app_defaults(app_defaults)
  end

  # The preinit block is the first code to be called in your application, after
  # `initialize`, but before option parsing, setup or command execution. It is
  # usually not necessary to override this method.
  # @return [void]
  # @api public
  def preinit
  end

  # Call in setup of subclass to deprecate an application.
  # @return [void]
  # @api public
  def deprecate
    @deprecated = true
  end

  # Return true if this application is deprecated.
  # @api public
  def deprecated?
    @deprecated
  end

  # Execute the application. This method should not be overridden.
  # @return [void]
  # @api public
  def run
    # I don't really like the names of these lifecycle phases.  It would be nice to change them to some more meaningful
    # names, and make deprecated aliases.  --cprice 2012-03-16

    exit_on_fail(_("Could not get application-specific default settings")) do
      initialize_app_defaults
    end

    Puppet::ApplicationSupport.push_application_context(self.class.run_mode, self.class.get_environment_mode)

    exit_on_fail(_("Could not initialize"))                { preinit }
    exit_on_fail(_("Could not parse application options")) { parse_options }
    exit_on_fail(_("Could not prepare for execution"))     { setup }

    if deprecated?
      Puppet.deprecation_warning(_("`puppet %{name}` is deprecated and will be removed in a future release.") % { name: name })
    end

    exit_on_fail(_("Could not configure routes from %{route_file}") % { route_file: Puppet[:route_file] }) { configure_indirector_routes }
    exit_on_fail(_("Could not log runtime debug info"))                       { log_runtime_environment }
    exit_on_fail(_("Could not run"))                                          { run_command }
  end

  # This method must be overridden and perform whatever action is required for
  # the application. The `command_line` reader contains the actions and
  # arguments.
  # @return [void]
  # @api public
  def main
    raise NotImplementedError, _("No valid command or main")
  end

  # Run the application. By default, it calls {#main}.
  # @return [void]
  # @api public
  def run_command
    main
  end

  # Setup the application. It is usually not necessary to override this method.
  # @return [void]
  # @api public
  def setup
    setup_logs
  end

  # Setup logging. By default the `console` log destination will only be created
  # if `debug` or `verbose` is specified on the command line. Override to customize
  # the logging behavior.
  # @return [void]
  # @api public
  def setup_logs
    handle_logdest_arg(Puppet[:logdest]) unless options[:setdest]

    unless options[:setdest]
      if options[:debug] || options[:verbose]
        Puppet::Util::Log.newdestination(:console)
      end
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
    return if arg.nil?

    logdest = arg.split(',').map!(&:strip)
    Puppet[:logdest] = arg

    logdest.each do |dest|
      begin
        Puppet::Util::Log.newdestination(dest)
        options[:setdest] = true
      rescue => detail
        Puppet.log_and_raise(detail, _("Could not set logdest to %{dest}.") % { dest: arg })
      end
    end
  end

  def configure_indirector_routes
    Puppet::ApplicationSupport.configure_indirector_routes(name.to_s)
  end

  # Output basic information about the runtime environment for debugging
  # purposes.
  #
  # @param extra_info [Hash{String => #to_s}] a flat hash of extra information
  #   to log. Intended to be passed to super by subclasses.
  # @return [void]
  # @api public
  def log_runtime_environment(extra_info = nil)
    runtime_info = {
      'puppet_version' => Puppet.version,
      'ruby_version' => RUBY_VERSION,
      'run_mode' => self.class.run_mode.name
    }
    unless Puppet::Util::Platform.jruby_fips?
      runtime_info['openssl_version'] = "'#{OpenSSL::OPENSSL_VERSION}'"
      runtime_info['openssl_fips'] = OpenSSL::OPENSSL_FIPS
    end
    runtime_info['default_encoding'] = Encoding.default_external
    runtime_info.merge!(extra_info) unless extra_info.nil?

    Puppet.debug 'Runtime environment: ' + runtime_info.map { |k, v| k + '=' + v.to_s }.join(', ')
  end

  # Options defined with the `option` method are parsed from settings and the command line.
  # Refer to {OptionParser} documentation for the exact format. Options are parsed as follows:
  #
  # * If the option method is given a block, then it will be called whenever the option is encountered in the command-line argument.
  # * If the option method has no block, then the default option handler will store the argument in the `options` instance variable.
  # * If a given option was not defined by an `option` method, but it exists as a Puppet setting:
  #   * if `unknown` was used with a block, it will be called with the option name and argument.
  #   * if `unknown` wasn't used, then the option/argument is handed to Puppet.settings.handlearg for
  #     a default behavior.
  #  * The `-h` and `--help` options are automatically handled by the command line before creating the application.
  #
  # Options specified on the command line override settings. It is usually not
  # necessary to override this method.
  # @return [void]
  # @api public
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
    self.class.to_s.sub(/.*::/, "").downcase.to_sym
  end

  # Return the text to display when running `puppet help`.
  # @return [String] The help to display
  # @api public
  def help
    _("No help available for puppet %{app_name}") % { app_name: name }
  end

  # The description used in top level `puppet help` output
  # If left empty in implementations, we will attempt to extract
  # the summary from the help text itself.
  # @return [String]
  # @api public
  def summary
    ""
  end
end
end
