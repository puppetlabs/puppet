require 'puppet'
require 'sync'
require 'puppet/transportable'

# The class for handling configuration files.
class Puppet::Util::Config
    include Enumerable
    include Puppet::Util

    @@sync = Sync.new

    attr_reader :file, :timer

    # Retrieve a config value
    def [](param)
        param = symbolize(param)

        # Yay, recursion.
        self.reparse() unless param == :filetimeout

        # Cache the returned values; this method was taking close to
        # 10% of the compile time.
        unless @returned[param]
            if @config.include?(param)
                if @config[param]
                    @returned[param] = @config[param].value
                end
            else
                raise ArgumentError, "Undefined configuration parameter '%s'" % param
            end
        end

        return @returned[param]
    end

    # Set a config value.  This doesn't set the defaults, it sets the value itself.
    def []=(param, value)
        @@sync.synchronize do # yay, thread-safe
            param = symbolize(param)
            unless @config.include?(param)
                raise Puppet::Error,
                    "Attempt to assign a value to unknown configuration parameter %s" % param.inspect
            end
            unless @order.include?(param)
                @order << param
            end
            @config[param].value = value
            if @returned.include?(param)
                @returned.delete(param)
            end
        end

        return value
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

        # Hackish, but acceptable.  Copy the current ARGV for restarting.
        Puppet.args = ARGV.dup

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
            if Puppet[:trace]
                puts detail.backtrace
            end
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

    # Remove all set values, potentially skipping cli values.
    def clear(exceptcli = false)
        @config.each { |name, obj|
            unless exceptcli and obj.setbycli
                obj.clear
            end
        }
        @returned.clear

        # Don't clear the 'used' in this case, since it's a config file reparse,
        # and we want to retain this info.
        unless exceptcli
            @used = []
        end
    end

    # This is mostly just used for testing.
    def clearused
        @returned.clear
        @used = []
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
        value = munge_value(value) if value
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

    def include?(name)
        name = name.intern if name.is_a? String
        @config.include?(name)
    end

    # Create a new config object
    def initialize
        @order = []
        @config = {}

        @created = []
        @returned = {}
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

        Puppet::Util::SUIDManager.asuser(obj.owner, obj.group) do
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

    # Parse the configuration file.
    def parse(file)
        configmap = parse_file(file)

        # We know we want the 'main' section
        if main = configmap[:main]
            set_parameter_hash(main)
        end

        # Otherwise, we only want our named section
        if @config.include?(:name) and named = configmap[symbolize(self[:name])]
            set_parameter_hash(named)
        end
    end

    # Parse the configuration file.  As of May 2007, this is a backward-compatibility method and
    # will be deprecated soon.
    def old_parse(file)
        text = nil

        if file.is_a? Puppet::Util::LoadedFile
            @file = file
        else
            @file = Puppet::Util::LoadedFile.new(file)
        end

        # Don't create a timer for the old style parsing.
        # settimer()

        begin
            text = File.read(@file.file)
        rescue Errno::ENOENT
            raise Puppet::Error, "No such file %s" % file
        rescue Errno::EACCES
            raise Puppet::Error, "Permission denied to file %s" % file
        end

        @values = Hash.new { |names, name|
            names[name] = {}
        }

        # Get rid of the values set by the file, keeping cli values.
        self.clear(true)

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
                if var == :mode
                    value = $2
                else
                    value = munge_value($2)
                end

                # Only warn if we don't know what this config var is.  This
                # prevents exceptions later on.
                unless @config.include?(var) or metas.include?(var.to_s)
                    Puppet.warning "Discarded unknown configuration parameter %s" % var.inspect
                    next # Skip this line.
                end

                # Mmm, "special" attributes
                if metas.include?(var.to_s)
                    unless values.include?(section)
                        values[section] = {}
                    end
                    values[section][var.to_s] = value

                    # If the parameter is valid, then set it.
                    if section == Puppet[:name] and @config.include?(var)
                        @config[var].value = value
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
        when /^\$\w+\//, /^\//:
            klass = CFile
        when String, Integer, Float: # nothing
            klass = CElement
        else
            raise Puppet::Error, "Invalid value '%s' for %s" % [value.inspect, hash[:name]]
        end
        hash[:parent] = self
        element = klass.new(hash)

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

    # Reparse our config file, if necessary.
    def reparse
        if defined? @file and @file.changed?
            Puppet.notice "Reparsing %s" % @file.file
            @@sync.synchronize do
                parse(@file)
            end
            reuse()
        end
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
        persection(section) do |obj|
            if @config[:mkusers] and @config[:mkusers].value
                [:owner, :group].each do |attr|
                    type = nil
                    if attr == :owner
                        type = :user
                    else
                        type = attr
                    end
                    # If a user and/or group is set, then make sure we're
                    # managing that object
                    if obj.respond_to? attr and name = obj.send(attr)
                        # Skip root or wheel
                        next if %w{root wheel}.include?(name.to_s)

                        # Skip owners and groups we've already done, but tag
                        # them with our section if necessary
                        if done[type].include?(name)
                            tags = done[type][name].tags
                            unless tags.include?(section)
                                done[type][name].tags = tags << section
                            end
                        elsif newobj = Puppet::Type.type(type)[name]
                            unless newobj.property(:ensure)
                                newobj[:ensure] = "present"
                            end
                            newobj.tag(section)
                            if type == :user
                                newobj[:comment] ||= "%s user" % name
                            end
                        else
                            newobj = Puppet::TransObject.new(name, type.to_s)
                            newobj.tags = ["puppet", "configuration", section]
                            newobj[:ensure] = "present"
                            if type == :user
                                newobj[:comment] ||= "%s user" % name
                            end
                            # Set the group appropriately for the user
                            if type == :user
                                newobj[:gid] = Puppet[:group]
                            end
                            done[type][name] = newobj
                            objects << newobj
                        end
                    end
                end
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
        end

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

    # Create a timer to check whether the file should be reparsed.
    def settimer
        if Puppet[:filetimeout] > 0
            @timer = Puppet.newtimer(
                :interval => Puppet[:filetimeout],
                :tolerance => 1,
                :start? => true
            ) do
                self.reparse()
            end
        end
    end

    # Convert our list of objects into a component that can be applied.
    def to_component
        transport = self.to_transportable
        return transport.to_type
    end

    # Convert our list of objects into a configuration file.
    def to_config
        str = %{The configuration file for #{Puppet[:name]}.  Note that this file
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
        if defined? @file.file and @file.file
            topbucket.name = @file.file
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
            tags = nil
            if Puppet[:tags]
                tags = Puppet[:tags]
                Puppet[:tags] = ""
            end
            trans = objects.evaluate
            trans.ignoretags = true
            trans.configurator = true
            trans.evaluate
            if tags
                Puppet[:tags] = tags
            end

            # Remove is a recursive process, so it's sufficient to just call
            # it on the component.
            objects.remove(true)

            objects = nil

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

        chown = nil
        if Puppet::Util::SUIDManager.uid == 0
            chown = [obj.owner, obj.group]
        else
            chown = [nil, nil]
        end
        Puppet::Util::SUIDManager.asuser(*chown) do
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

    # Open a non-default file under a default dir with the appropriate user,
    # group, and mode
    def writesub(default, file, *args)
        obj = nil
        unless obj = @config[default]
            raise ArgumentError, "Unknown default %s" % default
        end

        unless obj.is_a? CFile
            raise ArgumentError, "Default %s is not a file" % default
        end

        chown = nil
        if Puppet::Util::SUIDManager.uid == 0
            chown = [obj.owner, obj.group]
        else
            chown = [nil, nil]
        end

        Puppet::Util::SUIDManager.asuser(*chown) do
            mode = obj.mode || 0640
            if args.empty?
                args << "w"
            end

            args << mode

            # Update the umask to make non-executable files
            Puppet::Util.withumask(File.umask ^ 0111) do
                File.open(file, *args) do |file|
                    yield file
                end
            end
        end
    end

    private

    # Extra extra setting information for files.
    def extract_fileinfo(string)
        paramregex = %r{(\w+)\s*=\s*([\w\d]+)}
        result = {}
        string.scan(/\{\s*([^}]+)\s*\}/) do
            params = $1
            params.split(/\s*,\s*/).each do |str|
                if str =~ /^\s*(\w+)\s*=\s*([\w\w]+)\s*$/
                    param, value = $1.intern, $2
                    result[param] = value
                    unless [:owner, :mode, :group].include?(param)
                        raise Puppet::Error, "Invalid file option '%s'" % param
                    end

                    if param == :mode and value !~ /^\d+$/
                        raise Puppet::Error, "File modes must be numbers"
                    end
                else
                    raise Puppet::Error, "Could not parse '%s'" % string
                end
            end

            return result
        end

        return nil
    end

    # Convert arguments into booleans, integers, or whatever.
    def munge_value(value)
        # Handle different data types correctly
        return case value
            when /^false$/i: false
            when /^true$/i: true
            when /^\d+$/i: Integer(value)
            else
                value.gsub(/^["']|["']$/,'').sub(/\s+$/, '')
        end
    end

    # This is an abstract method that just turns a file in to a hash of hashes.
    # We mostly need this for backward compatibility -- as of May 2007 we need to
    # support parsing old files with any section, or new files with just two
    # valid sections.
    def parse_file(file)
        text = nil

        if file.is_a? Puppet::Util::LoadedFile
            @file = file
        else
            @file = Puppet::Util::LoadedFile.new(file)
        end

        # Create a timer so that this file will get checked automatically
        # and reparsed if necessary.
        settimer()

        begin
            text = File.read(@file.file)
        rescue Errno::ENOENT
            raise Puppet::Error, "No such file %s" % file
        rescue Errno::EACCES
            raise Puppet::Error, "Permission denied to file %s" % file
        end

        result = Hash.new { |names, name|
            names[name] = {}
        }

        count = 0

        # Default to 'main' for the section.
        section = :main
        result[section][:_meta] = {}
        text.split(/\n/).each { |line|
            count += 1
            case line
            when /^\[(\w+)\]$/:
                section = $1.intern # Section names
                # Add a meta section
                result[section][:_meta] ||= {}
            when /^\s*#/: next # Skip comments
            when /^\s*$/: next # Skip blanks
            when /^\s*(\w+)\s*=\s*(.+)$/: # settings
                var = $1.intern

                # We don't want to munge modes, because they're specified in octal, so we'll
                # just leave them as a String, since Puppet handles that case correctly.
                if var == :mode
                    value = $2
                else
                    value = munge_value($2)
                end

                # Check to see if this is a file argument and it has extra options
                begin
                    if value.is_a?(String) and options = extract_fileinfo(value)
                        result[section][:_meta][var] = options
                    end
                    result[section][var] = value
                rescue Puppet::Error => detail
                    detail.file = file
                    detail.line = line
                    raise
                end
            else
                error = Puppet::Error.new("Could not match line %s" % line)
                error.file = file
                error.line = line
                raise error
            end
        }

        return result
    end

    # Take all members of a hash and assign their values appropriately.
    def set_parameter_hash(params)
        params.each do |param, value|
            next if param == :_meta
            unless @config.include?(param)
                Puppet.warning "Discarded unknown configuration parameter %s" % param
                next
            end
            if @config[param].setbycli
                Puppet.debug "Ignoring %s set by config file; overridden by cli" % param
            else
                self[param] = value
            end
        end

        if meta = params[:_meta]
            meta.each do |var, values|
                values.each do |param, value|
                    @config[var].send(param.to_s + "=", value)
                end
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

        # Do variable interpolation on the value.
        def convert(value)
            return value unless value
            return value unless value.is_a? String
            newval = value.gsub(/\$(\w+)|\$\{(\w+)\}/) do |value|
                varname = $2 || $1
                if pval = @parent[varname]
                    pval
                else
                    raise Puppet::DevError, "Could not find value for %s" % parent
                end
            end

            return newval
        end

        def desc=(value)
            @desc = value.gsub(/^\s*/, '')
        end

        def hook=(block)
            meta_def :handle, &block
        end

        # Create the new element.  Pretty much just sets the name.
        def initialize(args = {})
            if args.include?(:parent)
                self.parent = args[:parent]
                args.delete(:parent)
            end
            args.each do |param, value|
                method = param.to_s + "="
                unless self.respond_to? method
                    raise ArgumentError, "%s does not accept %s" % [self.class, param]
                end

                self.send(method, value)
            end

            unless self.desc
                raise ArgumentError, "You must provide a description for the %s config option" % self.name
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

            if respond_to?(:handle)
                handle(@value)
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
                    # Don't both converting the mode, since the file type
                    # can handle it any old way.
                    obj[var] = value
                end
            }

            # Only chown or chgrp when root
            if Puppet::Util::SUIDManager.uid == 0
                [:group, :owner].each { |var|
                    if value = self.send(var)
                        obj[var] = value
                    end
                }
            end

            # And set the loglevel to debug for everything
            obj[:loglevel] = "debug"
            
            # We're not actually modifying any files here, and if we allow a
            # filebucket to get used here we get into an infinite recursion
            # trying to set the filebucket up.
            obj[:backup] = false

            if self.section
                obj.tags += ["puppet", "configuration", self.section, self.name]
            end
            objects << obj
            objects
        end

        # Make sure any provided variables look up to something.
        def validate(value)
            return true unless value.is_a? String
            value.scan(/\$(\w+)/) { |name|
                name = $1
                unless @parent.include?(name)
                    raise ArgumentError,
                        "Configuration parameter '%s' is undefined" %
                        name
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

# $Id$
