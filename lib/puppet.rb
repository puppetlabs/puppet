require 'puppet/version'

if Gem::Version.new(RUBY_VERSION.dup) < Gem::Version.new("2.3.0")
  raise LoadError, _("Puppet %{version} requires ruby 2.3.0 or greater.") % { version: Puppet.version }
end

Puppet::OLDEST_RECOMMENDED_RUBY_VERSION = '2.3.0'

# see the bottom of the file for further inclusions
# Also see the new Vendor support - towards the end
#
require 'facter'
require 'puppet/error'
require 'puppet/util'
require 'puppet/util/autoload'
require 'puppet/settings'
require 'puppet/util/feature'
require 'puppet/util/suidmanager'
require 'puppet/util/run_mode'
# PSON is deprecated, use JSON instead
require 'puppet/external/pson/common'
require 'puppet/external/pson/version'
require 'puppet/external/pson/pure'
require 'puppet/gettext/config'


#------------------------------------------------------------
# the top-level module
#
# all this really does is dictate how the whole system behaves, through
# preferences for things like debugging
#
# it's also a place to find top-level commands like 'debug'

# The main Puppet class. Everything is contained here.
#
# @api public
module Puppet
  require 'puppet/file_system'
  require 'puppet/etc'
  require 'puppet/context'
  require 'puppet/environments'

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

  # Get the value for a setting
  #
  # @param [Symbol] param the setting to retrieve
  #
  # @api public
  def self.[](param)
    if param == :debug
      return Puppet::Util::Log.level == :debug
    else
      return @@settings[param]
    end
  end

  require 'puppet/util/logging'
  extend Puppet::Util::Logging

  # Setup facter's logging
  Puppet::Util::Logging.setup_facter_logging!

  # The feature collection
  @features = Puppet::Util::Feature.new('puppet/feature')

  # Load the base features.
  require 'puppet/feature/base'

  # Store a new default value.
  def self.define_settings(section, hash)
    @@settings.define_settings(section, hash)
  end

  # setting access and stuff
  def self.[]=(param,value)
    @@settings[param] = value
  end

  def self.clear
    @@settings.clear
  end

  def self.debug=(value)
    if value
      Puppet::Util::Log.level=(:debug)
    else
      Puppet::Util::Log.level=(:notice)
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

  # Load all of the settings.
  require 'puppet/defaults'

  # Now that settings are loaded we have the code loaded to be able to issue
  # deprecation warnings. Warn if we're on a deprecated ruby version.
  if Gem::Version.new(RUBY_VERSION.dup) < Gem::Version.new(Puppet::OLDEST_RECOMMENDED_RUBY_VERSION)
    Puppet.deprecation_warning(_("Support for ruby version %{version} is deprecated and will be removed in a future release. See https://puppet.com/docs/puppet/latest/system_requirements.html#prerequisites for a list of supported ruby versions.") % { version: RUBY_VERSION })
  end

  # Initialize puppet's settings. This is intended only for use by external tools that are not
  #  built off of the Faces API or the Puppet::Util::Application class. It may also be used
  #  to initialize state so that a Face may be used programatically, rather than as a stand-alone
  #  command-line tool.
  #
  # @api public
  # @param args [Array<String>] the command line arguments to use for initialization
  # @return [void]
  def self.initialize_settings(args = [])
    do_initialize_settings_for_run_mode(:user, args)
  end

  # private helper method to provide the implementation details of initializing for a run mode,
  #  but allowing us to control where the deprecation warning is issued
  def self.do_initialize_settings_for_run_mode(run_mode, args)
    Puppet.settings.initialize_global_settings(args)
    run_mode = Puppet::Util::RunMode[run_mode]
    Puppet.settings.initialize_app_defaults(Puppet::Settings.app_defaults_for_run_mode(run_mode))
    Puppet.push_context(Puppet.base_context(Puppet.settings), "Initial context after settings initialization")
    Puppet::Parser::Functions.reset
  end
  private_class_method :do_initialize_settings_for_run_mode

  # Initialize puppet's core facts. It should not be called before initialize_settings.
  def self.initialize_facts
    # Add the puppetversion fact; this is done before generating the hash so it is
    # accessible to custom facts.
    Facter.add(:puppetversion) do
      setcode { Puppet.version.to_s }
    end

    Facter.add(:agent_specified_environment) do
      setcode do
        if Puppet.settings.set_by_config?(:environment)
          Puppet[:environment]
        end
      end
    end
  end

  # Load vendored (setup paths, and load what is needed upfront).
  # See the Vendor class for how to add additional vendored gems/code
  require "puppet/vendor"
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
                                           Puppet::Node::Environment::NO_MANIFEST))
      end
    end

    {
      :environments => Puppet::Environments::Cached.new(Puppet::Environments::Combined.new(*loaders)),
      :http_pool => proc {
        require 'puppet/network/http'
        Puppet::Network::HTTP::NoCachePool.new
      },
      :ssl_host => proc { Puppet::SSL::Host.localhost },
      :plugins => proc { Puppet::Plugins::Configuration.load_plugins }
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

  require 'puppet/node'

  # The single instance used for normal operation
  @context = Puppet::Context.new(bootstrap_context)
end

# This feels weird to me; I would really like for us to get to a state where there is never a "require" statement
#  anywhere besides the very top of a file.  That would not be possible at the moment without a great deal of
#  effort, but I think we should strive for it and revisit this at some point.  --cprice 2012-03-16

require 'puppet/indirector'
require 'puppet/compilable_resource_type'
require 'puppet/type'
require 'puppet/resource'
require 'puppet/parser'
require 'puppet/network'
require 'puppet/ssl'
require 'puppet/module'
require 'puppet/data_binding'
require 'puppet/util/storage'
require 'puppet/status'
require 'puppet/file_bucket/file'
require 'puppet/plugins/configuration'
