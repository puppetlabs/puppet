# A simple class that tells us when a file has changed and thus whether we
# should reload it

require 'puppet'

module Puppet
    class NoSuchFile < Puppet::Error; end
    class ParsedFile
        attr_reader :file

        # Provide a hook for setting the timestamp during testing, so we don't
        # have to depend on the granularity of the filesystem.
        attr_writer :tstamp

        Puppet.config.setdefaults(:puppet,
            :filetimeout => [ 15,
                "The minimum time to wait between checking for updates in
                configuration files."
            ]
        )

        # Determine whether the file has changed and thus whether it should
        # be reparsed
        def changed?
            # Don't actually stat the file more often than filetimeout.
            if Time.now - @statted >= Puppet[:filetimeout]
                tmp = stamp()

                if tmp == @tstamp
                    return false
                else
                    @tstamp = tmp
                    return true
                end
            else
                return false
            end
        end

        # Create the file.  Must be passed the file path.
        def initialize(file)
            @file = file
            unless FileTest.exists?(@file)
                raise Puppet::NoSuchFile, "Can not use a non-existent file for parsing"
            end
            @tstamp = stamp()
        end

        def to_s
            @file
        end

        private

        def stamp
            @statted = Time.now
            return File.stat(@file).ctime
        end
    end
end

# $Id$
