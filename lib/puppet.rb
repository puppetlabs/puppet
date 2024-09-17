# frozen_string_literal: true

require_relative 'puppet/version'
require_relative 'puppet/concurrent/synchronized'

Puppet::OLDEST_RECOMMENDED_RUBY_VERSION = '3.1.0'
if Gem::Version.new(RUBY_VERSION.dup) < Gem::Version.new(Puppet::OLDEST_RECOMMENDED_RUBY_VERSION)
  raise LoadError, "Puppet #{Puppet.version} requires Ruby #{Puppet::OLDEST_RECOMMENDED_RUBY_VERSION} or greater, found Ruby #{RUBY_VERSION.dup}."
end

$LOAD_PATH.extend(Puppet::Concurrent::Synchronized)

# see the bottom of the file for further inclusions
# Also see the new Vendor support - towards the end
#
require_relative 'puppet/error'
require_relative 'puppet/util'
require_relative 'puppet/util/autoload'
require_relative 'puppet/settings'
require_relative 'puppet/util/feature'
require_relative 'puppet/util/suidmanager'
require_relative 'puppet/util/run_mode'
require_relative 'puppet/gettext/config'
require_relative 'puppet/defaults'

# Defines the `Puppet` module. There are different entry points into Puppet
# depending on your use case.
#
# To use puppet as a library, see {Puppet::Pal}.
#
# To create a new application, see {Puppet::Application}.
#
# To create a new function, see {Puppet::Functions}.
#
# To access puppet's REST APIs, see https://puppet.com/docs/puppet/latest/http_api/http_api_index.html.
#
# @api public
module Puppet
  require_relative 'puppet/file_system'
  require_relative 'puppet/etc'
  require_relative 'puppet/context'
  require_relative 'puppet/environments'

  class << self
    Puppet::GettextConfig.setup_locale
    Puppet::GettextConfig.create_default_text_domain

    include Puppet::Util
    attr_reader :features
  end

  # the hash that determines how our system behaves
  @@settings = Puppet::Settings.new

  # Note: It's important that these accessors (`self.settings`, `self.[]`) are
  # defined before we try to load any "features" (which happens a few lines below),
  # because the implementation of the features loading may examine the values of
  # settings.
  def self.settings
    @@settings
  end

  # The puppetserver project has its own settings class that is thread-aware; this
  # method is here to allow the puppetserver to define its own custom settings class
  # for multithreaded puppet. It is not intended for use outside of the puppetserver
  # implmentation.
  def self.replace_settings_object(new_settings)
    @@settings = new_settings
  end

  # Get the value for a setting
  #
  # @param [Symbol] param the setting to retrieve
  #
  # @api public
  def self.[](param)
    if param == :debug
      Puppet::Util::Log.level == :debug
    else
      @@settings[param]
    end
  end

  require_relative 'puppet/util/logging'
  extend Puppet::Util::Logging

  # The feature collection
  @features = Puppet::Util::Feature.new('puppet/feature')

  # Load the base features.
  require_relative 'puppet/feature/base'

  # setting access and stuff
  def self.[]=(param, value)
    @@settings[param] = value
  end

  def self.clear
    @@settings.clear
  end

  def self.debug=(value)
    if value
      Puppet::Util::Log.level = (:debug)
    else
      Puppet::Util::Log.level = (:notice)
    end
  end

  def self.run_mode
    # This sucks (the existence of this method); there are a lot of places in our code that branch based the value of
    # "run mode", but there used to be some really confusing code paths that made it almost impossible to determine
    # when during the lifecycle of a puppet application run the value would be set properly.  A lot of the lifecycle
    # stuff has been cleaned up now, but it still seems frightening that we rely so heavily on this value.
    #
    # I'd like to see about getting rid of the concept of "run_mode" entirely, but there are just too many places in
    # the code that call this method at the moment... so I've settled for isolating it inside of the Settings class
    # (rather than using a global variable, as we did previously...).  Would be good to revisit this at some point.
    #
    # --cprice 2012-03-16
    Puppet::Util::RunMode[@@settings.preferred_run_mode]
  end

  # Modify the settings with defaults defined in `initialize_default_settings` method in puppet/defaults.rb. This can
  # be used in the initialization of new Puppet::Settings objects in the puppetserver project.
  Puppet.initialize_default_settings!(settings)

  # Now that settings are loaded we have the code loaded to be able to issue
  # deprecation warnings. Warn if we're on a deprecated ruby version.
  # Update JRuby version constraints in PUP-11716
  if Gem::Version.new(RUBY_VERSION.dup) < Gem::Version.new(Puppet::OLDEST_RECOMMENDED_RUBY_VERSION)
    Puppet.deprecation_warning(_("Support for ruby version %{version} is deprecated and will be removed in a future release. See https://puppet.com/docs/puppet/latest/system_requirements.html for a list of supported ruby versions.") % { version: RUBY_VERSION })
  end

  # Initialize puppet's settings. This is intended only for use by external tools that are not
  #  built off of the Faces API or the Puppet::Util::Application class. It may also be used
  #  to initialize state so that a Face may be used programatically, rather than as a stand-alone
  #  command-line tool.
  #
  # @api public
  # @param args [Array<String>] the command line arguments to use for initialization
  # @param require_config [Boolean] controls loading of Puppet configuration files
  # @param global_settings [Boolean] controls push to global context after settings object initialization
  # @param runtime_implementations [Hash<Symbol, Object>] runtime implementations to register
  # @return [void]
  def self.initialize_settings(args = [], require_config = true, push_settings_globally = true, runtime_implementations = {})
    do_initialize_settings_for_run_mode(:user, args, require_config, push_settings_globally, runtime_implementations)
  end

  def self.vendored_modules
    dir = Puppet[:vendormoduledir]
    if dir && File.directory?(dir)
      Dir.entries(dir)
         .reject { |f| f =~ /^\./ }
         .map { |f| File.join(dir, f, "lib") }
         .select { |d| FileTest.directory?(d) }
    else
      []
    end
  end
  private_class_method :vendored_modules

  def self.initialize_load_path
    $LOAD_PATH.unshift(Puppet[:libdir])
    $LOAD_PATH.concat(vendored_modules)
  end
  private_class_method :initialize_load_path

  # private helper method to provide the implementation details of initializing for a run mode,
  #  but allowing us to control where the deprecation warning is issued
  def self.do_initialize_settings_for_run_mode(run_mode, args, require_config, push_settings_globally, runtime_implementations)
    Puppet.settings.initialize_global_settings(args, require_config)
    run_mode = Puppet::Util::RunMode[run_mode]
    Puppet.settings.initialize_app_defaults(Puppet::Settings.app_defaults_for_run_mode(run_mode))
    if push_settings_globally
      initialize_load_path
      push_context_global(Puppet.base_context(Puppet.settings), "Initial context after settings initialization")
      Puppet::Parser::Functions.reset
    end
    runtime_implementations.each_pair do |name, impl|
      Puppet.runtime[name] = impl
    end
  end
  private_class_method :do_initialize_settings_for_run_mode

  # Initialize puppet's core facts. It should not be called before initialize_settings.
  def self.initialize_facts
    # Add the puppetversion fact; this is done before generating the hash so it is
    # accessible to custom facts.
    Puppet.runtime[:facter].add(:puppetversion) do
      setcode { Puppet.version.to_s }
    end

    Puppet.runtime[:facter].add(:agent_specified_environment) do
      setcode do
        Puppet.settings.set_by_cli(:environment) ||
          Puppet.settings.set_in_section(:environment, :agent) ||
          Puppet.settings.set_in_section(:environment, :main)
      end
    end
  end

  # Load vendored (setup paths, and load what is needed upfront).
  # See the Vendor class for how to add additional vendored gems/code
  require_relative 'puppet/vendor'
  Puppet::Vendor.load_vendored

  # The bindings used for initialization of puppet
  #
  # @param settings [Puppet::Settings,Hash<Symbol,String>] either a Puppet::Settings instance
  #   or a Hash of settings key/value pairs.
  # @api private
  def self.base_context(settings)
    environmentpath = settings[:environmentpath]
    basemodulepath = Puppet::Node::Environment.split_path(settings[:basemodulepath])

    if environmentpath.nil? || environmentpath.empty?
      raise(Puppet::Error, _("The environmentpath setting cannot be empty or nil."))
    else
      loaders = Puppet::Environments::Directories.from_path(environmentpath, basemodulepath)
      # in case the configured environment (used for the default sometimes)
      # doesn't exist
      default_environment = Puppet[:environment].to_sym
      if default_environment == :production
        modulepath = settings[:modulepath]
        modulepath = (modulepath.nil? || '' == modulepath) ? basemodulepath : Puppet::Node::Environment.split_path(modulepath)
        loaders << Puppet::Environments::StaticPrivate.new(
          Puppet::Node::Environment.create(default_environment,
                                           modulepath,
                                           Puppet::Node::Environment::NO_MANIFEST)
        )
      end
    end

    {
      :environments => Puppet::Environments::Cached.new(Puppet::Environments::Combined.new(*loaders)),
      :ssl_context => proc { Puppet.runtime[:http].default_ssl_context },
      :http_session => proc { Puppet.runtime[:http].create_session },
      :plugins => proc { Puppet::Plugins::Configuration.load_plugins },
      :rich_data => Puppet[:rich_data],
      # `stringify_rich` controls whether `rich_data` is stringified into a lossy format
      # instead of a lossless format. Catalogs should not be stringified, though to_yaml
      # and the resource application have uses for a lossy, user friendly format.
      :stringify_rich => false
    }
  end

  # A simple set of bindings that is just enough to limp along to
  # initialization where the {base_context} bindings are put in place
  # @api private
  def self.bootstrap_context
    root_environment = Puppet::Node::Environment.create(:'*root*', [], Puppet::Node::Environment::NO_MANIFEST)
    {
      :current_environment => root_environment,
      :root_environment => root_environment
    }
  end

  # @param overrides [Hash] A hash of bindings to be merged with the parent context.
  # @param description [String] A description of the context.
  # @api private
  def self.push_context(overrides, description = "")
    @context.push(overrides, description)
  end

  # Push something onto the context and make it global across threads. This
  # has the potential to convert threadlocal overrides earlier on the stack into
  # global overrides.
  # @api private
  def self.push_context_global(overrides, description = '')
    @context.unsafe_push_global(overrides, description)
  end

  # Return to the previous context.
  # @raise [StackUnderflow] if the current context is the root
  # @api private
  def self.pop_context
    @context.pop
  end

  # Lookup a binding by name or return a default value provided by a passed block (if given).
  # @api private
  def self.lookup(name, &block)
    @context.lookup(name, &block)
  end

  # @param bindings [Hash] A hash of bindings to be merged with the parent context.
  # @param description [String] A description of the context.
  # @yield [] A block executed in the context of the temporarily pushed bindings.
  # @api private
  def self.override(bindings, description = "", &block)
    @context.override(bindings, description, &block)
  end

  # @param name The name of a context key to ignore; intended for test usage.
  # @api private
  def self.ignore(name)
    @context.ignore(name)
  end

  # @param name The name of a previously ignored context key to restore; intended for test usage.
  # @api private
  def self.restore(name)
    @context.restore(name)
  end

  # @api private
  def self.mark_context(name)
    @context.mark(name)
  end

  # @api private
  def self.rollback_context(name)
    @context.rollback(name)
  end

  def self.runtime
    @runtime
  end

  require_relative 'puppet/node'

  # The single instance used for normal operation
  @context = Puppet::Context.new(bootstrap_context)

  require_relative 'puppet/runtime'
  @runtime = Puppet::Runtime.instance
end

# This feels weird to me; I would really like for us to get to a state where there is never a "require" statement
#  anywhere besides the very top of a file.  That would not be possible at the moment without a great deal of
#  effort, but I think we should strive for it and revisit this at some point.  --cprice 2012-03-16

require_relative 'puppet/indirector'
require_relative 'puppet/compilable_resource_type'
require_relative 'puppet/type'
require_relative 'puppet/resource'
require_relative 'puppet/parser'
require_relative 'puppet/network'
require_relative 'puppet/x509'
require_relative 'puppet/ssl'
require_relative 'puppet/module'
require_relative 'puppet/data_binding'
require_relative 'puppet/util/storage'
require_relative 'puppet/file_bucket/file'
require_relative 'puppet/plugins/configuration'
require_relative 'puppet/pal/pal_api'
require_relative 'puppet/node/facts'
