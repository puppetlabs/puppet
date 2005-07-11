# $Id$

module Puppet
    # a class for storing state
	class Storage
		include Singleton
		
		def initialize
			self.class.load
		end

        def Storage.clear
            @@state = nil
            Storage.init
        end

        def Storage.init
            @@state = Hash.new { |hash,key|
                hash[key] = Hash.new(nil)
            }
            @@splitchar = "\t"
        end

        self.init

		def Storage.load
            if Puppet[:statefile].nil?
                raise "Somehow the statefile is nil"
            end

			unless File.exists?(Puppet[:statefile])
                Puppet.info "Statefile %s does not exist" % Puppet[:statefile]
                return
            end
            Puppet.debug "Loading statefile %s" % Puppet[:statefile]
			File.open(Puppet[:statefile]) { |file|
				file.each { |line|
					myclass, key, value = line.split(@@splitchar)

					@@state[eval(myclass)][key] = Marshal::load(value)
				}
			}

            Puppet.debug "Loaded state is %s" % @@state.inspect
		end

		def Storage.state(myclass)
            unless myclass.is_a? Class
                myclass = myclass.class
            end
            result = @@state[myclass]
            return result
		end

		def Storage.store
            unless FileTest.directory?(File.dirname(Puppet[:statefile]))
                begin
                    Puppet.recmkdir(Puppet[:statefile])
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

			File.open(Puppet[:statefile], File::CREAT|File::WRONLY, 0600) { |file|
				@@state.each { |klass, thash|
                    thash.each { |key,value|
                        mvalue = Marshal::dump(value)
                        file.puts([klass,key,mvalue].join(@@splitchar))
                    }
				}
			}

            Puppet.debug "Stored state is %s" % @@state.inspect
		end
	end
end
