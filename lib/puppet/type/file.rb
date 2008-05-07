require 'digest/md5'
require 'cgi'
require 'etc'
require 'uri'
require 'fileutils'
require 'puppet/network/handler'
require 'puppet/util/diff'
require 'puppet/util/checksums'

module Puppet
    newtype(:file) do
        include Puppet::Util::MethodHelper
        include Puppet::Util::Checksums
        @doc = "Manages local files, including setting ownership and
            permissions, creation of both files and directories, and
            retrieving entire files from remote servers.  As Puppet matures, it
            expected that the ``file`` resource will be used less and less to
            manage content, and instead native resources will be used to do so.
            
            If you find that you are often copying files in from a central
            location, rather than using native resources, please contact
            Reductive Labs and we can hopefully work with you to develop a
            native resource to support what you are doing."

        newparam(:path) do
            desc "The path to the file to manage.  Must be fully qualified."
            isnamevar

            validate do |value|
                unless value =~ /^#{File::SEPARATOR}/
                    raise Puppet::Error, "File paths must be fully qualified"
                end
            end
        end

        newparam(:backup) do
            desc "Whether files should be backed up before
                being replaced.  The preferred method of backing files up is via
                a ``filebucket``, which stores files by their MD5 sums and allows
                easy retrieval without littering directories with backups.  You
                can specify a local filebucket or a network-accessible
                server-based filebucket by setting ``backup => bucket-name``.
                Alternatively, if you specify any value that begins with a ``.``
                (e.g., ``.puppet-bak``), then Puppet will use copy the file in
                the same directory with that value as the extension of the
                backup. Setting ``backup => false`` disables all backups of the
                file in question.
                
                Puppet automatically creates a local filebucket named ``puppet`` and
                defaults to backing up there.  To use a server-based filebucket,
                you must specify one in your configuration::
                    
                    filebucket { main:
                        server => puppet
                    }

                The ``puppetmasterd`` daemon creates a filebucket by default,
                so you can usually back up to your main server with this
                configuration.  Once you've described the bucket in your
                configuration, you can use it in any file::

                    file { \"/my/file\":
                        source => \"/path/in/nfs/or/something\",
                        backup => main
                    }

                This will back the file up to the central server.

                At this point, the benefits of using a filebucket are that you do not
                have backup files lying around on each of your machines, a given
                version of a file is only backed up once, and you can restore
                any given file manually, no matter how old.  Eventually,
                transactional support will be able to automatically restore
                filebucketed files.
                "

            defaultto { "puppet" }
            
            munge do |value|
                # I don't really know how this is happening.
                value = value.shift if value.is_a?(Array)

                case value
                when false, "false", :false:
                    false
                when true, "true", ".puppet-bak", :true:
                    ".puppet-bak"
                when /^\./
                    value
                when String:
                    # We can't depend on looking this up right now,
                    # we have to do it after all of the objects
                    # have been instantiated.
                    if resource.catalog and bucketobj = resource.catalog.resource(:filebucket, value)
                        @resource.bucket = bucketobj.bucket
                        bucketobj.title
                    else
                        # Set it to the string; finish() turns it into a
                        # filebucket.
                        @resource.bucket = value
                        value
                    end
                when Puppet::Network::Client.client(:Dipper):
                    @resource.bucket = value
                    value.name
                else
                    self.fail "Invalid backup type %s" %
                        value.inspect
                end
            end
        end

        newparam(:recurse) do
            desc "Whether and how deeply to do recursive
                management."

            newvalues(:true, :false, :inf, /^[0-9]+$/)

            # Replace the validation so that we allow numbers in
            # addition to string representations of them.
            validate { |arg| }
            munge do |value|
                newval = super(value)
                case newval
                when :true, :inf: true
                when :false: false
                when Integer, Fixnum, Bignum: value
                when /^\d+$/: Integer(value)
                else
                    raise ArgumentError, "Invalid recurse value %s" % value.inspect
                end
            end
        end

        newparam(:replace, :boolean => true) do
            desc "Whether or not to replace a file that is
                sourced but exists.  This is useful for using file sources
                purely for initialization."
            newvalues(:true, :false)
            aliasvalue(:yes, :true)
            aliasvalue(:no, :false)
            defaultto :true
        end

        newparam(:force, :boolean => true) do
            desc "Force the file operation.  Currently only used when replacing
                directories with links."
            newvalues(:true, :false)
            defaultto false
        end

        newparam(:ignore) do
            desc "A parameter which omits action on files matching
                specified patterns during recursion.  Uses Ruby's builtin globbing
                engine, so shell metacharacters are fully supported, e.g. ``[a-z]*``.
                Matches that would descend into the directory structure are ignored,
                e.g., ``*/*``."
       
            defaultto false

            validate do |value|
                unless value.is_a?(Array) or value.is_a?(String) or value == false
                    self.devfail "Ignore must be a string or an Array"
                end
            end
        end

        newparam(:links) do
            desc "How to handle links during file actions.  During file copying,
                ``follow`` will copy the target file instead of the link, ``manage``
                will copy the link itself, and ``ignore`` will just pass it by.
                When not copying, ``manage`` and ``ignore`` behave equivalently
                (because you cannot really ignore links entirely during local
                recursion), and ``follow`` will manage the file to which the
                link points."

            newvalues(:follow, :manage)

            defaultto :manage
        end

        newparam(:purge, :boolean => true) do
            desc "Whether unmanaged files should be purged.  If you have a filebucket
                configured the purged files will be uploaded, but if you do not,
                this will destroy data.  Only use this option for generated
                files unless you really know what you are doing.  This option only
                makes sense when recursively managing directories.
                
                Note that when using ``purge`` with ``source``, Puppet will purge any files
                that are not on the remote system."

            defaultto :false

            newvalues(:true, :false)
        end

        newparam(:sourceselect) do
            desc "Whether to copy all valid sources, or just the first one.  This parameter
                is only used in recursive copies; by default, the first valid source is the
                only one used as a recursive source, but if this parameter is set to ``all``,
                then all valid sources will have all of their contents copied to the local host,
                and for sources that have the same file, the source earlier in the list will
                be used."

            defaultto :first

            newvalues(:first, :all)
        end
        
        attr_accessor :bucket

        # Autorequire any parent directories.
        autorequire(:file) do
            if self[:path]
                File.dirname(self[:path])
            else
                Puppet.err "no path for %s, somehow; cannot setup autorequires" % self.ref
                nil
            end
        end

        # Autorequire the owner and group of the file.
        {:user => :owner, :group => :group}.each do |type, property|
            autorequire(type) do
                if @parameters.include?(property)
                    # The user/group property automatically converts to IDs
                    next unless should = @parameters[property].shouldorig
                    val = should[0]
                    if val.is_a?(Integer) or val =~ /^\d+$/
                        nil
                    else
                        val
                    end
                end
            end
        end
        
        CREATORS = [:content, :source, :target]

        validate do
            count = 0
            CREATORS.each do |param|
                count += 1 if self.should(param)
            end
            if count > 1
                self.fail "You cannot specify more than one of %s" % CREATORS.collect { |p| p.to_s}.join(", ")
            end
        end
        
        def self.[](path)
            return nil unless path
            super(path.gsub(/\/+/, '/').sub(/\/$/, ''))
        end

        # List files, but only one level deep.
        def self.instances(base = "/")
            unless FileTest.directory?(base)
                return []
            end

            files = []
            Dir.entries(base).reject { |e|
                e == "." or e == ".."
            }.each do |name|
                path = File.join(base, name)
                if obj = self[path]
                    obj[:check] = :all
                    files << obj
                else
                    files << self.create(
                        :name => path, :check => :all
                    )
                end
            end
            files
        end

        @depthfirst = false


        def argument?(arg)
            @arghash.include?(arg)
        end

        # Determine the user to write files as.
        def asuser
            if self.should(:owner) and ! self.should(:owner).is_a?(Symbol)
                writeable = Puppet::Util::SUIDManager.asuser(self.should(:owner)) {
                    FileTest.writable?(File.dirname(self[:path]))
                }

                # If the parent directory is writeable, then we execute
                # as the user in question.  Otherwise we'll rely on
                # the 'owner' property to do things.
                if writeable
                    asuser = self.should(:owner)
                end
            end

            return asuser
        end

        # We have to do some extra finishing, to retrieve our bucket if
        # there is one.
        def finish
            # Look up our bucket, if there is one
            if bucket = self.bucket
                case bucket
                when String:
                    if catalog and obj = catalog.resource(:filebucket, bucket)
                        self.bucket = obj.bucket
                    elsif bucket == "puppet"
                        obj = Puppet::Network::Client.client(:Dipper).new(
                            :Path => Puppet[:clientbucketdir]
                        )
                        self.bucket = obj
                    else
                        self.fail "Could not find filebucket '%s'" % bucket
                    end
                when Puppet::Network::Client.client(:Dipper): # things are hunky-dorey
                when Puppet::Type::Filebucket # things are hunky-dorey
                    self.bucket = bucket.bucket
                else
                    self.fail "Invalid bucket type %s" % bucket.class
                end
            end
            super
        end
        
        # Create any children via recursion or whatever.
        def eval_generate
            recurse()
        end

        # Deal with backups.
        def handlebackup(file = nil)
            # let the path be specified
            file ||= self[:path]
            # if they specifically don't want a backup, then just say
            # we're good
            unless FileTest.exists?(file)
                return true
            end

            unless self[:backup]
                return true
            end

            case File.stat(file).ftype
            when "directory":
                if self[:recurse]
                    # we don't need to backup directories when recurse is on
                    return true
                else
                    backup = self.bucket || self[:backup]
                    case backup
                    when Puppet::Network::Client.client(:Dipper):
                        notice "Recursively backing up to filebucket"
                        require 'find'
                        Find.find(self[:path]) do |f|
                            if File.file?(f)
                                sum = backup.backup(f)
                                self.info "Filebucketed %s to %s with sum %s" %
                                    [f, backup.name, sum]
                            end
                        end

                        return true
                    when String:
                        newfile = file + backup
                        # Just move it, since it's a directory.
                        if FileTest.exists?(newfile)
                            remove_backup(newfile)
                        end
                        begin
                            bfile = file + backup

                            # Ruby 1.8.1 requires the 'preserve' addition, but
                            # later versions do not appear to require it.
                            FileUtils.cp_r(file, bfile, :preserve => true)
                            return true
                        rescue => detail
                            # since they said they want a backup, let's error out
                            # if we couldn't make one
                            self.fail "Could not back %s up: %s" %
                                [file, detail.message]
                        end
                    else
                        self.err "Invalid backup type %s" % backup.inspect
                        return false
                    end
                end
            when "file":
                backup = self.bucket || self[:backup]
                case backup
                when Puppet::Network::Client.client(:Dipper):
                    sum = backup.backup(file)
                    self.info "Filebucketed to %s with sum %s" %
                        [backup.name, sum]
                    return true
                when String:
                    newfile = file + backup
                    if FileTest.exists?(newfile)
                        remove_backup(newfile)
                    end
                    begin
                        # FIXME Shouldn't this just use a Puppet object with
                        # 'source' specified?
                        bfile = file + backup

                        # Ruby 1.8.1 requires the 'preserve' addition, but
                        # later versions do not appear to require it.
                        FileUtils.cp(file, bfile, :preserve => true)
                        return true
                    rescue => detail
                        # since they said they want a backup, let's error out
                        # if we couldn't make one
                        self.fail "Could not back %s up: %s" %
                            [file, detail.message]
                    end
                else
                    self.err "Invalid backup type %s" % backup.inspect
                    return false
                end
            when "link": return true
            else
                self.notice "Cannot backup files of type %s" % File.stat(file).ftype
                return false
            end
        end
        
        def handleignore(children)
            return children unless self[:ignore]
            self[:ignore].each { |ignore|
                ignored = []
                Dir.glob(File.join(self[:path],ignore), File::FNM_DOTMATCH) {
                    |match| ignored.push(File.basename(match))
                }
                children = children - ignored
            }
            return children
        end
          
        def initialize(hash)
            # Store a copy of the arguments for later.
            tmphash = hash.to_hash

            # Used for caching clients
            @clients = {}

            super

            # Get rid of any duplicate slashes, and remove any trailing slashes.
            @title = @title.gsub(/\/+/, "/")
            
            @title.sub!(/\/$/, "") unless @title == "/"

            # Clean out as many references to any file paths as possible.
            # This was the source of many, many bugs.
            @arghash = tmphash
            @arghash.delete(self.class.namevar)

            [:source, :parent].each do |param|
                if @arghash.include?(param)
                    @arghash.delete(param)
                end
            end

            @stat = nil
        end

        # Build a recursive map of a link source
        def linkrecurse(recurse)
            target = @parameters[:target].should

            method = :lstat
            if self[:links] == :follow
                method = :stat
            end

            targetstat = nil
            unless FileTest.exist?(target)
                return
            end
            # Now stat our target
            targetstat = File.send(method, target)
            unless targetstat.ftype == "directory"
                return
            end

            # Now that we know our corresponding target is a directory,
            # change our type
            self[:ensure] = :directory

            unless FileTest.readable? target
                self.notice "Cannot manage %s: permission denied" % self.name
                return
            end

            children = Dir.entries(target).reject { |d| d =~ /^\.+$/ }
         
            # Get rid of ignored children
            if @parameters.include?(:ignore)
                children = handleignore(children)
            end

            added = []
            children.each do |file|
                Dir.chdir(target) do
                    longname = File.join(target, file)

                    # Files know to create directories when recursion
                    # is enabled and we're making links
                    args = {
                        :recurse => recurse,
                        :ensure => longname
                    }

                    if child = self.newchild(file, true, args)
                        added << child
                    end
                end
            end
            
            added
        end

        # Build up a recursive map of what's around right now
        def localrecurse(recurse)
            unless FileTest.exist?(self[:path]) and self.stat.directory?
                #self.info "%s is not a directory; not recursing" %
                #    self[:path]
                return
            end

            unless FileTest.readable? self[:path]
                self.notice "Cannot manage %s: permission denied" % self.name
                return
            end

            children = Dir.entries(self[:path])
         
            #Get rid of ignored children
            if @parameters.include?(:ignore)
                children = handleignore(children)
            end

            added = []
            children.each { |file|
                file = File.basename(file)
                next if file =~ /^\.\.?$/ # skip . and .. 
                options = {:recurse => recurse}

                if child = self.newchild(file, true, options)
                    added << child
                end
            }
            
            added
        end
        
        # Create a new file or directory object as a child to the current
        # object.
        def newchild(path, local, hash = {})
            raise(Puppet::DevError, "File recursion cannot happen without a catalog") unless catalog

            # make local copy of arguments
            args = symbolize_options(@arghash)

            # There's probably a better way to do this, but we don't want
            # to pass this info on.
            if v = args[:ensure]
                v = symbolize(v)
                args.delete(:ensure)
            end

            if path =~ %r{^#{File::SEPARATOR}}
                self.devfail(
                    "Must pass relative paths to PFile#newchild()"
                )
            else
                path = File.join(self[:path], path)
            end

            args[:path] = path

            unless hash.include?(:recurse)
                if args.include?(:recurse)
                    if args[:recurse].is_a?(Integer)
                        args[:recurse] -= 1 # reduce the level of recursion
                    end
                end

            end

            hash.each { |key,value|
                args[key] = value
            }

            child = nil

            # The child might already exist because 'localrecurse' runs
            # before 'sourcerecurse'.  I could push the override stuff into
            # a separate method or something, but the work is the same other
            # than this last bit, so it doesn't really make sense.
            if child = catalog.resource(:file, path)
                unless child.parent.object_id == self.object_id
                    self.debug "Not managing more explicit file %s" %
                        path
                    return nil
                end

                # This is only necessary for sourcerecurse, because we might have
                # created the object with different 'should' values than are
                # set remotely.
                unless local
                    args.each { |var,value|
                        next if var == :path
                        next if var == :name

                        # behave idempotently
                        unless child.should(var) == value
                            child[var] = value
                        end
                    }
                end
                return nil
            else # create it anew
                #notice "Creating new file with args %s" % args.inspect
                args[:parent] = self
                begin
                    # This method is used by subclasses of :file, so use the class name rather than hard-coding
                    # :file.
                    return nil unless child = catalog.create_implicit_resource(self.class.name, args)
                rescue => detail
                    self.notice "Cannot manage: %s" % [detail]
                    return nil
                end
            end

            # LAK:FIXME This shouldn't be necessary, but as long as we're
            # modeling the relationship graph specifically, it is.
            catalog.relationship_graph.add_edge self, child

            return child
        end

        # Files handle paths specially, because they just lengthen their
        # path names, rather than including the full parent's title each
        # time.
        def pathbuilder
            # We specifically need to call the method here, so it looks
            # up our parent in the catalog graph.
            if parent = parent()
                # We only need to behave specially when our parent is also
                # a file
                if parent.is_a?(self.class)
                    # Remove the parent file name
                    list = parent.pathbuilder
                    list.pop # remove the parent's path info
                    return list << self.ref
                else
                    return super
                end
            else
                return [self.ref]
            end
        end
        
        # Should we be purging?
        def purge?
            @parameters.include?(:purge) and (self[:purge] == :true or self[:purge] == "true")
        end

        # Recurse into the directory.  This basically just calls 'localrecurse'
        # and maybe 'sourcerecurse', returning the collection of generated
        # files.
        def recurse
            # are we at the end of the recursion?
            return unless self.recurse?

            recurse = self[:recurse]
            # we might have a string, rather than a number
            if recurse.is_a?(String)
                if recurse =~ /^[0-9]+$/
                    recurse = Integer(recurse)
                else # anything else is infinite recursion
                    recurse = true
                end
            end

            if recurse.is_a?(Integer)
                recurse -= 1
            end
            
            children = []
            
            # We want to do link-recursing before normal recursion so that all
            # of the target stuff gets copied over correctly.
            if @parameters.include? :target and ret = self.linkrecurse(recurse)
                children += ret
            end
            if ret = self.localrecurse(recurse)
                children += ret
            end

            # These will be files pulled in by the file source
            sourced = false
            if @parameters.include?(:source)
                ret, sourced = self.sourcerecurse(recurse)
                if ret
                    children += ret
                end
            end

            # The purge check needs to happen after all of the other recursion.
            if self.purge?
                children.each do |child|
                    if (sourced and ! sourced.include?(child[:path])) or ! child.managed?
                        child[:ensure] = :absent
                    end
                end
            end
            
            children
        end

        # A simple method for determining whether we should be recursing.
        def recurse?
            return false unless @parameters.include?(:recurse)

            val = @parameters[:recurse].value

            if val and (val == true or val > 0)
                return true
            else
                return false
            end
        end

        # Remove the old backup.
        def remove_backup(newfile)
            if self.class.name == :file and self[:links] != :follow
                method = :lstat
            else
                method = :stat
            end
            old = File.send(method, newfile).ftype

            if old == "directory"
                raise Puppet::Error,
                    "Will not remove directory backup %s; use a filebucket" %
                    newfile
            end

            info "Removing old backup of type %s" %
                File.send(method, newfile).ftype

            begin
                File.unlink(newfile)
            rescue => detail
                puts detail.backtrace if Puppet[:trace]
                self.err "Could not remove old backup: %s" % detail
                return false
            end
        end

        # Remove any existing data.  This is only used when dealing with
        # links or directories.
        def remove_existing(should)
            return unless s = stat(true)

            self.fail "Could not back up; will not replace" unless handlebackup

            unless should.to_s == "link"
                return if s.ftype.to_s == should.to_s 
            end

            case s.ftype
            when "directory":
                if self[:force] == :true
                    debug "Removing existing directory for replacement with %s" % should
                    FileUtils.rmtree(self[:path])
                else
                    notice "Not removing directory; use 'force' to override"
                end
            when "link", "file":
                debug "Removing existing %s for replacement with %s" %
                    [s.ftype, should]
                File.unlink(self[:path])
            else
                self.fail "Could not back up files of type %s" % s.ftype
            end
        end

        # a wrapper method to make sure the file exists before doing anything
        def retrieve
            unless stat = self.stat(true)
                # If the file doesn't exist but we have a source, then call
                # retrieve on that property

                propertyvalues = properties().inject({}) { |hash, property|
                                     hash[property] = :absent
                                     hash
                                  }

                if @parameters.include?(:source)
                    propertyvalues[:source] = @parameters[:source].retrieve
                end
                return propertyvalues
            end

            return currentpropvalues()
        end

        # This recurses against the remote source and makes sure the local
        # and remote structures match.  It's run after 'localrecurse'.  This
        # method only does anything when its corresponding remote entry is
        # a directory; in that case, this method creates file objects that
        # correspond to any contained remote files.
        def sourcerecurse(recurse)
            # we'll set this manually as necessary
            if @arghash.include?(:ensure)
                @arghash.delete(:ensure)
            end
            
            r = false
            if recurse
                unless recurse == 0
                    r = 1
                end
            end
            
            ignore = self[:ignore]

            result = []
            found = []

            # Keep track of all the files we found in the source, so we can purge
            # appropriately.
            sourced = []
            
            @parameters[:source].should.each do |source|
                sourceobj, path = uri2obj(source)

                # okay, we've got our source object; now we need to
                # build up a local file structure to match the remote
                # one

                server = sourceobj.server

                desc = server.list(path, self[:links], r, ignore)
                if desc == "" 
                    next
                end
            
                # Now create a new child for every file returned in the list.
                result += desc.split("\n").collect { |line|
                    file, type = line.split("\t")
                    next if file == "/" # skip the listing object
                    name = file.sub(/^\//, '')

                    # This makes sure that the first source *always* wins
                    # for conflicting files.
                    next if found.include?(name)

                    # For directories, keep all of the sources, so that
                    # sourceselect still works as planned.
                    if type == "directory"
                        newsource = @parameters[:source].should.collect do |tmpsource|
                            tmpsource + file
                        end
                    else
                        newsource = source + file
                    end
                    args = {:source => newsource}
                    if type == file
                        args[:recurse] = nil
                    end

                    found << name
                    sourced << File.join(self[:path], name)

                    self.newchild(name, false, args)
                }.reject {|c| c.nil? }

                if self[:sourceselect] == :first
                    return [result, sourced]
                end
            end
            return [result, sourced]
        end

        # Set the checksum, from another property.  There are multiple
        # properties that modify the contents of a file, and they need the
        # ability to make sure that the checksum value is in sync.
        def setchecksum(sum = nil)
            if @parameters.include? :checksum
                if sum
                    @parameters[:checksum].checksum = sum
                else
                    # If they didn't pass in a sum, then tell checksum to
                    # figure it out.
                    currentvalue = @parameters[:checksum].retrieve
                    @parameters[:checksum].checksum = currentvalue
                end
            end
        end

        # Stat our file.  Depending on the value of the 'links' attribute, we
        # use either 'stat' or 'lstat', and we expect the properties to use the
        # resulting stat object accordingly (mostly by testing the 'ftype'
        # value).
        def stat(refresh = false)
            method = :stat

            # Files are the only types that support links
            if (self.class.name == :file and self[:links] != :follow) or self.class.name == :tidy
                method = :lstat
            end
            path = self[:path]
            # Just skip them when they don't exist at all.
            unless FileTest.exists?(path) or FileTest.symlink?(path)
                @stat = nil
                return @stat
            end
            if @stat.nil? or refresh == true
                begin
                    @stat = File.send(method, self[:path])
                rescue Errno::ENOENT => error
                    @stat = nil
                rescue Errno::EACCES => error
                    self.warning "Could not stat; permission denied"
                    @stat = nil
                end
            end

            return @stat
        end

        # We have to hack this just a little bit, because otherwise we'll get
        # an error when the target and the contents are created as properties on
        # the far side.
        def to_trans(retrieve = true)
            obj = super
            if obj[:target] == :notlink
                obj.delete(:target)
            end
            obj
        end

        def localfileserver
            unless defined? @@localfileserver
                args = {
                    :Local => true,
                    :Mount => { "/" => "localhost" },
                    :Config => false
                }
                @@localfileserver = Puppet::Network::Handler.handler(:fileserver).new(args)
            end
            @@localfileserver
        end

        def uri2obj(source)
            sourceobj = Puppet::Type::File::FileSource.new
            path = nil
            unless source
                devfail "Got a nil source"
            end
            if source =~ /^\//
                source = "file://localhost/%s" % URI.escape(source)
                sourceobj.mount = "localhost"
                sourceobj.local = true
            end
            begin
                uri = URI.parse(URI.escape(source))
            rescue => detail
                self.fail "Could not understand source %s: %s" %
                    [source, detail.to_s]
            end

            case uri.scheme
            when "file":
                sourceobj.server = localfileserver
                path = "/localhost" + uri.path
            when "puppet":
                # FIXME: We should cache clients by uri.host + uri.port
                # not by the full source path
                unless @clients.include?(source)
                    host = uri.host
                    host ||= Puppet[:server] unless Puppet[:name] == "puppet"
                    if host.nil?
                        server = localfileserver
                    else
                        args = { :Server => host }
                        if uri.port
                            args[:Port] = uri.port
                        end
                        server = Puppet::Network::Client.file.new(args)
                    end
                    @clients[source] = server
                end
                sourceobj.server = @clients[source]

                tmp = uri.path
                if tmp =~ %r{^/(\w+)}
                    sourceobj.mount = $1
                    path = tmp
                    #path = tmp.sub(%r{^/\w+},'') || "/"
                else
                    self.fail "Invalid source path %s" % tmp
                end
            else
                self.fail "Got other URL type '%s' from %s" %
                        [uri.scheme, source]
            end

            return [sourceobj, path.sub(/\/\//, '/')]
        end

        # Write out the file.  Requires the content to be written,
        # the property name for logging, and the checksum for validation.
        def write(content, property, checksum = nil)
            if validate = validate_checksum?
                # Use the appropriate checksum type -- md5, md5lite, etc.
                sumtype = property(:checksum).checktype
                checksum ||= "{#{sumtype}}" + property(:checksum).send(sumtype, content)
            end

            remove_existing(:file)

            use_temporary_file = (content.length != 0)
            path = self[:path]
            path += ".puppettmp" if use_temporary_file

            mode = self.should(:mode) # might be nil
            umask = mode ? 000 : 022

            Puppet::Util.withumask(umask) do
                File.open(path, File::CREAT|File::WRONLY|File::TRUNC, mode) { |f| f.print content }
            end

            # And put our new file in place
            if use_temporary_file # This is only not true when our file is empty.
                begin
                    fail_if_checksum_is_wrong(path, checksum) if validate
                    File.rename(path, self[:path])
                rescue => detail
                    self.err "Could not rename tmp %s for replacing: %s" % [self[:path], detail]
                ensure
                    # Make sure the created file gets removed
                    File.unlink(path) if FileTest.exists?(path)
                end
            end

            # make sure all of the modes are actually correct
            property_fix

            # And then update our checksum, so the next run doesn't find it.
            self.setchecksum(checksum)
        end

        # Should we validate the checksum of the file we're writing?
        def validate_checksum?
            if sumparam = @parameters[:checksum]
                return sumparam.checktype.to_s !~ /time/
            else
                return false
            end
        end

        private

        # Make sure the file we wrote out is what we think it is.
        def fail_if_checksum_is_wrong(path, checksum)
            if checksum =~ /^\{(\w+)\}.+/
                sumtype = $1
            else
                # This shouldn't happen, but if it happens to, it's nicer
                # to just use a default sumtype than fail.
                sumtype = "md5"
            end
            newsum = property(:checksum).getsum(sumtype, path)
            return if newsum == checksum

            self.fail "File written to disk did not match checksum; discarding changes (%s vs %s)" % [checksum, newsum]
        end

        # Override the parent method, because we don't want to generate changes
        # when the file is missing and there is no 'ensure' state.
        def propertychanges(currentvalues)
            unless self.stat
                found = false
                ([:ensure] + CREATORS).each do |prop|
                    if @parameters.include?(prop)
                        found = true
                        break
                    end
                end
                unless found
                    return []
                end
            end
            super
        end

        # There are some cases where all of the work does not get done on
        # file creation/modification, so we have to do some extra checking.
        def property_fix
            properties.each do |thing|
                next unless [:mode, :owner, :group].include?(thing.name)

                # Make sure we get a new stat objct
                self.stat(true)
                currentvalue = thing.retrieve
                unless thing.insync?(currentvalue)
                    thing.sync
                end
            end
        end
    end # Puppet.type(:pfile)

    # the filesource class can't include the path, because the path
    # changes for every file instance
    class ::Puppet::Type::File::FileSource
        attr_accessor :mount, :root, :server, :local
    end

    # We put all of the properties in separate files, because there are so many
    # of them.  The order these are loaded is important, because it determines
    # the order they are in the property lit.
    require 'puppet/type/file/checksum'
    require 'puppet/type/file/content'     # can create the file
    require 'puppet/type/file/source'      # can create the file
    require 'puppet/type/file/target'      # creates a different type of file
    require 'puppet/type/file/ensure'      # can create the file
    require 'puppet/type/file/owner'
    require 'puppet/type/file/group'
    require 'puppet/type/file/mode'
    require 'puppet/type/file/type'
end
