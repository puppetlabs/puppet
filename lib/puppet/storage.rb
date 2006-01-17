require 'yaml'

module Puppet
    # a class for storing state
    class Storage
        include Singleton
        
        def initialize
            self.class.load
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
            if Puppet[:checksumfile].nil?
                raise Puppet::DevError, "Somehow the statefile is nil"
            end

            unless File.exists?(Puppet[:checksumfile])
                Puppet.info "Statefile %s does not exist" % Puppet[:checksumfile]
                unless defined? @@state and ! @@state.nil?
                    self.init
                end
                return
            end
            #Puppet.debug "Loading statefile %s" % Puppet[:checksumfile]
            Puppet::Util.lock(Puppet[:checksumfile]) { |file|
                #@@state = Marshal.load(file)
                begin
                    @@state = YAML.load(file)
                rescue => detail
                    Puppet.err "Checksumfile %s is corrupt; replacing" %
                        Puppet[:checksumfile]
                    begin
                        File.rename(Puppet[:checksumfile],
                            Puppet[:checksumfile] + ".bad")
                    rescue
                        raise Puppet::Error,
                            "Could not rename corrupt %s; remove manually" %
                            Puppet[:checksumfile]
                    end
                end
            }

            #Puppet.debug "Loaded state is %s" % @@state.inspect
        end

        def self.stateinspect
            @@state.inspect
        end

        def self.state(myclass)
            unless myclass.is_a? Class
                myclass = myclass.class
            end

            @@state[myclass.to_s] ||= {}
            return @@state[myclass.to_s]
        end

        def self.store
            unless FileTest.directory?(File.dirname(Puppet[:checksumfile]))
                begin
                    Puppet.recmkdir(File.dirname(Puppet[:checksumfile]))
                    Puppet.info "Creating state directory %s" %
                        File.dirname(Puppet[:checksumfile])
                rescue => detail
                    Puppet.err "Could not create state file: %s" % detail
                    return
                end
            end

            unless FileTest.exist?(Puppet[:checksumfile])
                Puppet.info "Creating state file %s" % Puppet[:checksumfile]
            end

            Puppet::Util.lock(Puppet[:checksumfile], File::CREAT|File::WRONLY, 0600) { |file|
                file.print YAML.dump(@@state)
                #file.puts(Marshal::dump(@@state))
                #File.open(Puppet[:checksumfile], File::CREAT|File::WRONLY, 0600) { |file|
                #    @@state.each { |klass, thash|
                #        thash.each { |key,value|
                #            Puppet.warning "Storing: %s %s %s" %
                #                [klass, key.inspect, value.inspect]
                #            mvalue = Marshal::dump(value)
                #            file.puts([klass,key,mvalue].join(@@splitchar))
                #        }
                #    }
                #}
            }
        end
    end
end

# $Id$
