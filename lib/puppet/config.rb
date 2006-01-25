module Puppet
# The class for handling configuration files.
class Config
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

    def setdefaults(hash)
        hash.each { |param, value|
            if @defaults.include?(param)
                raise Puppet::Error, "Default %s is already defined" % param
            end

            case value
            when true, false:
                @defaults[param] = Boolean.new(param, value)
            when String:
                @defaults[param] = Element.new(param, value)
            when Hash:
                type = nil
                unless value.include?(:type)
                    raise Puppet::Error, "You must include the object type"
                end
                unless type = Puppet.type(value[:type])
                    raise Puppet::Error, "Invalid type %s" % value[:type]
                end

                value.delete(:type)

                # FIXME this won't work, because we don't want to interpolate the
                # file name until they actually ask for it
                begin
                    @defaults[param] = type.create(value)
                rescue => detail
                    raise Puppet::Error, "Could not create default %s: %s" %
                        [param, detail]
                end
            end
        }
    end

    class Element
        attr_accessor :name, :value
    end

    class File < Element
    end

    class Boolean < Element
        def value=(value)
            unless value == true or value == false
                raise Puppet::DevError, "Invalid value %s for %s" % [value, @name]
            end

            @value = value
        end
    end
end
end

# $Id$
