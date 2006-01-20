module Puppet
# The class for handling configuration files.
class Config < Hash
    # Slight override, since we can't seem to have a subclass where all instances
    # have the same default block.
    def [](section)
        unless self.has_key?(section)
            self[section] = {}
        end
        super
    end

    def initialize(file)
        text = nil

        begin
            text = File.read(file)
        rescue Errno::ENOENT
            raise Puppet::Error, "No such file %s" % file
        rescue Errno::EACCES
            raise Puppet::Error, "Permission denied to file %s" % file
        end

        # Store it for later, in a way that we can test and such.
        @file = Puppet::ParsedFile.new(file)

        @values = Hash.new { |names, name|
            names[name] = {}
        }

        section = "puppet"
        text.split(/\n/).each { |line|
            case line
            when /^\[(\w+)\]$/: section = $1 # Section names
            when /^\s*#/: next # Skip comments
            when /^\s*$/: next # Skip blanks
            when /^\s*(\w+)\s+(.+)$/: # settings
                var = $1
                value = $2
                self[section][var] = value
            else
                raise Puppet::Error, "Could not match line %s" % line
            end
        }
    end
end
end

# $Id$
