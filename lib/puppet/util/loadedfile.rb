# A simple class that tells us when a file has changed and thus whether we
# should reload it

require 'puppet'

module Puppet
    class NoSuchFile < Puppet::Error; end
    class Util::LoadedFile
        attr_reader :file, :statted

        # Provide a hook for setting the timestamp during testing, so we don't
        # have to depend on the granularity of the filesystem.
        attr_writer :tstamp

        # Determine whether the file has changed and thus whether it should
        # be reparsed.
        def changed?
            # Allow the timeout to be disabled entirely.
            if Puppet[:filetimeout] < 0
                return true
            end
            tmp = stamp()

            # We use a different internal variable than the stamp method
            # because it doesn't keep historical state and we do -- that is,
            # we will always be comparing two timestamps, whereas
            # stamp() just always wants the latest one.
            if tmp == @tstamp
                return false
            else
                @tstamp = tmp
                return @tstamp
            end
        end

        # Create the file.  Must be passed the file path.
        def initialize(file)
            @file = file
            unless FileTest.exists?(@file)
                raise Puppet::NoSuchFile,
                    "Can not use a non-existent file for parsing"
            end
            @statted = 0
            @stamp = nil
            @tstamp = stamp()
        end

        # Retrieve the filestamp, but only refresh it if we're beyond our
        # filetimeout
        def stamp
            if @stamp.nil? or (Time.now.to_i - @statted >= Puppet[:filetimeout])
                @statted = Time.now.to_i
                begin
                    @stamp = File.stat(@file).ctime
                rescue Errno::ENOENT
                    @stamp = Time.now
                end
            end
            return @stamp
        end

        def to_s
            @file
        end
    end
end

