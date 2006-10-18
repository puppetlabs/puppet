require 'puppet'
require 'webrick/httpstatus'
require 'cgi'
require 'delegate'

module Puppet
class FileServerError < Puppet::Error; end
class Server
    class FileServer < Handler
        attr_accessor :local

        Puppet.setdefaults("fileserver",
            :fileserverconfig => ["$confdir/fileserver.conf",
                "Where the fileserver configuration is stored."])

        CHECKPARAMS = [:mode, :type, :owner, :group, :checksum]

        @interface = XMLRPC::Service::Interface.new("fileserver") { |iface|
            iface.add_method("string describe(string, string)")
            iface.add_method("string list(string, string, boolean, array)")
            iface.add_method("string retrieve(string, string)")
        }

        # Describe a given file.  This returns all of the manageable aspects
        # of that file.
        def describe(url, links = :ignore, client = nil, clientip = nil)
            links = links.intern if links.is_a? String

            if links == :manage
                raise Puppet::FileServerError, "Cannot currently copy links"
            end

            mount, path = convert(url, client, clientip)

            if client
                mount.debug "Describing %s for %s" % [url, client]
            end

            obj = nil
            unless obj = mount.check(path, links)
                return ""
            end

            desc = []
            CHECKPARAMS.each { |check|
                if state = obj.state(check)
                    unless state.is
                        mount.debug "Manually retrieving info for %s" % check
                        state.retrieve
                    end
                    desc << state.is
                else
                    if check == "checksum" and obj.state(:type).is == "file"
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
                @config = Puppet::LoadedFile.new(
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
            unless FileTest.exists?(path)
                return ""
            end

            # We pass two paths here, but reclist internally changes one
            # of the arguments when called internally.
            desc = reclist(mount, path, path, recurse, ignore)

            if desc.length == 0
                mount.notice "Got no information on //%s/%s" %
                    [mount, path]
                return ""
            end
            
            desc.collect { |sub|
                sub.join("\t")
            }.join("\n")
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

            unless FileTest.exists?(path)
                return ""
            end

            links = links.intern if links.is_a? String

            if links == :ignore and FileTest.symlink?(path)
                return ""
            end

            str = nil
            if links == :manage
                raise Puppet::Error, "Cannot copy links yet."
            else
                str = File.read(path)
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
            unless mount.allowed?(client, clientip)
                mount.warning "%s cannot access %s" %
                    [client, file]
                raise Puppet::Server::AuthorizationError, "Cannot access %s" % mount
            end
        end

        def convert(url, client, clientip)
            readconfig

            url = URI.unescape(url)

            mount, stub = splitpath(url, client)

            authcheck(url, mount, client, clientip)

            path = nil
            unless path = mount.subdir(stub, client)
                mount.notice "Could not find subdirectory %s" %
                    "//%s/%s" % [mount, stub]
                return ""
            end

            return mount, path
        end

        # Deal with ignore parameters.
        def handleignore(children, path, ignore)            
            ignore.each { |ignore|                
                Dir.glob(File.join(path,ignore), File::FNM_DOTMATCH) { |match|
                    children.delete(File.basename(match))
                }                
            }
            return children
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
                        when /\[(\w+)\]/:
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
                                begin
                                    mount.path = value
                                rescue FileServerError => detail
                                    Puppet.err "Removing mount %s: %s" %
                                        [mount.name, detail]
                                    newmounts.delete(mount.name)
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
                #raise Puppet::Error, "%s does not exit" % @config
            #rescue FileServerError => detail
            #    Puppet.err "FileServer error: %s" % detail
            end

            # Verify each of the mounts are valid.
            # We let the check raise an error, so that it can raise an error
            # pointing to the specific problem.
            newmounts.each { |name, mount|
                unless mount.valid?
                    raise FileServerError, "No path specified for mount %s" %
                        name
                end
            }
            @mounts = newmounts
        end

        # Recursively list the directory. FIXME This should be using
        # puppet objects, not directly listing.
        def reclist(mount, root, path, recurse, ignore)
            # Take out the root of the path.
            name = path.sub(root, '')
            if name == ""
                name = "/"
            end

            if name == path
                raise FileServerError, "Could not match %s in %s" %
                    [root, path]
            end

            desc = [name]
            ftype = File.stat(path).ftype

            desc << ftype
            if recurse.is_a?(Integer)
                recurse -= 1
            end

            ary = [desc]
            if recurse == true or (recurse.is_a?(Integer) and recurse > -1)
                if ftype == "directory"
                    children = Dir.entries(path)
                    if ignore
                        children = handleignore(children, path, ignore)
                    end  
                    children.each { |child|
                        next if child =~ /^\.\.?$/
                        reclist(mount, root, File.join(path, child), recurse, ignore).each { |cobj|
                            ary << cobj
                        }
                    }
                end
            end

            return ary.reject { |c| c.nil? }
        end

        # Split the path into the separate mount point and path.
        def splitpath(dir, client)
            # the dir is based on one of the mounts
            # so first retrieve the mount path
            mount = nil
            path = nil
            if dir =~ %r{/(\w+)/?}
                mount = $1
                path = dir.sub(%r{/#{mount}/?}, '')

                unless @mounts.include?(mount)
                    raise FileServerError, "Fileserver module '%s' not mounted" % mount
                end

                unless @mounts[mount].valid?
                    raise FileServerError,
                        "Fileserver error: Mount '%s' does not have a path set" % mount
                end

                # And now replace the name with the actual object.
                mount = @mounts[mount]
            else
                raise FileServerError, "Fileserver error: Invalid path '%s'" % dir
            end

            if path == ""
                path = nil
            else
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
        class Mount < AuthStore
            attr_reader :name

            Puppet::Util.logmethods(self, true)

            # Run 'retrieve' on a file.  This gets the actual parameters, so
            # we can pass them to the client.
            def check(dir, links)
                unless FileTest.exists?(dir)
                    self.notice "File source %s does not exist" % dir
                    return nil
                end

                obj = fileobj(dir, links)

                # FIXME we should really have a timeout here -- we don't
                # want to actually check on every connection, maybe no more
                # than every 60 seconds or something.  It'd be nice if we
                # could use the builtin scheduling to do this.

                # Retrieval is enough here, because we don't want to cache
                # any information in the state file, and we don't want to generate
                # any state changes or anything.  We don't even need to sync
                # the checksum, because we're always going to hit the disk
                # directly.
                obj.retrieve

                return obj
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

            # Create out object.  It must have a name.
            def initialize(name, path = nil)
                unless name =~ %r{^\w+$}
                    raise FileServerError, "Invalid name format '%s'" % name
                end
                @name = name

                if path
                    self.path = path
                else
                    @path = nil
                end

                @comp = Puppet.type(:component).create(
                    :name => "mount[#{name}]"
                )
                #@comp.type = "mount"
                #@comp.name = name

                super()
            end

            def fileobj(path, links)
                obj = nil
                if obj = Puppet.type(:file)[path]
                    # This can only happen in local fileserving, but it's an
                    # important one.  It'd be nice if we didn't just set
                    # the check params every time, but I'm not sure it's worth
                    # the effort.
                    obj[:check] = CHECKPARAMS
                else
                    obj = Puppet.type(:file).create(
                        :name => path,
                        :check => CHECKPARAMS
                    )

                    @comp.push(obj)
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

            # Retrieve a specific directory relative to a mount point.
            # If they pass in a client, then expand as necessary.
            def subdir(dir = nil, client = nil)
                basedir = self.path(client)

                dirname = if dir
                    File.join(basedir, dir.split("/").join(File::SEPARATOR))
                else
                    basedir
                end

                dirname
            end

            def to_s
                "mount[#{@name}]"
            end

            # Verify our configuration is valid.  This should really check to
            # make sure at least someone will be allowed, but, eh.
            def valid?
                return false unless @path

                return true
            end
        end
    end
end
end

# $Id$
