require 'puppet'
require 'sync'
require 'puppet/transportable'
require 'getoptlong'


# The class for handling configuration files.
class Puppet::Util::Settings
    include Enumerable
    include Puppet::Util

    @@sync = Sync.new

    attr_accessor :file
    attr_reader :timer

    # Retrieve a config value
    def [](param)
        value(param)
    end

    # Set a config value.  This doesn't set the defaults, it sets the value itself.
    def []=(param, value)
        @@sync.synchronize do # yay, thread-safe
            param = symbolize(param)
            unless element = @config[param]
                raise ArgumentError,
                    "Attempt to assign a value to unknown configuration parameter %s" % param.inspect
            end
            if element.respond_to?(:munge)
                value = element.munge(value)
            end
            if element.respond_to?(:handle)
                element.handle(value)
            end
            # Reset the name, so it's looked up again.
            if param == :name
                @name = nil
            end
            @values[:memory][param] = value
            @cache.clear
        end

        return value
    end

    # A simplified equality operator.
    # LAK: For some reason, this causes mocha to not be able to mock
    # the 'value' method, and it's not used anywhere.
#    def ==(other)
#        self.each { |myname, myobj|
#            unless other[myname] == value(myname)
#                return false
#            end
#        }
#
#        return true
#    end

    # Generate the list of valid arguments, in a format that GetoptLong can
    # understand, and add them to the passed option list.
    def addargs(options)
        # Hackish, but acceptable.  Copy the current ARGV for restarting.
        Puppet.args = ARGV.dup

        # Add all of the config parameters as valid options.
        self.each { |name, element|
            element.getopt_args.each { |args| options << args }
        }

        return options
    end

    # Turn the config into a Puppet configuration and apply it
    def apply
        trans = self.to_transportable
        begin
            config = trans.to_catalog
            config.store_state = false
            config.apply
            config.clear
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
        @values.each do |name, values|
            next if name == :cli and exceptcli
            @values.delete(name) 
        end

        # Don't clear the 'used' in this case, since it's a config file reparse,
        # and we want to retain this info.
        unless exceptcli
            @used = []
        end

        @cache.clear

        @name = nil
    end

    # This is mostly just used for testing.
    def clearused
        @cache.clear
        @used = []
    end

    # Do variable interpolation on the value.
    def convert(value)
        return value unless value
        return value unless value.is_a? String
        newval = value.gsub(/\$(\w+)|\$\{(\w+)\}/) do |value|
            varname = $2 || $1
            if pval = self.value(varname)
                pval
            else
                raise Puppet::DevError, "Could not find value for %s" % parent
            end
        end

        return newval
    end

    # Return a value's description.
    def description(name)
        if obj = @config[symbolize(name)]
            obj.desc
        else
            nil
        end
    end

    def each
        @config.each { |name, object|
            yield name, object
        }
    end

    # Iterate over each section name.
    def eachsection
        yielded = []
        @config.each do |name, object|
            section = object.section
            unless yielded.include? section
                yield section
                yielded << section
            end
        end
    end

    # Return an object by name.
    def element(param)
        param = symbolize(param)
        @config[param]
    end

    # Handle a command-line argument.
    def handlearg(opt, value = nil)
        @cache.clear
        value = munge_value(value) if value
        str = opt.sub(/^--/,'')
        bool = true
        newstr = str.sub(/^no-/, '')
        if newstr != str
            str = newstr
            bool = false
        end
        str = str.intern
        if self.valid?(str)
            if self.boolean?(str)
                @values[:cli][str] = bool
            else
                @values[:cli][str] = value
            end
        else
            raise ArgumentError, "Invalid argument %s" % opt
        end
    end

    def include?(name)
        name = name.intern if name.is_a? String
        @config.include?(name)
    end

    # check to see if a short name is already defined
    def shortinclude?(short)
        short = short.intern if name.is_a? String
        @shortnames.include?(short)
    end

    # Create a new config object
    def initialize
        @config = {}
        @shortnames = {}

        @created = []
        @searchpath = nil

        # Keep track of set values.
        @values = Hash.new { |hash, key| hash[key] = {} }

        # And keep a per-environment cache
        @cache = Hash.new { |hash, key| hash[key] = {} }

        # A central concept of a name.
        @name = nil
    end

    # Return a given object's file metadata.
    def metadata(param)
        if obj = @config[symbolize(param)] and obj.is_a?(CFile)
            return [:owner, :group, :mode].inject({}) do |meta, p|
                if v = obj.send(p)
                    meta[p] = v
                end
                meta
            end
        else
            nil
        end
    end

    # Make a directory with the appropriate user, group, and mode
    def mkdir(default)
        obj = get_config_file_default(default)

        Puppet::Util::SUIDManager.asuser(obj.owner, obj.group) do
            mode = obj.mode || 0750
            Dir.mkdir(obj.value, mode)
        end
    end

    # Figure out our name.
    def name
        unless @name
            unless @config[:name]
                return nil
            end
            searchpath.each do |source|
                next if source == :name
                break if @name = @values[source][:name]
            end
            unless @name
                @name = convert(@config[:name].default).intern
            end
        end
        @name
    end

    # Return all of the parameters associated with a given section.
    def params(section = nil)
        if section
            section = section.intern if section.is_a? String
            @config.find_all { |name, obj|
                obj.section == section
            }.collect { |name, obj|
                name
            }
        else
            @config.keys
        end
    end

    # Parse the configuration file.
    def parse(file)
        clear(true)

        parse_file(file).each do |area, values|
            @values[area] = values
        end

        # Determine our environment, if we have one.
        if @config[:environment]
            env = self.value(:environment).to_sym
        else
            env = "none"
        end

        # Call any hooks we should be calling.
        settings_with_hooks.each do |setting|
            each_source(env) do |source|
                if value = @values[source][setting.name]
                    # We still have to use value() to retrieve the value, since
                    # we want the fully interpolated value, not $vardir/lib or whatever.
                    # This results in extra work, but so few of the settings
                    # will have associated hooks that it ends up being less work this
                    # way overall.
                    setting.handle(self.value(setting.name, env))
                    break
                end
            end
        end

        # We have to do it in the reverse of the search path,
        # because multiple sections could set the same value
        # and I'm too lazy to only set the metadata once.
        searchpath.reverse.each do |source|
            if meta = @values[source][:_meta]
                set_metadata(meta)
            end
        end
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

        return element
    end

    # This has to be private, because it doesn't add the elements to @config
    private :newelement

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

    # The order in which to search for values.
    def searchpath(environment = nil)
        if environment
            [:cli, :memory, environment, :name, :main]
        else
            [:cli, :memory, :name, :main]
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
    def section_to_transportable(section, done = nil)
        done ||= Hash.new { |hash, key| hash[key] = {} }
        objects = []
        persection(section) do |obj|
            if @config[:mkusers] and value(:mkusers)
                objects += add_user_resources(section, obj, done)
            end

            value = obj.value

            # Only files are convertable to transportable resources.
            next unless obj.respond_to? :to_transportable and transobjects = obj.to_transportable

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

        bucket = Puppet::TransBucket.new
        bucket.type = "Settings"
        bucket.name = section
        bucket.push(*objects)
        bucket.keyword = "class"

        return bucket
    end

    # Set a bunch of defaults in a given section.  The sections are actually pretty
    # pointless, but they help break things up a bit, anyway.
    def setdefaults(section, defs)
        section = symbolize(section)
        call = []
        defs.each { |name, hash|
            if hash.is_a? Array
                unless hash.length == 2
                    raise ArgumentError, "Defaults specified as an array must contain only the default value and the decription"
                end
                tmp = hash
                hash = {}
                [:default, :desc].zip(tmp).each { |p,v| hash[p] = v }
            end
            name = symbolize(name)
            hash[:name] = name
            hash[:section] = section
            name = hash[:name]
            if @config.include?(name)
                raise ArgumentError, "Parameter %s is already defined" % name
            end
            tryconfig = newelement(hash)
            if short = tryconfig.short
                if other = @shortnames[short]
                    raise ArgumentError, "Parameter %s is already using short name '%s'" % [other.name, short]
                end
                @shortnames[short] = tryconfig
            end
            @config[name] = tryconfig

            # Collect the settings that need to have their hooks called immediately.
            # We have to collect them so that we can be sure we're fully initialized before
            # the hook is called.
            call << tryconfig if tryconfig.call_on_define
        }

        call.each { |setting| setting.handle(self.value(setting.name)) }
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
    def to_configuration
        transport = self.to_transportable
        return transport.to_catalog
    end

    # Convert our list of config elements into a configuration file.
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

        # Add a section heading that matches our name.
        if @config.include?(:name)
            str += "[%s]\n" % self[:name]
        end
        eachsection do |section|
            persection(section) do |obj|
                str += obj.to_config + "\n"
            end
        end

        return str
    end

    # Convert our configuration into a list of transportable objects.
    def to_transportable(*sections)
        done = Hash.new { |hash, key|
            hash[key] = {}
        }

        topbucket = Puppet::TransBucket.new
        if defined? @file.file and @file.file
            topbucket.name = @file.file
        else
            topbucket.name = "top"
        end
        topbucket.type = "Settings"
        topbucket.top = true

        # Now iterate over each section
        if sections.empty?
            eachsection do |section|
                sections << section
            end
        end
        sections.each do |section|
            obj = section_to_transportable(section, done)
            topbucket.push obj
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

            bucket = to_transportable(*sections)

            config = bucket.to_catalog
            config.host_config = false
            config.apply do |transaction|
                if failures = transaction.any_failed?
                    raise "Could not configure for running; got %s failure(s)" % failures
                end
            end
            config.clear

            sections.each { |s| @used << s }
            @used.uniq
        end
    end

    def valid?(param)
        param = symbolize(param)
        @config.has_key?(param)
    end

    # Find the correct value using our search path.  Optionally accept an environment
    # in which to search before the other configuration sections.
    def value(param, environment = nil)
        param = symbolize(param)
        environment = symbolize(environment) if environment

        # Short circuit to nil for undefined parameters.
        return nil unless @config.include?(param)

        # Yay, recursion.
        self.reparse() unless param == :filetimeout

        # Check the cache first.  It needs to be a per-environment
        # cache so that we don't spread values from one env
        # to another.
        if cached = @cache[environment||"none"][param]
            return cached
        end

        # See if we can find it within our searchable list of values
        val = nil
        each_source(environment) do |source|
            # Look for the value.  We have to test the hash for whether
            # it exists, because the value might be false.
            if @values[source].include?(param)
                val = @values[source][param]
                break
            end
        end

        # If we didn't get a value, use the default
        val = @config[param].default if val.nil?

        # Convert it if necessary
        val = convert(val)

        # And cache it
        @cache[environment||"none"][param] = val
        return val
    end

    # Open a file with the appropriate user, group, and mode
    def write(default, *args, &bloc)
        obj = get_config_file_default(default)
        writesub(default, value(obj.name), *args, &bloc)
    end

    # Open a non-default file under a default dir with the appropriate user,
    # group, and mode
    def writesub(default, file, *args, &bloc)
        obj = get_config_file_default(default)
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

    def readwritelock(default, *args, &bloc)
        file = value(get_config_file_default(default).name)
        tmpfile = file + ".tmp"
        sync = Sync.new
        unless FileTest.directory?(File.dirname(tmpfile))
            raise Puppet::DevError, "Cannot create %s; directory %s does not exist" %
                [file, File.dirname(file)]
        end

        sync.synchronize(Sync::EX) do
            File.open(file, "r+", 0600) do |rf|
                rf.lock_exclusive do
                    if File.exist?(tmpfile)
                        raise Puppet::Error, ".tmp file already exists for %s; Aborting locked write. Check the .tmp file and delete if appropriate" %
                            [file]
                    end

                    writesub(default, tmpfile, *args, &bloc)

                    begin
                        File.rename(tmpfile, file)
                    rescue => detail
                        Puppet.err "Could not rename %s to %s: %s" %
                            [file, tmpfile, detail]
                    end
                end
            end
        end
    end

    private

    def get_config_file_default(default)
        obj = nil
        unless obj = @config[default]
            raise ArgumentError, "Unknown default %s" % default
        end

        unless obj.is_a? CFile
            raise ArgumentError, "Default %s is not a file" % default
        end

        return obj
    end
    
    # Create the transportable objects for users and groups.
    def add_user_resources(section, obj, done)
        resources = []
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
                else
                    newobj = Puppet::TransObject.new(name, type.to_s)
                    newobj.tags = ["puppet", "configuration", section]
                    newobj[:ensure] = :present
                    if type == :user
                        newobj[:comment] ||= "%s user" % name
                    end
                    # Set the group appropriately for the user
                    if type == :user
                        newobj[:gid] = Puppet[:group]
                    end
                    done[type][name] = newobj
                    resources << newobj
                end
            end
        end
        resources
    end

    # Yield each search source in turn.
    def each_source(environment)
        searchpath(environment).each do |source|
            # Modify the source as necessary.
            source = self.name if source == :name
            yield source
        end
    end

    # Return all elements that have associated hooks; this is so
    # we can call them after parsing the configuration file.
    def settings_with_hooks
        @config.values.find_all { |setting| setting.respond_to?(:handle) }
    end

    # Extract extra setting information for files.
    def extract_fileinfo(string)
        result = {}
        value = string.sub(/\{\s*([^}]+)\s*\}/) do
            params = $1
            params.split(/\s*,\s*/).each do |str|
                if str =~ /^\s*(\w+)\s*=\s*([\w\d]+)\s*$/
                    param, value = $1.intern, $2
                    result[param] = value
                    unless [:owner, :mode, :group].include?(param)
                        raise ArgumentError, "Invalid file option '%s'" % param
                    end

                    if param == :mode and value !~ /^\d+$/
                        raise ArgumentError, "File modes must be numbers"
                    end
                else
                    raise ArgumentError, "Could not parse '%s'" % string
                end
            end
            ''
        end
        result[:value] = value.sub(/\s*$/, '')
        return result

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
        text = read_file(file)

        # Create a timer so that this file will get checked automatically
        # and reparsed if necessary.
        settimer()

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
            when /^\s*\[(\w+)\]$/:
                section = $1.intern # Section names
                # Add a meta section
                result[section][:_meta] ||= {}
            when /^\s*#/: next # Skip comments
            when /^\s*$/: next # Skip blanks
            when /^\s*(\w+)\s*=\s*(.*)$/: # settings
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
                        value = options[:value]
                        options.delete(:value)
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

    # Read the file in.
    def read_file(file)
        if file.is_a? Puppet::Util::LoadedFile
            @file = file
        else
            @file = Puppet::Util::LoadedFile.new(file)
        end

        begin
            return File.read(@file.file)
        rescue Errno::ENOENT
            raise ArgumentError, "No such file %s" % file
        rescue Errno::EACCES
            raise ArgumentError, "Permission denied to file %s" % file
        end
    end

    # Set file metadata.
    def set_metadata(meta)
        meta.each do |var, values|
            values.each do |param, value|
                @config[var].send(param.to_s + "=", value)
            end
        end
    end

    # The base element type.
    class CElement
        attr_accessor :name, :section, :default, :parent, :setbycli, :call_on_define
        attr_reader :desc, :short

        # Unset any set value.
        def clear
            @value = nil
        end

        def desc=(value)
            @desc = value.gsub(/^\s*/, '')
        end

        # get the arguments in getopt format
        def getopt_args
            if short
                [["--#{name}", "-#{short}", GetoptLong::REQUIRED_ARGUMENT]]
            else
                [["--#{name}", GetoptLong::REQUIRED_ARGUMENT]]
            end
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

        # short name for the celement
        def short=(value)
            if value.to_s.length != 1
                raise ArgumentError, "Short names can only be one character."
            end
            @short = value.to_s
        end

        # Convert the object to a config statement.
        def to_config
            str = @desc.gsub(/^/, "# ") + "\n"

            # Add in a statement about the default.
            if defined? @default and @default
                str += "# The default value is '%s'.\n" % @default
            end

            # If the value has not been overridden, then print it out commented
            # and unconverted, so it's clear that that's the default and how it
            # works.
            value = @parent.value(self.name)

            if value != @default
                line = "%s = %s" % [@name, value]
            else
                line = "# %s = %s" % [@name, @default]
            end

            str += line + "\n"

            str.gsub(/^/, "    ")
        end

        # Retrieves the value, or if it's not set, retrieves the default.
        def value
            @parent.value(self.name)
        end
    end

    # A file.
    class CFile < CElement
        attr_writer :owner, :group
        attr_accessor :mode, :create

        def group
            if defined? @group
                return @parent.convert(@group)
            else
                return nil
            end
        end

        def owner
            if defined? @owner
                return @parent.convert(@owner)
            else
                return nil
            end
        end

        # Set the type appropriately.  Yep, a hack.  This supports either naming
        # the variable 'dir', or adding a slash at the end.
        def munge(value)
            # If it's not a fully qualified path...
            if value.is_a?(String) and value !~ /^\$/ and value !~ /^\// and value != 'false'
                # Make it one
                value = File.join(Dir.getwd, value)
            end
            if value.to_s =~ /\/$/
                @type = :directory
                return value.sub(/\/$/, '')
            end
            return value
        end

        # Return the appropriate type.
        def type
            value = @parent.value(self.name)
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
        def to_transportable
            type = self.type
            return nil unless type

            path = self.value

            return nil unless path.is_a?(String)
            return nil if path =~ /^\/dev/
            return nil if Puppet::Type.type(:file)[path] # skip files that are in our global resource list.

            objects = []

            # Skip plain files that don't exist, since we won't be managing them anyway.
            return nil unless self.name.to_s =~ /dir$/ or File.exist?(path) or self.create
            obj = Puppet::TransObject.new(path, "file")

            # Only create directories, or files that are specifically marked to
            # create.
            if type == :directory or self.create
                obj[:ensure] = type
            end
            [:mode].each { |var|
                if value = self.send(var)
                    # Don't bother converting the mode, since the file type
                    # can handle it any old way.
                    obj[var] = value
                end
            }

            # Only chown or chgrp when root
            if Puppet.features.root?
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
                        "Settings parameter '%s' is undefined" %
                        name
                end
            }
        end
    end

    # A simple boolean.
    class CBoolean < CElement
        # get the arguments in getopt format
        def getopt_args
            if short
                [["--#{name}", "-#{short}", GetoptLong::NO_ARGUMENT],
                 ["--no-#{name}", GetoptLong::NO_ARGUMENT]]
            else
                [["--#{name}", GetoptLong::NO_ARGUMENT],
                 ["--no-#{name}", GetoptLong::NO_ARGUMENT]]
            end
        end

        def munge(value)
            case value
            when true, "true": return true
            when false, "false": return false
            else
                raise ArgumentError, "Invalid value '%s' for %s" %
                    [value.inspect, @name]
            end
        end
    end
end
