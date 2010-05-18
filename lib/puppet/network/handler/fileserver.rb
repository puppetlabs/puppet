require 'puppet'
require 'puppet/network/authstore'
require 'webrick/httpstatus'
require 'cgi'
require 'delegate'
require 'sync'

require 'puppet/file_serving'
require 'puppet/file_serving/metadata'

class Puppet::Network::Handler
    AuthStoreError = Puppet::AuthStoreError
    class FileServerError < Puppet::Error; end
    class FileServer < Handler
        desc "The interface to Puppet's fileserving abilities."

        attr_accessor :local

        CHECKPARAMS = [:mode, :type, :owner, :group, :checksum]

        # Special filserver module for puppet's module system
        MODULES = "modules"
        PLUGINS = "plugins"

        @interface = XMLRPC::Service::Interface.new("fileserver") { |iface|
            iface.add_method("string describe(string, string)")
            iface.add_method("string list(string, string, boolean, array)")
            iface.add_method("string retrieve(string, string)")
        }

        def self.params
            CHECKPARAMS.dup
        end

        # If the configuration file exists, then create (if necessary) a LoadedFile
        # object to manage it; else, return nil.
        def configuration
            # Short-circuit the default case.
            return @configuration if defined?(@configuration)

            config_path = @passed_configuration_path || Puppet[:fileserverconfig]
            return nil unless FileTest.exist?(config_path)

            # The file exists but we don't have a LoadedFile instance for it.
            @configuration = Puppet::Util::LoadedFile.new(config_path)
        end

        # Create our default mounts for modules and plugins.  This is duplicated code,
        # but I'm not really worried about that.
        def create_default_mounts
            @mounts = {}
            Puppet.debug "No file server configuration file; autocreating #{MODULES} mount with default permissions"
            mount = Mount.new(MODULES)
            mount.allow("*")
            @mounts[MODULES] = mount

            Puppet.debug "No file server configuration file; autocreating #{PLUGINS} mount with default permissions"
            mount = PluginMount.new(PLUGINS)
            mount.allow("*")
            @mounts[PLUGINS] = mount
        end

        # Describe a given file.  This returns all of the manageable aspects
        # of that file.
        def describe(url, links = :follow, client = nil, clientip = nil)
            links = links.intern if links.is_a? String

            mount, path = convert(url, client, clientip)

            mount.debug("Describing %s for %s" % [url, client]) if client

            # use the mount to resolve the path for us.
            return "" unless full_path = mount.file_path(path, client)

            metadata = Puppet::FileServing::Metadata.new(url, :path => full_path, :links => links)

            return "" unless metadata.exist?

            begin
                metadata.collect
            rescue => detail
                puts detail.backtrace if Puppet[:trace]
                Puppet.err detail
                return ""
            end

            return metadata.attributes_with_tabs
        end

        # Create a new fileserving module.
        def initialize(hash = {})
            @mounts = {}
            @files = {}

            if hash[:Local]
                @local = hash[:Local]
            else
                @local = false
            end

            if hash[:Config] == false
                @noreadconfig = true
            end

            @passed_configuration_path = hash[:Config]

            if hash.include?(:Mount)
                @passedconfig = true
                unless hash[:Mount].is_a?(Hash)
                    raise Puppet::DevError, "Invalid mount hash %s" %
                        hash[:Mount].inspect
                end

                hash[:Mount].each { |dir, name|
                    if FileTest.exists?(dir)
                        self.mount(dir, name)
                    end
                }
                self.mount(nil, MODULES)
                self.mount(nil, PLUGINS)
            else
                @passedconfig = false
                if configuration
                    readconfig(false) # don't check the file the first time.
                else
                    create_default_mounts()
                end
            end
        end

        # List a specific directory's contents.
        def list(url, links = :ignore, recurse = false, ignore = false, client = nil, clientip = nil)
            mount, path = convert(url, client, clientip)

            mount.debug "Listing %s for %s" % [url, client] if client

            return "" unless mount.path_exists?(path, client)

            desc = mount.list(path, recurse, ignore, client)

            if desc.length == 0
                mount.notice "Got no information on //%s/%s" % [mount, path]
                return ""
            end

            desc.collect { |sub| sub.join("\t") }.join("\n")
        end

        def local?
            self.local
        end

        # Is a given mount available?
        def mounted?(name)
            @mounts.include?(name)
        end

        # Mount a new directory with a name.
        def mount(path, name)
            if @mounts.include?(name)
                if @mounts[name] != path
                    raise FileServerError, "%s is already mounted at %s" %
                        [@mounts[name].path, name]
                else
                    # it's already mounted; no problem
                    return
                end
            end

            # Let the mounts do their own error-checking.
            @mounts[name] = Mount.new(name, path)
            @mounts[name].info "Mounted %s" % path

            return @mounts[name]
        end

        # Retrieve a file from the local disk and pass it to the remote
        # client.
        def retrieve(url, links = :ignore, client = nil, clientip = nil)
            links = links.intern if links.is_a? String

            mount, path = convert(url, client, clientip)

            if client
                mount.info "Sending %s to %s" % [url, client]
            end

            unless mount.path_exists?(path, client)
                mount.debug "#{mount} reported that #{path} does not exist"
                return ""
            end

            links = links.intern if links.is_a? String

            if links == :ignore and FileTest.symlink?(path)
                mount.debug "I think that #{path} is a symlink and we're ignoring them"
                return ""
            end

            str = mount.read_file(path, client)

            if @local
                return str
            else
                return CGI.escape(str)
            end
        end

        def umount(name)
            @mounts.delete(name) if @mounts.include? name
        end

        private

        def authcheck(file, mount, client, clientip)
            # If we're local, don't bother passing in information.
            if local?
                client = nil
                clientip = nil
            end
            unless mount.allowed?(client, clientip)
                mount.warning "%s cannot access %s" %
                    [client, file]
                raise Puppet::AuthorizationError, "Cannot access %s" % mount
            end
        end

        # Take a URL and some client info and return a mount and relative
        # path pair.
        #
        def convert(url, client, clientip)
            readconfig

            url = URI.unescape(url)

            mount, stub = splitpath(url, client)

            authcheck(url, mount, client, clientip)

            return mount, stub
        end

        # Return the mount for the Puppet modules; allows file copying from
        # the modules.
        def modules_mount(module_name, client)
            # Find our environment, if we have one.
            unless hostname = (client || Facter.value("hostname"))
                raise ArgumentError, "Could not find hostname"
            end
            if node = Puppet::Node.find(hostname)
                env = node.environment
            else
                env = nil
            end

            # And use the environment to look up the module.
            if mod = Puppet::Node::Environment.new(env).module(module_name) and mod.files?
                return @mounts[MODULES].copy(mod.name, mod.file_directory)
            else
                return nil
            end
        end

        # Read the configuration file.
        def readconfig(check = true)
            return if @noreadconfig

            return unless configuration

            if check and ! @configuration.changed?
                return
            end

            newmounts = {}
            begin
                File.open(@configuration.file) { |f|
                    mount = nil
                    count = 1
                    f.each { |line|
                        case line
                        when /^\s*#/; next # skip comments
                        when /^\s*$/; next # skip blank lines
                        when /\[([-\w]+)\]/
                            name = $1
                            if newmounts.include?(name)
                                raise FileServerError, "%s is already mounted as %s in %s" %
                                    [newmounts[name], name, @configuration.file]
                            end
                            mount = Mount.new(name)
                            newmounts[name] = mount
                        when /^\s*(\w+)\s+(.+)$/
                            var = $1
                            value = $2
                            case var
                            when "path"
                                if mount.name == MODULES
                                    Puppet.warning "The '#{mount.name}' module can not have a path. Ignoring attempt to set it"
                                else
                                    begin
                                        mount.path = value
                                    rescue FileServerError => detail
                                        Puppet.err "Removing mount %s: %s" %
                                            [mount.name, detail]
                                        newmounts.delete(mount.name)
                                    end
                                end
                            when "allow"
                                value.split(/\s*,\s*/).each { |val|
                                    begin
                                        mount.info "allowing %s access" % val
                                        mount.allow(val)
                                    rescue AuthStoreError => detail
                                        puts detail.backtrace if Puppet[:trace]
                                        raise FileServerError.new(detail.to_s,
                                            count, @configuration.file)
                                    end
                                }
                            when "deny"
                                value.split(/\s*,\s*/).each { |val|
                                    begin
                                        mount.info "denying %s access" % val
                                        mount.deny(val)
                                    rescue AuthStoreError => detail
                                        raise FileServerError.new(detail.to_s,
                                            count, @configuration.file)
                                    end
                                }
                            else
                                raise FileServerError.new("Invalid argument '%s'" % var,
                                    count, @configuration.file)
                            end
                        else
                            raise FileServerError.new("Invalid line '%s'" % line.chomp,
                                count, @configuration.file)
                        end
                        count += 1
                    }
                }
            rescue Errno::EACCES => detail
                Puppet.err "FileServer error: Cannot read %s; cannot serve" % @configuration
                #raise Puppet::Error, "Cannot read %s" % @configuration
            rescue Errno::ENOENT => detail
                Puppet.err "FileServer error: '%s' does not exist; cannot serve" %
                    @configuration
            end

            unless newmounts[MODULES]
                Puppet.debug "No #{MODULES} mount given; autocreating with default permissions"
                mount = Mount.new(MODULES)
                mount.allow("*")
                newmounts[MODULES] = mount
            end

            unless newmounts[PLUGINS]
                Puppet.debug "No #{PLUGINS} mount given; autocreating with default permissions"
                mount = PluginMount.new(PLUGINS)
                mount.allow("*")
                newmounts[PLUGINS] = mount
            end

            unless newmounts[PLUGINS].valid?
                Puppet.debug "No path given for #{PLUGINS} mount; creating a special PluginMount"
                # We end up here if the user has specified access rules for
                # the plugins mount, without specifying a path (which means
                # they want to have the default behaviour for the mount, but
                # special access control).  So we need to move all the
                # user-specified access controls into the new PluginMount
                # object...
                mount = PluginMount.new(PLUGINS)
                # Yes, you're allowed to hate me for this.
                mount.instance_variable_set(:@declarations,
                                 newmounts[PLUGINS].instance_variable_get(:@declarations)
                                 )
                newmounts[PLUGINS] = mount
            end

            # Verify each of the mounts are valid.
            # We let the check raise an error, so that it can raise an error
            # pointing to the specific problem.
            newmounts.each { |name, mount|
                unless mount.valid?
                    raise FileServerError, "Invalid mount %s" %
                        name
                end
            }
            @mounts = newmounts
        end

        # Split the path into the separate mount point and path.
        def splitpath(dir, client)
            # the dir is based on one of the mounts
            # so first retrieve the mount path
            mount = nil
            path = nil
            if dir =~ %r{/([-\w]+)}
                # Strip off the mount name.
                mount_name, path = dir.sub(%r{^/}, '').split(File::Separator, 2)

                unless mount = modules_mount(mount_name, client)
                    unless mount = @mounts[mount_name]
                        raise FileServerError, "Fileserver module '%s' not mounted" % mount_name
                    end
                end
            else
                raise FileServerError, "Fileserver error: Invalid path '%s'" % dir
            end

            if path.nil? or path == ''
                path = '/'
            elsif path
                # Remove any double slashes that might have occurred
                path = URI.unescape(path.gsub(/\/\//, "/"))
            end

            return mount, path
        end

        def to_s
            "fileserver"
        end

        # A simple class for wrapping mount points.  Instances of this class
        # don't know about the enclosing object; they're mainly just used for
        # authorization.
        class Mount < Puppet::Network::AuthStore
            attr_reader :name

            @@syncs = {}

            @@files = {}

            Puppet::Util.logmethods(self, true)

            # Create a map for a specific client.
            def clientmap(client)
                {
                    "h" => client.sub(/\..*$/, ""),
                    "H" => client,
                    "d" => client.sub(/[^.]+\./, "") # domain name
                }
            end

            # Replace % patterns as appropriate.
            def expand(path, client = nil)
                # This map should probably be moved into a method.
                map = nil

                if client
                    map = clientmap(client)
                else
                    Puppet.notice "No client; expanding '%s' with local host" %
                        path
                    # Else, use the local information
                    map = localmap()
                end
                path.gsub(/%(.)/) do |v|
                    key = $1
                    if key == "%"
                        "%"
                    else
                        map[key] || v
                    end
                end
            end

            # Do we have any patterns in our path, yo?
            def expandable?
                if defined? @expandable
                    @expandable
                else
                    false
                end
            end

            # Return a fully qualified path, given a short path and
            # possibly a client name.
            def file_path(relative_path, node = nil)
                full_path = path(node)

                unless full_path
                    p self
                    raise ArgumentError.new("Mounts without paths are not usable") unless full_path
                end

                # If there's no relative path name, then we're serving the mount itself.
                return full_path unless relative_path and relative_path != "/"

                return File.join(full_path, relative_path)
            end

            # Create out object.  It must have a name.
            def initialize(name, path = nil)
                unless name =~ %r{^[-\w]+$}
                    raise FileServerError, "Invalid name format '%s'" % name
                end
                @name = name

                if path
                    self.path = path
                else
                    @path = nil
                end

                @files = {}

                super()
            end

            def fileobj(path, links, client)
                obj = nil
                if obj = @files[file_path(path, client)]
                    # This can only happen in local fileserving, but it's an
                    # important one.  It'd be nice if we didn't just set
                    # the check params every time, but I'm not sure it's worth
                    # the effort.
                    obj[:check] = CHECKPARAMS
                else
                    obj = Puppet::Type.type(:file).new(
                        :name => file_path(path, client),
                        :check => CHECKPARAMS
                    )
                    @files[file_path(path, client)] = obj
                end

                if links == :manage
                    links = :follow
                end

                # This, ah, might be completely redundant
                unless obj[:links] == links
                    obj[:links] = links
                end

                return obj
            end

            # Read the contents of the file at the relative path given.
            def read_file(relpath, client)
                File.read(file_path(relpath, client))
            end

            # Cache this manufactured map, since if it's used it's likely
            # to get used a lot.
            def localmap
                unless defined? @@localmap
                    @@localmap = {
                        "h" =>  Facter.value("hostname"),
                        "H" => [Facter.value("hostname"),
                                Facter.value("domain")].join("."),
                        "d" =>  Facter.value("domain")
                    }
                end
                @@localmap
            end

            # Return the path as appropriate, expanding as necessary.
            def path(client = nil)
                if expandable?
                    return expand(@path, client)
                else
                    return @path
                end
            end

            # Set the path.
            def path=(path)
                # FIXME: For now, just don't validate paths with replacement
                # patterns in them.
                if path =~ /%./
                    # Mark that we're expandable.
                    @expandable = true
                else
                    unless FileTest.exists?(path)
                        raise FileServerError, "%s does not exist" % path
                    end
                    unless FileTest.directory?(path)
                        raise FileServerError, "%s is not a directory" % path
                    end
                    unless FileTest.readable?(path)
                        raise FileServerError, "%s is not readable" % path
                    end
                    @expandable = false
                end
                @path = path
            end

            # Verify that the path given exists within this mount's subtree.
            #
            def path_exists?(relpath, client = nil)
                File.exists?(file_path(relpath, client))
            end

            # Return the current values for the object.
            def properties(obj)
                obj.retrieve.inject({}) { |props, ary| props[ary[0].name] = ary[1]; props }
            end

            # Retrieve a specific directory relative to a mount point.
            # If they pass in a client, then expand as necessary.
            def subdir(dir = nil, client = nil)
                basedir = self.path(client)

                dirname = if dir
                    File.join(basedir, *dir.split("/"))
                else
                    basedir
                end

                dirname
            end

            def sync(path)
                @@syncs[path] ||= Sync.new
                @@syncs[path]
            end

            def to_s
                "mount[%s]" % @name
            end

            # Verify our configuration is valid.  This should really check to
            # make sure at least someone will be allowed, but, eh.
            def valid?
                if name == MODULES
                    return @path.nil?
                else
                    return ! @path.nil?
                end
            end

            # Return a new mount with the same properties as +self+, except
            # with a different name and path.
            def copy(name, path)
                result = self.clone
                result.path = path
                result.instance_variable_set(:@name, name)
                return result
            end

            # List the contents of the relative path +relpath+ of this mount.
            #
            # +recurse+ is the number of levels to recurse into the tree,
            # or false to provide no recursion or true if you just want to
            # go for broke.
            #
            # +ignore+ is an array of filenames to ignore when traversing
            # the list.
            #
            # The return value of this method is a complex nest of arrays,
            # which describes a directory tree.  Each file or directory is
            # represented by an array, where the first element is the path
            # of the file (relative to the root of the mount), and the
            # second element is the type.  A directory is represented by an
            # array as well, where the first element is a "directory" array,
            # while the remaining elements are other file or directory
            # arrays.  Confusing?  Hell yes.  As an added bonus, all names
            # must start with a slash, because... well, I'm fairly certain
            # a complete explanation would involve the words "crack pipe"
            # and "bad batch".
            #
            def list(relpath, recurse, ignore, client = nil)
                abspath = file_path(relpath, client)
                if FileTest.exists?(abspath)
                    if FileTest.directory?(abspath) and recurse
                        return reclist(abspath, recurse, ignore)
                    else
                        return [["/", File.stat(abspath).ftype]]
                    end
                end
                return nil
            end

            def reclist(abspath, recurse, ignore)
                require 'puppet/file_serving'
                require 'puppet/file_serving/fileset'
                if recurse.is_a?(Fixnum)
                    args = { :recurse => true, :recurselimit => recurse, :links => :follow }
                else
                    args = { :recurse => recurse, :links => :follow }
                end
                args[:ignore] = ignore if ignore
                fs = Puppet::FileServing::Fileset.new(abspath, args)
                ary = fs.files.collect do |file|
                    if file == "."
                        file = "/"
                    else
                        file = File.join("/", file )
                    end
                    stat = fs.stat(File.join(abspath, file))
                    next if stat.nil?
                    [ file, stat.ftype ]
                end

                return ary.compact
            end

        end

        # A special mount class specifically for the plugins mount -- just
        # has some magic to effectively do a union mount of the 'plugins'
        # directory of all modules.
        #
        class PluginMount < Mount
            def path(client)
                ''
            end

            def mod_path_exists?(mod, relpath, client = nil)
                ! mod.plugin(relpath).nil?
            end

            def path_exists?(relpath, client = nil)
               !valid_modules(client).find { |mod| mod.plugin(relpath) }.nil?
            end

            def valid?
                true
            end

            def mod_file_path(mod, relpath, client = nil)
                File.join(mod, PLUGINS, relpath)
            end

            def file_path(relpath, client = nil)
                return nil unless mod = valid_modules(client).find { |m| m.plugin(relpath) }
                mod.plugin(relpath)
            end

            # create a list of files by merging all modules
            def list(relpath, recurse, ignore, client = nil)
                result = []
                valid_modules(client).each do |mod|
                    if modpath = mod.plugin(relpath)
                        if FileTest.directory?(modpath) and recurse
                            ary = reclist(modpath, recurse, ignore)
                            ary = [] if ary.nil?
                            result += ary
                        else
                            result += [["/", File.stat(modpath).ftype]]
                        end
                    end
                end
                result
            end

            private
            def valid_modules(client)
                Puppet::Node::Environment.new.modules.find_all { |mod| mod.exist? }
            end

            def add_to_filetree(f, filetree)
               first, rest = f.split(File::SEPARATOR, 2)
            end
        end
    end
end

