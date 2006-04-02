require 'puppet'
require 'sync'
require 'puppet/transportable'

module Puppet
# The class for handling configuration files.
class Config
    include Enumerable

    @@sync = Sync.new


    # Retrieve a config value
    def [](param)
        param = symbolize(param)
        if @config.include?(param)
            if @config[param]
                val = @config[param].value
                return val
            end
        else
            raise ArgumentError, "Invalid argument %s" % param
        end
    end

    # Set a config value.  This doesn't set the defaults, it sets the value itself.
    def []=(param, value)
        param = symbolize(param)
        unless @config.include?(param)
            raise Puppet::Error, "Unknown configuration parameter %s" % param.inspect
        end
        unless @order.include?(param)
            @order << param
        end
        @config[param].value = value
    end

    # A simplified equality operator.
    def ==(other)
        self.each { |myname, myobj|
            unless other[myname] == myobj.value
                return false
            end
        }

        return true
    end

    # Generate the list of valid arguments, in a format that GetoptLong can
    # understand, and add them to the passed option list.
    def addargs(options)
        require 'getoptlong'
        # Add all of the config parameters as valid options.
        self.each { |param, obj|
            if self.boolean?(param)
                options << ["--#{param}", GetoptLong::NO_ARGUMENT]
                options << ["--no-#{param}", GetoptLong::NO_ARGUMENT]
            else
                options << ["--#{param}", GetoptLong::REQUIRED_ARGUMENT]
            end
        }

        return options
    end

    # Turn the config into a transaction and apply it
    def apply
        trans = self.to_transportable
        begin
            comp = trans.to_type
            trans = comp.evaluate
            trans.evaluate
            comp.remove
        rescue => detail
                puts detail.backtrace
            Puppet.err "Could not configure myself: %s" % detail
        end
    end

    # Is our parameter a boolean parameter?
    def boolean?(param)
        param = symbolize(param)
        if @config.include?(param) and @config[param].kind_of? CBoolean
            return true
        else
            return false
        end
    end

    # Remove all set values.
    def clear
        @config.each { |name, obj|
            obj.clear
        }
        @used = []
    end

    def symbolize(param)
        case param
        when String: return param.intern
        when Symbol: return param
        else
            raise ArgumentError, "Invalid param type %s" % param.class
        end
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

    # Iterate over each section name.
    def eachsection
        yielded = []
        @order.each { |name|
            if @config.include?(name)
                section = @config[name].section
                unless yielded.include? section
                    yield section
                    yielded << section
                end
            else
                raise Puppet::DevError, "%s is in the order but does not exist" % name
            end
        }
    end

    # Return an object by name.
    def element(param)
        param = symbolize(param)
        @config[param]
    end

    # Handle a command-line argument.
    def handlearg(opt, value = nil)
        if value == "true"
            value = true
        end
        if value == "false"
            value = false
        end
        str = opt.sub(/^--/,'')
        bool = true
        newstr = str.sub(/^no-/, '')
        if newstr != str
            str = newstr
            bool = false
        end
        if self.valid?(str)
            if self.boolean?(str)
                self[str] = bool
            else
                self[str] = value
            end

            # Mark that this was set on the cli, so it's not overridden if the
            # config gets reread.
            @config[str.intern].setbycli = true
        else
            raise ArgumentError, "Invalid argument %s" % opt
        end
    end

    # Create a new config object
    def initialize
        @order = []
        @config = {}

        @created = []
    end

    # Make a directory with the appropriate user, group, and mode
    def mkdir(default)
        obj = nil
        unless obj = @config[default]
            raise ArgumentError, "Unknown default %s" % default
        end

        unless obj.is_a? CFile
            raise ArgumentError, "Default %s is not a file" % default
        end

        Puppet::Util.asuser(obj.owner, obj.group) do
            mode = obj.mode || 0750
            Dir.mkdir(obj.value, mode)
        end
    end

    # Return all of the parameters associated with a given section.
    def params(section)
        section = section.intern if section.is_a? String
        @config.find_all { |name, obj|
            obj.section == section
        }.collect { |name, obj|
            name
        }
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
        metas = %w{owner group mode}
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

                    # Do some annoying skullduggery here.  This is so that
                    # the group can be set in the config file.  The problem
                    # is that we're using the word 'group' twice, which is
                    # confusing.
                    if var == :group and section == Puppet.name and @config.include?(:group)
                        @config[:group].value = value
                    end
                    next
                end

                # Don't override set parameters, since the file is parsed
                # after cli arguments are handled.
                unless @config.include?(var) and @config[var].setbycli
                    Puppet.debug "%s: Setting %s to '%s'" % [section, var, value]
                    self[var] = value
                end
                @config[var].section = symbolize(section)

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
    def newelement(hash)
        value = hash[:value] || hash[:default]
        klass = nil
        if hash[:section]
            hash[:section] = symbolize(hash[:section])
        end
        case value
        when true, false, "true", "false":
            klass = CBoolean
        when /^\$/, /^\//:
            klass = CFile
        when String, Integer, Float: # nothing
            klass = CElement
        else
            raise Puppet::Error, "Invalid value '%s' for %s" % [value.inspect, hash[:name]]
        end
        element = klass.new(hash)
        element.parent = self

        @order << element.name

        return element
    end

    # Iterate across all of the objects in a given section.
    def persection(section)
        section = symbolize(section)
        self.each { |name, obj|
            if obj.section == section
                yield obj
            end
        }
    end

    # Get a list of objects per section
    def sectionlist
        sectionlist = []
        self.each { |name, obj|
            section = obj.section || "puppet"
            sections[section] ||= []
            unless sectionlist.include?(section)
                sectionlist << section
            end
            sections[section] << obj
        }

        return sectionlist, sections
    end

    # Convert a single section into transportable objects.
    def section_to_transportable(section, done = nil, includefiles = true)
        done ||= Hash.new { |hash, key| hash[key] = {} }
        objects = []
        persection(section) { |obj|
            if @config[:mkusers] and @config[:mkusers].value
                [:owner, :group].each { |attr|
                    type = nil
                    if attr == :owner
                        type = :user
                    else
                        type = attr
                    end
                    if obj.respond_to? attr and name = obj.send(attr)
                        # Skip owners and groups we've already done, but tag them with
                        # our section if necessary
                        if done[type].include?(name)
                            tags = done[type][name].tags
                            unless tags.include?(section)
                                done[type][name].tags = tags << section
                            end
                        elsif newobj = Puppet::Type.type(type)[name]
                            unless newobj.state(:ensure)
                                newobj[:ensure] = "present"
                            end
                            newobj.tag(section)
                        else
                            newobj = TransObject.new(name, type.to_s)
                            newobj.tags = ["puppet", "configuration", section]
                            newobj[:ensure] = "present"
                            done[type][name] = newobj
                            objects << newobj
                        end
                    end
                }
            end

            if obj.respond_to? :to_transportable
                next if obj.value =~ /^\/dev/
                transobjects = obj.to_transportable
                transobjects = [transobjects] unless transobjects.is_a? Array
                transobjects.each do |trans|
                    # transportable could return nil
                    next unless trans
                    unless done[:file].include? trans.name
                        @created << trans.name
                        objects << trans
                        done[:file][trans.name] = trans
                    end
                end
            end
        }

        bucket = Puppet::TransBucket.new
        bucket.type = section
        bucket.push(*objects)
        bucket.keyword = "class"

        return bucket
    end

    # Set a bunch of defaults in a given section.  The sections are actually pretty
    # pointless, but they help break things up a bit, anyway.
    def setdefaults(section, defs)
        section = symbolize(section)
        defs.each { |name, hash|
            if hash.is_a? Array
                tmp = hash
                hash = {}
                [:default, :desc].zip(tmp).each { |p,v| hash[p] = v }
            end
            name = symbolize(name)
            hash[:name] = name
            hash[:section] = section
            name = hash[:name]
            if @config.include?(name)
                raise Puppet::Error, "Parameter %s is already defined" % name
            end
            @config[name] = newelement(hash)
        }
    end

    # Convert our list of objects into a component that can be applied.
    def to_component
        transport = self.to_transportable
        return transport.to_type
    end

    # Convert our list of objects into a configuration file.
    def to_config
        str = %{The configuration file for #{Puppet.name}.  Note that this file
is likely to have unused configuration parameters in it; any parameter that's
valid anywhere in Puppet can be in any config file, even if it's not used.

Every section can specify three special parameters: owner, group, and mode.
These parameters affect the required permissions of any files specified after
their specification.  Puppet will sometimes use these parameters to check its
own configured state, so they can be used to make Puppet a bit more self-managing.

Note also that the section names are entirely for human-level organizational
purposes; they don't provide separate namespaces.  All parameters are in a
single namespace.

Generated on #{Time.now}.

}.gsub(/^/, "# ")

        eachsection do |section|
            str += "[#{section}]\n"
            persection(section) do |obj|
                str += obj.to_config + "\n"
            end
        end

        return str
    end

    # Convert our configuration into a list of transportable objects.
    def to_transportable
        done = Hash.new { |hash, key|
            hash[key] = {}
        }

        topbucket = Puppet::TransBucket.new
        if defined? @file and @file
            topbucket.name = @file
        else
            topbucket.name = "configtop"
        end
        topbucket.type = "puppetconfig"
        topbucket.top = true

        # Now iterate over each section
        eachsection do |section|
            topbucket.push section_to_transportable(section, done)
        end

        topbucket
    end

    # Convert to a parseable manifest
    def to_manifest
        transport = self.to_transportable

        manifest = transport.to_manifest + "\n"
        eachsection { |section|
            manifest += "include #{section}\n"
        }

        return manifest
    end

    def reuse
        return unless defined? @used
        @@sync.synchronize do # yay, thread-safe
            @used.each do |section|
                @used.delete(section)
                self.use(section)
            end
        end
    end

    # Create the necessary objects to use a section.  This is idempotent;
    # you can 'use' a section as many times as you want.
    def use(*sections)
        @@sync.synchronize do # yay, thread-safe
            unless defined? @used
                @used = []
            end

            runners = sections.collect { |s|
                symbolize(s)
            }.find_all { |s|
                ! @used.include? s
            }
            return if runners.empty?

            bucket = Puppet::TransBucket.new
            bucket.type = "puppetconfig"
            bucket.top = true

            # Create a hash to keep track of what we've done so far.
            @done = Hash.new { |hash, key| hash[key] = {} }
            runners.each do |section|
                bucket.push section_to_transportable(section, @done, false)
            end

            objects = bucket.to_type

            objects.finalize
            trans = objects.evaluate
            trans.evaluate

            # Remove is a recursive process, so it's sufficient to just call
            # it on the component.
            objects.remove

            runners.each { |s| @used << s }
        end
    end

    def valid?(param)
        param = symbolize(param)
        @config.has_key?(param)
    end

    # Open a file with the appropriate user, group, and mode
    def write(default, *args)
        obj = nil
        unless obj = @config[default]
            raise ArgumentError, "Unknown default %s" % default
        end

        unless obj.is_a? CFile
            raise ArgumentError, "Default %s is not a file" % default
        end

        Puppet::Util.asuser(obj.owner, obj.group) do
            mode = obj.mode || 0640

            if args.empty?
                args << "w"
            end

            args << mode

            File.open(obj.value, *args) do |file|
                yield file
            end
        end
    end

    # The base element type.
    class CElement
        attr_accessor :name, :section, :default, :parent, :setbycli
        attr_reader :desc

        # Unset any set value.
        def clear
            @value = nil
        end

        def convert(value)
            return value unless value
            return value unless value.is_a? String
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

        def desc=(value)
            @desc = value.gsub(/^\s*/, '')
        end

        # Create the new element.  Pretty much just sets the name.
        def initialize(args = {})
            args.each do |param, value|
                method = param.to_s + "="
                unless self.respond_to? method
                    raise ArgumentError, "%s does not accept %s" % [self.class, param]
                end

                self.send(method, value)
            end
        end

        def iscreated
            @iscreated = true
        end

        def iscreated?
            if defined? @iscreated
                return @iscreated
            else
                return false
            end
        end

        def set?
            if defined? @value and ! @value.nil?
                return true
            else
                return false
            end
        end

        # Convert the object to a config statement.
        def to_config
            str = @desc.gsub(/^/, "# ") + "\n"

            # Add in a statement about the default.
            if defined? @default and @default
                str += "# The default value is '%s'.\n" % @default
            end

            line = "%s = %s" % [@name, self.value]

            # If the value has not been overridden, then print it out commented
            # and unconverted, so it's clear that that's the default and how it
            # works.
            if defined? @value and ! @value.nil?
                line = "%s = %s" % [@name, self.value]
            else
                line = "# %s = %s" % [@name, @default]
            end

            str += line + "\n"

            str.gsub(/^/, "    ")
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

            if retval.is_a? String
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
    class CFile < CElement
        attr_writer :owner, :group
        attr_accessor :mode, :create

        def group
            if defined? @group
                return convert(@group)
            else
                return nil
            end
        end

        def owner
            if defined? @owner
                return convert(@owner)
            else
                return nil
            end
        end

        # Set the type appropriately.  Yep, a hack.  This supports either naming
        # the variable 'dir', or adding a slash at the end.
        def munge(value)
            if value.to_s =~ /\/$/
                @type = :directory
                return value.sub(/\/$/, '')
            end
            return value
        end

        # Return the appropriate type.
        def type
            value = self.value
            if @name.to_s =~ /dir/
                return :directory
            elsif value.to_s =~ /\/$/
                return :directory
            elsif value.is_a? String
                return :file
            else
                return nil
            end
        end

        # Convert the object to a TransObject instance.
        # FIXME There's no dependency system in place right now; if you use
        # a section that requires another section, there's nothing done to
        # correct that for you, at the moment.
        def to_transportable
            type = self.type
            return nil unless type
            path = self.value.split(File::SEPARATOR)
            path.shift # remove the leading nil

            objects = []
            obj = Puppet::TransObject.new(self.value, "file")

            # Only create directories, or files that are specifically marked to
            # create.
            if type == :directory or self.create
                obj[:ensure] = type
            end
            [:mode].each { |var|
                if value = self.send(var)
                    obj[var] = "%o" % value
                end
            }

            # Only chown or chgrp when root
            if Process.uid == 0
                [:group, :owner].each { |var|
                    if value = self.send(var)
                        obj[var] = value
                    end
                }
            end

            # And set the loglevel to debug for everything
            obj[:loglevel] = "debug"

            if self.section
                obj.tags = ["puppet", "configuration", self.section]
            end
            objects << obj
            objects
        end

        # Make sure any provided variables look up to something.
        def validate(value)
            return true unless value.is_a? String
            value.scan(/\$(\w+)/) { |name|
                name = name[0]
                unless @parent[name]
                    raise Puppet::Error, "'%s' is unset" % name
                end
            }
        end
    end

    # A simple boolean.
    class CBoolean < CElement
        def munge(value)
            case value
            when true, "true": return true
            when false, "false": return false
            else
                raise Puppet::Error, "Invalid value '%s' for %s" %
                    [value.inspect, @name]
            end
        end
    end
end
end

# $Id$
