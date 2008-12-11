require 'yaml'
require 'sync'

require 'puppet/util/file_locking'

# a class for storing state
class Puppet::Util::Storage
    include Singleton
    include Puppet::Util

    def self.state
        return @@state
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
        if object.is_a? Puppet::Type
            # We used to store things by path, now we store them by ref.
            # In oscar(0.20.0) this changed to using the ref.
            if @@state.include?(object.path)
                @@state[object.ref] = @@state[object.path]
                @@state.delete(object.path)
            end
            name = object.ref
        elsif object.is_a?(Symbol)
            name = object
        else
            raise ArgumentError, "You can only cache information for Types and symbols"
        end

        return @@state[name] ||= {}
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
            unless defined? @@state and ! @@state.nil?
                self.init
            end
            return
        end
        Puppet::Util.benchmark(:debug, "Loaded state") do
            Puppet::Util::FileLocking.readlock(Puppet[:statefile]) do |file|
                begin
                    @@state = YAML.load(file)
                rescue => detail
                    Puppet.err "Checksumfile %s is corrupt (%s); replacing" %
                        [Puppet[:statefile], detail]
                    begin
                        File.rename(Puppet[:statefile],
                            Puppet[:statefile] + ".bad")
                    rescue
                        raise Puppet::Error,
                            "Could not rename corrupt %s; remove manually" %
                            Puppet[:statefile]
                    end
                end
            end
        end

        unless @@state.is_a?(Hash)
            Puppet.err "State got corrupted"
            self.init
        end

        #Puppet.debug "Loaded state is %s" % @@state.inspect
    end

    def self.stateinspect
        @@state.inspect
    end

    def self.store
        Puppet.debug "Storing state"

        unless FileTest.exist?(Puppet[:statefile])
            Puppet.info "Creating state file %s" % Puppet[:statefile]
        end

        Puppet::Util.benchmark(:debug, "Stored state") do
            Puppet::Util::FileLocking.writelock(Puppet[:statefile], 0660) do |file|
                file.print YAML.dump(@@state)
            end
        end
    end
end
