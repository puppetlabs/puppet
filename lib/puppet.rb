require 'puppet/version'

# see the bottom of the file for further inclusions
require 'facter'
require 'puppet/error'
require 'puppet/util'
require 'puppet/util/autoload'
require 'puppet/settings'
require 'puppet/util/feature'
require 'puppet/util/suidmanager'
require 'puppet/util/run_mode'
require 'puppet/external/pson/common'
require 'puppet/external/pson/version'
require 'puppet/external/pson/pure'

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
  class << self
    include Puppet::Util
    attr_reader :features
    attr_writer :name
  end

  # the hash that determines how our system behaves
  @@settings = Puppet::Settings.new

  # The services running in this process.
  @services ||= []

  require 'puppet/util/logging'

  extend Puppet::Util::Logging

  # The feature collection
  @features = Puppet::Util::Feature.new('puppet/feature')

  # Load the base features.
  require 'puppet/feature/base'

  # Store a new default value.
  def self.define_settings(section, hash)
    @@settings.define_settings(section, hash)
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

  # configuration parameter access and stuff
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

  def self.settings
    @@settings
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

  # Load all of the configuration parameters.
  require 'puppet/defaults'

  def self.genmanifest
    if Puppet[:genmanifest]
      puts Puppet.settings.to_manifest
      exit(0)
    end
  end

  # Parse the config file for this process.
  # @deprecated Use {#initialize_settings}
  def self.parse_config()
    Puppet.deprecation_warning("Puppet.parse_config is deprecated; please use Faces API (which will handle settings and state management for you), or (less desirable) call Puppet.initialize_settings")
    Puppet.initialize_settings
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

  # Initialize puppet's settings for a specified run_mode.
  #
  # @deprecated Use {#initialize_settings}
  def self.initialize_settings_for_run_mode(run_mode)
    Puppet.deprecation_warning("initialize_settings_for_run_mode may be removed in a future release, as may run_mode itself")
    do_initialize_settings_for_run_mode(run_mode, [])
  end

  # private helper method to provide the implementation details of initializing for a run mode,
  #  but allowing us to control where the deprecation warning is issued
  def self.do_initialize_settings_for_run_mode(run_mode, args)
    Puppet.settings.initialize_global_settings(args)
    run_mode = Puppet::Util::RunMode[run_mode]
    Puppet.settings.initialize_app_defaults(Puppet::Settings.app_defaults_for_run_mode(run_mode))
  end
  private_class_method :do_initialize_settings_for_run_mode

  # Create a new type.  Just proxy to the Type class.  The mirroring query
  # code was deprecated in 2008, but this is still in heavy use.  I suppose
  # this can count as a soft deprecation for the next dev. --daniel 2011-04-12
  def self.newtype(name, options = {}, &block)
    Puppet::Type.newtype(name, options, &block)
  end
end

# This feels weird to me; I would really like for us to get to a state where there is never a "require" statement
#  anywhere besides the very top of a file.  That would not be possible at the moment without a great deal of
#  effort, but I think we should strive for it and revisit this at some point.  --cprice 2012-03-16

require 'puppet/type'
require 'puppet/parser'
require 'puppet/resource'
require 'puppet/network'
require 'puppet/ssl'
require 'puppet/module'
require 'puppet/data_binding'
require 'puppet/util/storage'
require 'puppet/status'
require 'puppet/file_bucket/file'
