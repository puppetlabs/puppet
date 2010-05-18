require 'digest/md5'
require 'cgi'
require 'etc'
require 'uri'
require 'fileutils'
require 'puppet/network/handler'
require 'puppet/util/diff'
require 'puppet/util/checksums'
require 'puppet/network/client'
require 'puppet/util/backups'

module Puppet
    newtype(:file) do
        include Puppet::Util::MethodHelper
        include Puppet::Util::Checksums
        include Puppet::Util::Backups
        @doc = "Manages local files, including setting ownership and
            permissions, creation of both files and directories, and
            retrieving entire files from remote servers.  As Puppet matures, it
            expected that the ``file`` resource will be used less and less to
            manage content, and instead native resources will be used to do so.

            If you find that you are often copying files in from a central
            location, rather than using native resources, please contact
            Puppet Labs and we can hopefully work with you to develop a
            native resource to support what you are doing."

        newparam(:path) do
            desc "The path to the file to manage.  Must be fully qualified."
            isnamevar

            validate do |value|
                unless value =~ /^#{File::SEPARATOR}/
                    fail Puppet::Error,"File paths must be fully qualified, not '#{value}'"
                end
            end

            # convert the current path in an index into the collection and the last
            # path name. The aim is to use less storage for all common paths in a hierarchy
            munge do |value|
                path, name = File.split(value)
                { :index => Puppet::FileCollection.collection.index(path), :name => name }
            end

            # and the reverse
            unmunge do |value|
                File.join( Puppet::FileCollection.collection.path(value[:index]), value[:name] )
            end
 
            to_canonicalize do |s|
                # Get rid of any duplicate slashes, and remove any trailing slashes unless 
                # the title is just a slash, in which case leave it.
                s.gsub(/\/+/, "/").sub(/(.)\/$/,'\1')
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

            defaultto "puppet"

            munge do |value|
                # I don't really know how this is happening.
                value = value.shift if value.is_a?(Array)

                case value
                when false, "false", :false
                    false
                when true, "true", ".puppet-bak", :true
                    ".puppet-bak"
                when String
                    value
                else
                    self.fail "Invalid backup type %s" % value.inspect
                end
            end
        end

        newparam(:recurse) do
            desc "Whether and how deeply to do recursive
                management."

            newvalues(:true, :false, :inf, :remote, /^[0-9]+$/)

            # Replace the validation so that we allow numbers in
            # addition to string representations of them.
            validate { |arg| }
            munge do |value|
                newval = super(value)
                case newval
                when :true, :inf; true
                when :false; false
                when :remote; :remote
                when Integer, Fixnum, Bignum
                    self.warning "Setting recursion depth with the recurse parameter is now deprecated, please use recurselimit"

                    # recurse == 0 means no recursion
                    return false if value == 0

                    resource[:recurselimit] = value
                    true
                when /^\d+$/
                    self.warning "Setting recursion depth with the recurse parameter is now deprecated, please use recurselimit"
                    value = Integer(value)

                    # recurse == 0 means no recursion
                    return false if value == 0

                    resource[:recurselimit] = value
                    true
                else
                    self.fail "Invalid recurse value #{value.inspect}"
                end
            end
        end

        newparam(:recurselimit) do
            desc "How deeply to do recursive management."

            newvalues(/^[0-9]+$/)

            munge do |value|
                newval = super(value)
                case newval
                when Integer, Fixnum, Bignum; value
                when /^\d+$/; Integer(value)
                else
                    self.fail "Invalid recurselimit value #{value.inspect}"
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

        # Autorequire any parent directories.
        autorequire(:file) do
            basedir = File.dirname(self[:path])
            if basedir != self[:path]
                basedir
            else
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
            if @parameters.include?(:source)
                count += 1
            end
            if count > 1
                self.fail "You cannot specify more than one of %s" % CREATORS.collect { |p| p.to_s}.join(", ")
            end

            if !self[:source] and self[:recurse] == :remote
                self.fail "You cannot specify a remote recursion without a source"
            end

            if !self[:recurse] and self[:recurselimit]
                self.warning "Possible error: recurselimit is set but not recurse, no recursion will happen"
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
                    files << self.new(
                        :name => path, :check => :all
                    )
                end
            end
            files
        end

        @depthfirst = false

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

        def bucket
            return @bucket if defined?(@bucket) and @bucket

            backup = self[:backup]
            return nil unless backup
            return nil if backup =~ /^\./

            unless catalog or backup == "puppet"
                fail "Can not find filebucket for backups without a catalog"
            end

            unless catalog and filebucket = catalog.resource(:filebucket, backup) or backup == "puppet"
                fail "Could not find filebucket %s specified in backup" % backup
            end

            return default_bucket unless filebucket

            @bucket = filebucket.bucket

            return @bucket
        end

        def default_bucket
            Puppet::Type.type(:filebucket).mkdefaultbucket.bucket
        end

        # Does the file currently exist?  Just checks for whether
        # we have a stat
        def exist?
            stat ? true : false
        end

        # We have to do some extra finishing, to retrieve our bucket if
        # there is one.
        def finish
            # Look up our bucket, if there is one
            bucket()
            super
        end

        # Create any children via recursion or whatever.
        def eval_generate
            return [] unless self.recurse?

            recurse
            #recurse.reject do |resource|
            #    catalog.resource(:file, resource[:path])
            #end.each do |child|
            #    catalog.add_resource child
            #    catalog.relationship_graph.add_edge self, child
            #end
        end

        def flush
            # We want to make sure we retrieve metadata anew on each transaction.
            @parameters.each do |name, param|
                param.flush if param.respond_to?(:flush)
            end
            @stat = nil
        end

        def initialize(hash)
            # Used for caching clients
            @clients = {}

            super

            @title = self.class.canonicalize_ref(@title)
            @stat = nil
        end

        # Configure discovered resources to be purged.
        def mark_children_for_purging(children)
            children.each do |name, child|
                next if child[:source]
                child[:ensure] = :absent
            end
        end

        # Create a new file or directory object as a child to the current
        # object.
        def newchild(path)
            full_path = File.join(self[:path], path)

            # Add some new values to our original arguments -- these are the ones
            # set at initialization.  We specifically want to exclude any param
            # values set by the :source property or any default values.
            # LAK:NOTE This is kind of silly, because the whole point here is that
            # the values set at initialization should live as long as the resource
            # but values set by default or by :source should only live for the transaction
            # or so.  Unfortunately, we don't have a straightforward way to manage
            # the different lifetimes of this data, so we kludge it like this.
            # The right-side hash wins in the merge.
            options = @original_parameters.merge(:path => full_path).reject { |param, value| value.nil? }

            # These should never be passed to our children.
            [:parent, :ensure, :recurse, :recurselimit, :target, :alias, :source].each do |param|
                options.delete(param) if options.include?(param)
            end

            return self.class.new(options)
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

        # Recursively generate a list of file resources, which will
        # be used to copy remote files, manage local files, and/or make links
        # to map to another directory.
        def recurse
            children = {}
            if self[:recurse] != :remote
                children = recurse_local
            end

            if self[:target]
                recurse_link(children)
            elsif self[:source]
                recurse_remote(children)
            end

            # If we're purging resources, then delete any resource that isn't on the
            # remote system.
            mark_children_for_purging(children) if self.purge?

            result = children.values.sort { |a, b| a[:path] <=> b[:path] }
            remove_less_specific_files(result)
        end

        # This is to fix bug #2296, where two files recurse over the same
        # set of files.  It's a rare case, and when it does happen you're
        # not likely to have many actual conflicts, which is good, because
        # this is a pretty inefficient implementation.
        def remove_less_specific_files(files)
            mypath = self[:path].split(File::Separator)
            other_paths = catalog.vertices.
              select  { |r| r.is_a?(self.class) and r[:path] != self[:path] }.
              collect { |r| r[:path].split(File::Separator) }.
              select  { |p| p[0,mypath.length]  == mypath }

            return files if other_paths.empty?

            files.reject { |file|
                path = file[:path].split(File::Separator)
                other_paths.any? { |p| path[0,p.length] == p }
                }
        end

        # A simple method for determining whether we should be recursing.
        def recurse?
            return false unless @parameters.include?(:recurse)

            val = @parameters[:recurse].value

            if val and (val == true or val == :remote)
                return true
            else
                return false
            end
        end

        # Recurse the target of the link.
        def recurse_link(children)
            perform_recursion(self[:target]).each do |meta|
                if meta.relative_path == "."
                    self[:ensure] = :directory
                    next
                end

                children[meta.relative_path] ||= newchild(meta.relative_path)
                if meta.ftype == "directory"
                    children[meta.relative_path][:ensure] = :directory
                else
                    children[meta.relative_path][:ensure] = :link
                    children[meta.relative_path][:target] = meta.full_path
                end
            end
            children
        end

        # Recurse the file itself, returning a Metadata instance for every found file.
        def recurse_local
            result = perform_recursion(self[:path])
            return {} unless result
            result.inject({}) do |hash, meta|
                next hash if meta.relative_path == "."

                hash[meta.relative_path] = newchild(meta.relative_path)
                hash
            end
        end

        # Recurse against our remote file.
        def recurse_remote(children)
            sourceselect = self[:sourceselect]

            total = self[:source].collect do |source|
                next unless result = perform_recursion(source)
                return if top = result.find { |r| r.relative_path == "." } and top.ftype != "directory"
                result.each { |data| data.source = "%s/%s" % [source, data.relative_path] }
                break result if result and ! result.empty? and sourceselect == :first
                result
            end.flatten

            # This only happens if we have sourceselect == :all
            unless sourceselect == :first
                found = []
                total.reject! do |data|
                    result = found.include?(data.relative_path)
                    found << data.relative_path unless found.include?(data.relative_path)
                    result
                end
            end

            total.each do |meta|
                if meta.relative_path == "."
                    parameter(:source).metadata = meta
                    next
                end
                children[meta.relative_path] ||= newchild(meta.relative_path)
                children[meta.relative_path][:source] = meta.source
                children[meta.relative_path][:checksum] = :md5 if meta.ftype == "file"

                children[meta.relative_path].parameter(:source).metadata = meta
            end

            children
        end

        def perform_recursion(path)
            params = {
                :links => self[:links],
                :recurse => (self[:recurse] == :remote ? true : self[:recurse]),
                :recurselimit => self[:recurselimit],
                :ignore => self[:ignore]
            }
            params[:checksum_type] = self[:checksum] if self[:checksum] == :none
            Puppet::FileServing::Metadata.search(path, params)
        end

        # Remove any existing data.  This is only used when dealing with
        # links or directories.
        def remove_existing(should)
            return unless s = stat

            self.fail "Could not back up; will not replace" unless perform_backup

            unless should.to_s == "link"
                return if s.ftype.to_s == should.to_s
            end

            case s.ftype
            when "directory"
                if self[:force] == :true
                    debug "Removing existing directory for replacement with %s" % should
                    FileUtils.rmtree(self[:path])
                else
                    notice "Not removing directory; use 'force' to override"
                end
            when "link", "file"
                debug "Removing existing %s for replacement with %s" %
                    [s.ftype, should]
                File.unlink(self[:path])
            else
                self.fail "Could not back up files of type %s" % s.ftype
            end
            expire
        end

        # a wrapper method to make sure the file exists before doing anything
        def retrieve
            if source = parameter(:source)
                source.copy_source_values
            end
            super
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

        # Should this thing be a normal file?  This is a relatively complex
        # way of determining whether we're trying to create a normal file,
        # and it's here so that the logic isn't visible in the content property.
        def should_be_file?
            return true if self[:ensure] == :file

            # I.e., it's set to something like "directory"
            return false if e = self[:ensure] and e != :present

            # The user doesn't really care, apparently
            if self[:ensure] == :present
                return true unless s = stat
                return true if s.ftype == "file"
                return false
            end

            # If we've gotten here, then :ensure isn't set
            return true if self[:content]
            return true if stat and stat.ftype == "file"
            return false
        end

        # Stat our file.  Depending on the value of the 'links' attribute, we
        # use either 'stat' or 'lstat', and we expect the properties to use the
        # resulting stat object accordingly (mostly by testing the 'ftype'
        # value).
        cached_attr(:stat) do
            method = :stat

            # Files are the only types that support links
            if (self.class.name == :file and self[:links] != :follow) or self.class.name == :tidy
                method = :lstat
            end
            path = self[:path]

            begin
                File.send(method, self[:path])
            rescue Errno::ENOENT => error
                return nil
            rescue Errno::EACCES => error
                warning "Could not stat; permission denied"
                return nil
            end
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
            if use_temporary_file
                path = "#{self[:path]}.puppettmp_#{rand(10000)}"
                while File.exists?(path) or File.symlink?(path)
                    path = "#{self[:path]}.puppettmp_#{rand(10000)}"
                    end
              else
                path = self[:path]
              end

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
                    fail "Could not rename temporary file %s to %s : %s" % [path, self[:path], detail]
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
                next unless [:mode, :owner, :group, :seluser, :selrole, :seltype, :selrange].include?(thing.name)

                # Make sure we get a new stat objct
                expire
                currentvalue = thing.retrieve
                unless thing.insync?(currentvalue)
                    thing.sync
                end
            end
        end
    end # Puppet::Type.type(:pfile)

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
    require 'puppet/type/file/selcontext'  # SELinux file context
end
