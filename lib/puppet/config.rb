module Puppet
# The class for handling configuration files.
class Config
    # Retrieve a config value
    def [](param)
        param = param.intern unless param.is_a? Symbol
        if @config.include?(param)
            if @config[param]
                val = @config[param].value
                return val
            end
        else
            nil
        end
    end

    # Set a config value.  This doesn't set the defaults, it sets the value itself.
    def []=(param, value)
        param = param.intern unless param.is_a? Symbol
        unless @config.include?(param)
            @config[param] = newelement(param, value)
        end
        @config[param].value = value
    end

    # Remove all set values.
    def clear
        @config.each { |name, obj|
            obj.clear
        }
    end

    # Create a new config object
    def initialize
        @config = {}
    end

    # Parse a configuration file.
    def parse(file)
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
            when /^\s*(\w+)\s*=\s*(.+)$/: # settings
                var = $1.intern
                value = $2
                Puppet.info "%s: Setting %s to '%s'" % [section, var, value]

                self[var] = value
                @config[var].section = section
            else
                raise Puppet::Error, "Could not match line %s" % line
            end
        }
    end

    # Create a new element.  The value is passed in because it's used to determine
    # what kind of element we're creating, but the value itself might be either
    # a default or a value, so we can't actually assign it.
    def newelement(param, value)
        mod = nil
        case value
        when true, false, "true", "false":
            mod = CBoolean
        when /^\$/, /^\//:
            mod = CFile
        when String: # nothing
        else
            raise Puppet::Error, "Invalid value '%s'" % value
        end
        element = CElement.new(param)
        element.parent = self
        if mod
            element.extend(mod)
        end

        return element
    end

    # Set a bunch of defaults in a given section.  The sections are actually pretty
    # pointless, but they help break things up a bit, anyway.
    def setdefaults(section, hash)
        section = section.intern unless section.is_a? Symbol
        hash.each { |param, value|
            if @config.include?(param) and @config[param].default
                raise Puppet::Error, "Default %s is already defined" % param
            end
            unless @config.include?(param)
                @config[param] = newelement(param, value)
            end
            @config[param].default = value
            @config[param].section = section
        }
    end

    # The base element type.
    class CElement
        attr_accessor :name, :section, :default, :parent

        # Unset any set value.
        def clear
            @value = nil
        end

        # Create the new element.  Pretty much just sets the name.
        def initialize(name, value = nil)
            @name = name
            if value
                @value = value
            end
        end

        # Retrieves the value, or if it's not set, retrieves the default.
        def value
            retval = nil
            if defined? @value and ! @value.nil?
                retval = @value
            elsif defined? @default
                retval = @default
            else
                return nil
            end

            if respond_to?(:convert)
                return convert(retval)
            else
                return retval
            end
        end

        # Set the value.
        def value=(value)
            if respond_to?(:validate)
                validate(value)
            end
            if respond_to?(:munge)
                @value = munge(value)
            else
                @value = value
            end
        end
    end

    # A file.
    module CFile
        attr_accessor :user, :group, :mode, :type

        def convert(value)
            unless value
                return nil
            end
            if value =~ /\$(\w+)/
                parent = $1
                if pval = @parent[parent]
                    newval = value.sub(/\$#{parent}/, pval)
                    return File.join(newval.split("/"))
                else
                    raise Puppet::DevError, "Could not find value for %s" % parent
                end
            else
                return value
            end
        end

        # Set the type appropriately.  Yep, a hack.
        def munge(value)
            if @name.to_s =~ /dir/
                @type = :directory
            else
                @type = :file
            end
            return value
        end

        # Make sure any provided variables look up to something.
        def validate(value)
            value.scan(/\$(\w+)/) { |name|
                name = name[0]
                unless @parent[name]
                    raise Puppet::Error, "'%s' is unset" % name
                end
            }
        end
    end

    # A simple boolean.
    module CBoolean
        def munge(value)
            case value
            when true, "true": return true
            when false, "false": return false
            else
                raise Puppet::Error, "Invalid value %s for %s" % [value, @name]
            end
        end
    end
end
end

# $Id$
