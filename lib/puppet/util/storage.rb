require 'yaml'
require 'sync'

require 'puppet/util/file_locking'

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
    Storage.init
  end

  def self.init
    @@state = {}
    @@splitchar = "\t"
  end

  self.init

  def self.load
    Puppet.settings.use(:main) unless FileTest.directory?(Puppet[:statedir])

    unless File.exists?(Puppet[:statefile])
      self.init unless !@@state.nil?
      return
    end
    unless File.file?(Puppet[:statefile])
      Puppet.warning("Checksumfile #{Puppet[:statefile]} is not a file, ignoring")
      return
    end
    Puppet::Util.benchmark(:debug, "Loaded state") do
      Puppet::Util::FileLocking.readlock(Puppet[:statefile]) do |file|
        begin
          @@state = YAML.load(file)
        rescue => detail
          Puppet.err "Checksumfile #{Puppet[:statefile]} is corrupt (#{detail}); replacing"
          begin
            File.rename(Puppet[:statefile], Puppet[:statefile] + ".bad")
          rescue
            raise Puppet::Error,
              "Could not rename corrupt #{Puppet[:statefile]}; remove manually"
          end
        end
      end
    end

    unless @@state.is_a?(Hash)
      Puppet.err "State got corrupted"
      self.init
    end

    #Puppet.debug "Loaded state is #{@@state.inspect}"
  end

  def self.stateinspect
    @@state.inspect
  end

  def self.store
    Puppet.debug "Storing state"

    Puppet.info "Creating state file #{Puppet[:statefile]}" unless FileTest.exist?(Puppet[:statefile])

    Puppet::Util.benchmark(:debug, "Stored state") do
      Puppet::Util::FileLocking.writelock(Puppet[:statefile], 0660) do |file|
        file.print YAML.dump(@@state)
      end
    end
  end
end
