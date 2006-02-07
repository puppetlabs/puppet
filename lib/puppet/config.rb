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
        unless @order.include?(param)
            @order << param
        end
        @config[param].value = value
    end

    # Remove all set values.
    def clear
        @config.each { |name, obj|
            obj.clear
        }
    end

    def each
        @order.each { |name|
            if @config.include?(name)
                yield name, @config[name]
            else
                raise Puppet::DevError, "%s is in the order but does not exist" % name
            end
        }
    end

    # Return an object by name.
    def element(param)
        param = param.intern unless param.is_a? Symbol
        @config[param]
    end

    # Create a new config object
    def initialize
        @order = []
        @config = {}
    end

    # Parse a configuration file.
    def parse(file)
        text = nil
        @file = file

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
        metas = %w{user group mode}
        values = Hash.new { |hash, key| hash[key] = {} }
        text.split(/\n/).each { |line|
            case line
            when /^\[(\w+)\]$/: section = $1 # Section names
            when /^\s*#/: next # Skip comments
            when /^\s*$/: next # Skip blanks
            when /^\s*(\w+)\s*=\s*(.+)$/: # settings
                var = $1.intern
                value = $2

                # Mmm, "special" attributes
                if metas.include?(var.to_s)
                    unless values.include?(section)
                        values[section] = {}
                    end
                    values[section][var.to_s] = value
                    next
                end
                Puppet.info "%s: Setting %s to '%s'" % [section, var, value]
                self[var] = value
                @config[var].section = section

                metas.each { |meta|
                    if values[section][meta]
                        if @config[var].respond_to?(meta + "=")
                            @config[var].send(meta + "=", values[section][meta])
                        end
                    end
                }
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

    # Convert our list of objects into a component that can be applied.
    def to_component
        transport = self.to_transportable
        return transport.to_type
#        comp = Puppet.type(:component).create(
#            :name => "PuppetConfig"
#        )
#        self.to_objects.each { |hash|
#            type = hash[:type]
#            hash.delete(:name)
#            comp.push Puppet.type(type).create(hash)
#        }
#
#        return comp
    end

    # Convert our configuration into a list of transportable objects.
    def to_transportable
        objects = []
        done = {
            :user => [],
            :group => [],
        }
        sections = {}
        sectionlist = []
        self.each { |name, obj|
            section = obj.section || "puppet"
            sections[section] ||= []
            unless sectionlist.include?(section)
                sectionlist << section
            end
            sections[section] << obj
        }

        topbucket = Puppet::TransBucket.new
        if defined? @file and @file
            topbucket.name = @file
        else
            topbucket.name = "configtop"
        end
        topbucket.type = "puppetconfig"
        topbucket.top = true
        topbucket.autoname = true
        sectionlist.each { |section|
            objects = []
            sections[section].each { |obj|
                Puppet.notice "changing %s" % obj.name
                [:user, :group].each { |type|
                    if obj.respond_to? type and val = obj.send(type)
                        # Skip users and groups we've already done, but tag them with
                        # our section if necessary
                        if done[type].include?(val)
                            next unless defined? @section and @section

                            tags = done[type][val].tags
                            unless tags.include?(@section)
                                done[type][val].tags = tags << @section
                            end
                        else
                            newobj = TransObject.new(val, type.to_s)
                            newobj[:ensure] = "exists"
                            done[type] << newobj
                        end
                    end
                }

                if obj.respond_to? :to_transportable
                    objects << obj.to_transportable
                else
                    Puppet.notice "%s is not transportable" % obj.name
                end
            }

            bucket = Puppet::TransBucket.new
            bucket.autoname = true
            bucket.name = "autosection-%s" % bucket.object_id
            bucket.type = section
            bucket.push(*objects)
            bucket.keyword = "class"

            topbucket.push bucket
        }
#        self.each { |name, obj|
#            [:user, :group].each { |type|
#                if obj.respond_to? type and val = obj.send(type)
#                    # Skip users and groups we've already done, but tag them with
#                    # our section if necessary
#                    if done[type].include?(val)
#                        next unless defined? @section and @section
#
#                        tags = done[type][val].tags
#                        unless tags.include?(@section)
#                            done[type][val].tags = tags << @section
#                        end
#                    else
#                        obj = TransObject.new(val, type.to_s)
#                        obj[:ensure] = "exists"
#                        done[type] << obj
#                    end
#                end
#            }
#
#            if obj.respond_to? :to_transportable
#                objects << obj.to_transportable
#            end
#        }

        topbucket
    end

    # Convert to a parseable manifest
    def to_manifest
        transport = self.to_transportable
        return transport.to_manifest
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

        # Set the type appropriately.  Yep, a hack.  This supports either naming
        # the variable 'dir', or adding a slash at the end.
        def munge(value)
            if value.to_s =~ /dir/
                @type = :directory
            elsif value =~ /\/$/
                @type = :directory
                return value.sub(/\/$/, '')
            else
                @type = :file
            end
            return value
        end

        def to_transportable
            Puppet.notice "transportabling %s" % self.name
            obj = Puppet::TransObject.new(self.value, "file")
            obj[:ensure] = self.type
            [:user, :group, :mode].each { |var|
                if value = self.send(var)
                    obj[var] = value
                end
            }
            if self.section
                obj.tags = ["puppet", "configuration", self.section]
            end
            obj
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
