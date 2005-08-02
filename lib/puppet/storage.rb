# $Id$

module Puppet
    # a class for storing state
	class Storage
		include Singleton
		
		def initialize
			self.class.load
		end

        def self.clear
            @@state = nil
            Storage.init
        end

        def self.init
            Puppet.debug "Initializing Storage"
            @@state = Hash.new { |hash,key|
                hash[key] = Hash.new(nil)
            }
            @@splitchar = "\t"
        end

        self.init

		def self.load
            if Puppet[:checksumfile].nil?
                raise "Somehow the statefile is nil"
            end

			unless File.exists?(Puppet[:checksumfile])
                Puppet.info "Statefile %s does not exist" % Puppet[:checksumfile]
                return
            end
            #Puppet.debug "Loading statefile %s" % Puppet[:checksumfile]
			File.open(Puppet[:checksumfile]) { |file|
				file.each { |line|
					myclass, key, value = line.split(@@splitchar)

                    begin
                        @@state[eval(myclass)][key] = Marshal::load(value)
                    rescue => detail
                        raise RuntimeError,
                            "Failed to load value for %s::%s => %s" % [
                                myclass,key,detail
                            ], caller
                    end
				}
			}

            #Puppet.debug "Loaded state is %s" % @@state.inspect
		end

		def self.state(myclass)
            unless myclass.is_a? Class
                myclass = myclass.class
            end
            result = @@state[myclass]
            return result
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

			File.open(Puppet[:checksumfile], File::CREAT|File::WRONLY, 0600) { |file|
				@@state.each { |klass, thash|
                    thash.each { |key,value|
                        mvalue = Marshal::dump(value)
                        file.puts([klass,key,mvalue].join(@@splitchar))
                    }
				}
			}

            #Puppet.debug "Stored state is %s" % @@state.inspect
		end
	end
end
