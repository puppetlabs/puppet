require 'puppet'
require 'webrick/httpstatus'
require 'cgi'

module Puppet
class Server
    class FileServerError < Puppet::Error; end
    class FileServer < Handler
        attr_accessor :local

        Puppet.setdefault(:fileserverconfig, [:puppetconf, "fileserver.conf"])

        #CHECKPARAMS = %w{checksum type mode owner group}
        CHECKPARAMS = [:mode, :type, :owner, :group, :checksum]

        @interface = XMLRPC::Service::Interface.new("fileserver") { |iface|
            iface.add_method("string describe(string)")
            iface.add_method("string list(string, boolean, array)")
            iface.add_method("string retrieve(string)")
        }

        def authcheck(file, mount, client, clientip)
            unless mount.allowed?(client, clientip)
                Puppet.warning "%s cannot access %s in %s" %
                    [client, mount, file]
                raise Puppet::Server::AuthorizationError, "Cannot access %s" % mount
            end
        end

        # Run 'retrieve' on a file.  This gets the actual parameters, so
        # we can pass them to the client.
        def check(dir)
            unless FileTest.exists?(dir)
                Puppet.notice "File source %s does not exist" % dir
                return nil
            end

            obj = nil
            unless obj = Puppet.type(:file)[dir]
                obj = Puppet.type(:file).create(
                    :name => dir,
                    :check => CHECKPARAMS
                )
            end
            # we should really have a timeout here -- we don't
            # want to actually check on every connection, maybe no more
            # than every 60 seconds or something
            #@files[mount].evaluate
            obj.evaluate

            return obj
        end

        # Describe a given file.  This returns all of the manageable aspects
        # of that file.
        def describe(file, client = nil, clientip = nil)
            readconfig
            mount, path = splitpath(file)

            authcheck(file, mount, client, clientip)

            sdir = nil
            unless sdir = subdir(mount, path)
                mount.notice "Could not find subdirectory %s" %
                    "//%s/%s" % [mount, path]
                return ""
            end

            obj = nil
            unless obj = self.check(sdir)
                return ""
            end

            desc = []
            CHECKPARAMS.each { |check|
                if state = obj.state(check)
                    unless state.is
                        mount.notice "Manually retrieving info for %s" % check
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

        # Deal with ignore parameters.
        def handleignore(children, path, ignore)            
            ignore.value.each { |ignore|                
                Dir.glob(File.join(path,ignore), File::FNM_DOTMATCH) { |match|
                    children.delete(File.basename(match))
                }                
            }
            return children
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
                @config = hash[:Config] || Puppet[:fileserverconfig]
                @noreadconfig = false
            end

            @configtimeout = hash[:ConfigTimeout] || 60
            @configstamp = nil
            @congigstatted = nil

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
                readconfig
            end
        end

        # List a specific directory's contents.
        def list(dir, recurse = false, ignore = false, client = nil, clientip = nil)
            readconfig
            mount, path = splitpath(dir)

            authcheck(dir, mount, client, clientip)

            subdir = nil
            unless subdir = subdir(mount, path)
                mount.notice "Could not find subdirectory %s" %
                    "%s:%s" % [mount, path]
                return ""
            end

            obj = nil
            unless FileTest.exists?(subdir)
                return ""
            end

            rmdir = expand_mount(dir, mount)
            desc = reclist(mount, rmdir, subdir, recurse, ignore)

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

            if FileTest.directory?(path)
                if FileTest.readable?(path)
                    @mounts[name] = Mount.new(name, path)
                    @mounts[name].info "Mounted"
                else
                    raise FileServerError, "%s is not readable" % path
                end
            else
                raise FileServerError, "%s is not a directory" % path
            end
        end

        # Read the configuration file.
        def readconfig
            return if @noreadconfig

            if @configstamp and FileTest.exists?(@config)
                if @configtimeout and @configstatted
                    if Time.now - @configstatted > @configtimeout
                        @configstatted = Time.now
                        tmp = File.stat(@config).ctime

                        if tmp == @configstamp
                            return
                        end
                    else
                        return
                    end
                end
            end

            newmounts = {}
            begin
                File.open(@config) { |f|
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
                                    [newmounts[name], name]
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
                                        raise FileServerError, "%s at line %s of %s" %
                                            [detail.to_s, count, @config]
                                    end
                                }
                            when "deny":
                                value.split(/\s*,\s*/).each { |val|
                                    begin
                                        mount.info "denying %s access" % val
                                        mount.deny(val)
                                    rescue AuthStoreError => detail
                                        raise FileServerError, "%s at line %s of %s" %
                                            [detail.to_s, count, @config]
                                    end
                                }
                            else
                                raise FileServerError,
                                    "Invalid argument '%s' at line %s" % [var, count]
                            end
                        else
                            raise FileServerError, "Invalid line %s: %s" % [count, line]
                        end
                        count += 1
                    }
                }
            rescue Errno::EACCES => detail
                Puppet.err "FileServer error: Cannot read %s; cannot serve" % @config
                #raise Puppet::Error, "Cannot read %s" % @config
            rescue Errno::ENOENT => detail
                Puppet.err "FileServer error: '%s' does not exit; cannot serve" %
                    @config
                #raise Puppet::Error, "%s does not exit" % @config
            #rescue FileServerError => detail
            #    Puppet.err "FileServer error: %s" % detail
            end

            # Verify each of the mounts are valid.
            # We let the check raise an error, so that it can raise an error
            # pointing to the specific problem.
            newmounts.each { |name, mount|
                mount.valid?
            }
            @mounts = newmounts

            @configstamp = File.stat(@config).ctime
            @configstatted = Time.now
        end

        # Retrieve a file from the local disk and pass it to the remote
        # client.
        def retrieve(file, client = nil, clientip = nil)
            readconfig
            mount, path = splitpath(file)

            authcheck(file, mount, client, clientip)

            fpath = nil
            if path
                fpath = File.join(mount.path, path)
            else
                fpath = mount.path
            end

            unless FileTest.exists?(fpath)
                return ""
            end

            str = File.read(fpath)

            if @local
                return str
            else
                return CGI.escape(str)
            end
        end

        private

        # Convert from the '/mount/path' form to the real path on disk.
        def expand_mount(name, mount)
            # Note that the user could have passed a path with multiple /'s
            # in it, and we are likely to result in multiples, so we have to
            # get rid of all of them.
            name.sub(/\/#{mount.name}/, mount.path).gsub(%r{/+}, '/').sub(
                %r{/$}, ''
            )
        end

        # Recursively list the directory.
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
        def splitpath(dir)
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

                unless @mounts[mount].path
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
            end
            return mount, path
        end

        # Retrieve a specific directory relative to a mount point.
        def subdir(mount, dir)
            basedir = mount.path

            dirname = nil
            if dir
                dirname = File.join(basedir, dir.split("/").join(File::SEPARATOR))
            else
                dirname = basedir
            end

            dirname
        end

        # A simple class for wrapping mount points.  Instances of this class
        # don't know about the enclosing object; they're mainly just used for
        # authorization.
        class Mount < AuthStore
            attr_reader :path, :name

            Puppet::Util.logmethods(self, true)

            # Create out orbject.  It must have a name.
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

                super()
            end

            # Set the path.
            def path=(path)
                unless FileTest.exists?(path)
                    raise FileServerError, "%s does not exist" % path
                end
                @path = path
            end

            def to_s
                if @path
                    @name + ":" + @path
                else
                    @name
                end
            end

            # Verify our configuration is valid.  This should really check to
            # make sure at least someone will be allowed, but, eh.
            def valid?
                unless @path
                    raise FileServerError, "No path specified"
                end
            end
        end
    end
end
end

# $Id$
