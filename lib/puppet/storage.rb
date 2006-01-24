require 'yaml'

module Puppet
    # a class for storing state
    class Storage
        include Singleton
        
        def initialize
            self.class.load
        end

        # Return a hash that will be stored to disk.  It's worth noting
        # here that we use the object's full path, not just the name/type
        # combination.  At the least, this is useful for those non-isomorphic
        # types like exec, but it also means that if an object changes locations
        # in the configuration it will lose its cache.
        def self.cache(object)
            unless object.is_a? Puppet::Type
                raise Puppet::DevFail, "Must pass a Type instance to Storage.cache"
            end
            return @@state[object.path] ||= {}
        end

        def self.clear
            @@state.clear
            Storage.init
        end

        def self.init
            Puppet.debug "Initializing Storage"
            @@state = {}
            @@splitchar = "\t"
        end

        self.init

        def self.load
            if Puppet[:statefile].nil?
                raise Puppet::DevError, "Somehow the statefile is nil"
            end

            unless File.exists?(Puppet[:statefile])
                Puppet.info "Statefile %s does not exist" % Puppet[:statefile]
                unless defined? @@state and ! @@state.nil?
                    self.init
                end
                return
            end
            #Puppet.debug "Loading statefile %s" % Puppet[:statefile]
            Puppet::Util.lock(Puppet[:statefile]) { |file|
                #@@state = Marshal.load(file)
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
            }

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
            unless FileTest.directory?(File.dirname(Puppet[:statefile]))
                begin
                    Puppet.recmkdir(File.dirname(Puppet[:statefile]))
                    Puppet.info "Creating state directory %s" %
                        File.dirname(Puppet[:statefile])
                rescue => detail
                    Puppet.err "Could not create state file: %s" % detail
                    return
                end
            end

            unless FileTest.exist?(Puppet[:statefile])
                Puppet.info "Creating state file %s" % Puppet[:statefile]
            end

            Puppet::Util.lock(
                Puppet[:statefile], "w", 0600
            ) { |file|
                file.print YAML.dump(@@state)
            }
        end
    end
end

# $Id$
