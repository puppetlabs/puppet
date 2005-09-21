# A simple class that tells us when a file has changed and thus whether we
# should reload it

require 'puppet'

module Puppet
    class ParsedFile
        # Determine whether the file has changed and thus whether it should
        # be reparsed
        def changed?
            tmp = self.stamp
            retval = false
            if tmp != @stamp
                retval = true
                @stamp = tmp
            end
            @statted = Time.now

            return retval
        end

        # Create the file.  Must be passed the file path.
        def initialize(file)
            @file = file
            unless FileTest.exists?(@file)
                raise Puppet::DevError, "Can not use a non-existent file for parsing"
            end
            @stamp = self.stamp
            @statted = Time.now
        end

        def stamp
            File.stat(@file).ctime
        end
    end
end
