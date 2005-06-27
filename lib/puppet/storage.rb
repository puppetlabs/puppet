# $Id$

module Puppet
    # a class for storing state
	class Storage
		include Singleton
		@@state = Hash.new { |hash,key|
            hash[key] = Hash.new(nil)
        }
		@@splitchar = "\t"
		
		def initialize
			self.class.load
		end

		def Storage.load
            # XXX I should probably use a better default state dir
            Puppet[:statefile] ||= "/var/tmp/puppetstate"
			return unless File.exists?(Puppet[:statefile])
			File.open(Puppet[:statefile]) { |file|
				file.gets { |line|
					myclass, key, value = line.split(@@splitchar)

					@@state[myclass][key] = Marshal::load(value)
				}
			}
		end

		def Storage.state(myclass)
            unless myclass.is_a? Class
                myclass = myclass.class
            end
            result = @@state[myclass]
            return result
		end

		def Storage.store
			File.open(Puppet[:statefile], File::CREAT|File::WRONLY, 0600) { |file|
				@@state.each { |klass, thash|
                    thash.each { |key,value|
                        mvalue = Marshal::dump(value)
                        file.puts([klass,key,mvalue].join(@@splitchar))
                    }
				}
			}
		end
	end
end
