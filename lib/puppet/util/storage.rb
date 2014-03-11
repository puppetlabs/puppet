require 'yaml'
require 'sync'
require 'singleton'
require 'puppet/util/yaml'

# a class for storing state
class Puppet::Util::Storage
  include Singleton
  include Puppet::Util

  def self.state
    @@state
  end

  def initialize
    self.class.load
  end

  # Return a hash that will be stored to disk.  It's worth noting
  # here that we use the object's full path, not just the name/type
  # combination.  At the least, this is useful for those non-isomorphic
  # types like exec, but it also means that if an object changes locations
  # in the configuration it will lose its cache.
  def self.cache(object)
    if object.is_a?(Symbol)
      name = object
    else
      name = object.to_s
    end

    @@state[name] ||= {}
  end

  def self.clear
    @@state.clear
  end

  def self.init
    @@state = {}
  end

  self.init

  def self.load
    Puppet.settings.use(:main) unless FileTest.directory?(Puppet[:statedir])
    filename = Puppet[:statefile]

    unless Puppet::FileSystem.exist?(filename)
      self.init if @@state.nil?
      return
    end
    unless File.file?(filename)
      Puppet.warning("Checksumfile #{filename} is not a file, ignoring")
      return
    end
    Puppet::Util.benchmark(:debug, "Loaded state") do
      begin
        @@state = Puppet::Util::Yaml.load_file(filename)
      rescue Puppet::Util::Yaml::YamlLoadError => detail
        Puppet.err "Checksumfile #{filename} is corrupt (#{detail}); replacing"

        begin
          File.rename(filename, filename + ".bad")
        rescue
          raise Puppet::Error, "Could not rename corrupt #{filename}; remove manually", detail.backtrace
        end
      end
    end

    unless @@state.is_a?(Hash)
      Puppet.err "State got corrupted"
      self.init
    end
  end

  def self.stateinspect
    @@state.inspect
  end

  def self.store
    Puppet.debug "Storing state"

    Puppet.info "Creating state file #{Puppet[:statefile]}" unless Puppet::FileSystem.exist?(Puppet[:statefile])

    Puppet::Util.benchmark(:debug, "Stored state") do
      Puppet::Util::Yaml.dump(@@state, Puppet[:statefile])
    end
  end
end
