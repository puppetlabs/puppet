require 'puppet'
require 'puppet/network/authstore'
require 'webrick/httpstatus'
require 'cgi'
require 'delegate'
require 'sync'

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

        # Describe a given file.  This returns all of the manageable aspects
        # of that file.
        def describe(url, links = :ignore, client = nil, clientip = nil)
            links = links.intern if links.is_a? String

            if links == :manage
                raise Puppet::Network::Handler::FileServerError, "Cannot currently copy links"
            end

            mount, path = convert(url, client, clientip)

            if client
                mount.debug "Describing %s for %s" % [url, client]
            end

            obj = nil
            unless obj = mount.getfileobject(path, links, client)
                return ""
            end

            currentvalues = mount.check(obj)
    
            desc = []
            CHECKPARAMS.each { |check|
                if value = currentvalues[check]
                    desc << value
                else
                    if check == "checksum" and currentvalues[:type] == "file"
                        mount.notice "File %s does not have data for %s" %
                            [obj.name, check]
                    end
                    desc << nil
                end
            }

            return desc.join("\t")
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
            else
                @config = Puppet::Util::LoadedFile.new(
                    hash[:Config] || Puppet[:fileserverconfig]
                )
                @noreadconfig = false
            end

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
                readconfig(false) # don't check the file the first time.
            end
        end

        # List a specific directory's contents.
        def list(url, links = :ignore, recurse = false, ignore = false, client = nil, clientip = nil)
            mount, path = convert(url, client, clientip)

            if client
                mount.debug "Listing %s for %s" % [url, client]
            end

            obj = nil
            unless mount.path_exists?(path, client)
                return ""
            end

            desc = mount.list(path, recurse, ignore, client)

            if desc.length == 0
                mount.notice "Got no information on //%s/%s" %
                    [mount, path]
                return ""
            end
            
            desc.collect { |sub|
                sub.join("\t")
            }.join("\n")
        end
        
        def local?
            self.local
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

            str = nil
            if links == :manage
                raise Puppet::Error, "Cannot copy links yet."
            else
                str = mount.read_file(path, client)
            end

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
            mod = Puppet::Module::find(module_name, env)
            if mod
                return @mounts[MODULES].copy(mod.name, mod.files)
            else
                return nil
            end
        end

        # Read the configuration file.
        def readconfig(check = true)
            return if @noreadconfig

            if check and ! @config.changed?
                return
            end

            newmounts = {}
            begin
                File.open(@config.file) { |f|
                    mount = nil
                    count = 1
                    f.each { |line|
                        case line
                        when /^\s*#/: next # skip comments
                        when /^\s*$/: next # skip blank lines
                        when /\[([-\w]+)\]/:
                            name = $1
                            if newmounts.include?(name)
                                raise FileServerError, "%s is already mounted at %s" %
                                    [newmounts[name], name], count, @config.file
                            end
                            mount = Mount.new(name)
                            newmounts[name] = mount
                        when /^\s*(\w+)\s+(.+)$/:
                            var = $1
                            value = $2
                            case var
                            when "path":
                                if mount.name == PLUGINS
                                    Puppet.warning "An explicit 'plugins' mount is deprecated.  Please switch to using modules."
                                end
                                
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
                            when "allow":
                                value.split(/\s*,\s*/).each { |val|
                                    begin
                                        mount.info "allowing %s access" % val
                                        mount.allow(val)
                                    rescue AuthStoreError => detail
                                        raise FileServerError.new(detail.to_s,
                                            count, @config.file)
                                    end
                                }
                            when "deny":
                                value.split(/\s*,\s*/).each { |val|
                                    begin
                                        mount.info "denying %s access" % val
                                        mount.deny(val)
                                    rescue AuthStoreError => detail
                                        raise FileServerError.new(detail.to_s,
                                            count, @config.file)
                                    end
                                }
                            else
                                raise FileServerError.new("Invalid argument '%s'" % var,
                                    count, @config.file)
                            end
                        else
                            raise FileServerError.new("Invalid line '%s'" % line.chomp,
                                count, @config.file)
                        end
                        count += 1
                    }
                }
            rescue Errno::EACCES => detail
                Puppet.err "FileServer error: Cannot read %s; cannot serve" % @config
                #raise Puppet::Error, "Cannot read %s" % @config
            rescue Errno::ENOENT => detail
                Puppet.err "FileServer error: '%s' does not exist; cannot serve" %
                    @config
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

            def getfileobject(dir, links, client = nil)
                unless path_exists?(dir, client)
                    self.debug "File source %s does not exist" % dir
                    return nil
                end

                return fileobj(dir, links, client)
            end
             
            # Run 'retrieve' on a file.  This gets the actual parameters, so
            # we can pass them to the client.
            def check(obj)
                # Retrieval is enough here, because we don't want to cache
                # any information in the state file, and we don't want to generate
                # any state changes or anything.  We don't even need to sync
                # the checksum, because we're always going to hit the disk
                # directly.

                # We're now caching file data, using the LoadedFile to check the
                # disk no more frequently than the :filetimeout.
                path = obj[:path]
                sync = sync(path)
                unless data = @@files[path]
                    data = {}
                    sync.synchronize(Sync::EX) do
                        @@files[path] = data
                        data[:loaded_obj] = Puppet::Util::LoadedFile.new(path)
                        data[:values] = properties(obj)
                        return data[:values]
                    end
                end

                changed = nil
                sync.synchronize(Sync::SH) do
                    changed = data[:loaded_obj].changed?
                end

                if changed
                    sync.synchronize(Sync::EX) do
                        data[:values] = properties(obj)
                        return data[:values]
                    end
                else
                    sync.synchronize(Sync::SH) do
                        return data[:values]
                    end
                end
            end

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

                raise ArgumentError.new("Mounts without paths are not usable") unless full_path

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

                super()
            end

            def fileobj(path, links, client)
                obj = nil
                if obj = Puppet.type(:file)[file_path(path, client)]
                    # This can only happen in local fileserving, but it's an
                    # important one.  It'd be nice if we didn't just set
                    # the check params every time, but I'm not sure it's worth
                    # the effort.
                    obj[:check] = CHECKPARAMS
                else
                    obj = Puppet.type(:file).create(
                        :name => file_path(path, client),
                        :check => CHECKPARAMS
                    )
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
                reclist(file_path(relpath, client), nil, recurse, ignore)
            end

            # Recursively list the files in this tree.
            def reclist(basepath, abspath, recurse, ignore)
                abspath = basepath if abspath.nil?
                relpath = abspath.sub(%r{^#{basepath}}, '')
                relpath = "/#{relpath}" if relpath[0] != ?/  #/
                
                desc = [relpath]
                
                ftype = File.stat(abspath).ftype

                desc << ftype
                if recurse.is_a?(Integer)
                    recurse -= 1
                end

                ary = [desc]
                if recurse == true or (recurse.is_a?(Integer) and recurse > -1)
                    if ftype == "directory"
                        children = Dir.entries(abspath)
                        if ignore
                            children = handleignore(children, abspath, ignore)
                        end  
                        children.each { |child|
                            next if child =~ /^\.\.?$/
                            reclist(basepath, File.join(abspath, child), recurse, ignore).each { |cobj|
                                ary << cobj
                            }
                        }
                    end
                end

                return ary.compact
            end

            # Deal with ignore parameters.
            def handleignore(files, path, ignore_patterns)
                ignore_patterns.each do |ignore|
                    files.delete_if do |entry|
                        File.fnmatch(ignore, entry, File::FNM_DOTMATCH)
                    end
                end
                return files
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

            def path_exists?(relpath, client = nil)
               !valid_modules.find { |m| File.exists?(File.join(m, PLUGINS, relpath)) }.nil?
            end
            
            def valid?
                true
            end

            def file_path(relpath, client = nil)
                mod = valid_modules.map { |m| File.exists?(File.join(m, PLUGINS, relpath)) ? m : nil }.compact.first
                File.join(mod, PLUGINS, relpath)
            end

            def reclist(basepath, abspath, recurse, ignore)
                abspath = basepath if abspath.nil?
                relpath = abspath.sub(%r{^#{basepath}}, '')
                relpath = "/#{relpath}" unless relpath[0] == ?/  #/
                
                desc = [relpath]
                
                ftype = File.stat(file_path(abspath)).ftype

                desc << ftype
                if recurse.is_a?(Integer)
                    recurse -= 1
                end

                ary = [desc]
                if recurse == true or (recurse.is_a?(Integer) and recurse > -1)
                    if ftype == "directory"
                        valid_modules.each do |mod|
                            begin
                                children = Dir.entries(File.join(mod, PLUGINS, abspath))
                                if ignore
                                    children = handleignore(children, abspath, ignore)
                                end  
                                children.each { |child|
                                    next if child =~ /^\.\.?$/
                                    reclist(basepath, File.join(abspath, child), recurse, ignore).each { |cobj|
                                        ary << cobj
                                    }
                                }
                            rescue Errno::ENOENT
                                # A missing directory or whatever isn't a
                                # massive problem in here; it'll happen
                                # whenever we've got a module that doesn't
                                # have a directory than another module does.
                            end
                        end
                    end
                end

                return ary.compact
            end

            private
            def valid_modules
               Puppet::Module.all.find_all { |m| File.directory?(File.join(m, PLUGINS)) }
            end
            
            def add_to_filetree(f, filetree)
               first, rest = f.split(File::SEPARATOR, 2)
            end
        end
    end
end

