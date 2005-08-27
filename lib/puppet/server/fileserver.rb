require 'puppet'
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
            iface.add_method("string list(string, boolean)")
            iface.add_method("string retrieve(string)")
        }

        def check(dir)
            unless FileTest.exists?(dir)
                Puppet.notice "File source %s does not exist" % dir
                return nil
            end

            obj = nil
            unless obj = Puppet::Type::PFile[dir]
                obj = Puppet::Type::PFile.new(
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

        def describe(file, request = nil)
            mount, path = splitpath(file)

            subdir = nil
            unless subdir = subdir(mount, path)
                Puppet.notice "Could not find subdirectory %s" %
                    "//%s/%s" % [mount, path]
                return ""
            end

            obj = nil
            unless obj = self.check(subdir)
                return ""
            end

            desc = []
            CHECKPARAMS.each { |check|
                if state = obj.state(check)
                    unless state.is
                        Puppet.notice "Manually retrieving info for %s" % check
                        state.retrieve
                    end
                    desc << state.is
                else
                    if check == "checksum" and obj.state(:type).is == "file"
                        Puppet.notice "File %s does not have data for %s" %
                            [obj.name, check]
                    end
                    desc << nil
                end
            }

            return desc.join("\t")
        end

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

            @configstamp = nil

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

        def list(dir, recurse = false, sum = "md5", request = nil)
            mount, path = splitpath(dir)

            subdir = nil
            unless subdir = subdir(mount, path)
                Puppet.notice "Could not find subdirectory %s" %
                    "//%s/%s" % [mount, path]
                return ""
            end

            obj = nil
            unless FileTest.exists?(subdir)
                return ""
            end

            #rmdir = File.dirname(File.join(@mounts[mount], path))
            rmdir = nameswap(dir, mount)
            desc = reclist(rmdir, subdir, recurse)

            if desc.length == 0
                Puppet.notice "Got no information on //%s/%s" %
                    [mount, path]
                return ""
            end
            
            desc.collect { |sub|
                sub.join("\t")
            }.join("\n")
        end

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
                    Puppet.info "Mounted %s at %s" % [path, name]
                else
                    raise FileServerError, "%s is not readable" % path
                end
            else
                raise FileServerError, "%s is not a directory" % path
            end
        end

        def readconfig
            return if @noreadconfig

            @mounts.clear

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
                            if @mounts.include?(name)
                                raise FileServerError, "%s is already mounted at %s" %
                                    [@mounts[name], name]
                            end
                            mount = Mount.new(name)
                            @mounts[name] = mount
                        when /\s*(\w+)\s+(.+)$/:
                            var = $1
                            value = $2
                            case var
                            when "path":
                                mount.path = value
                            when "allow":
                                value.split(/\s*,\s*/).each { |val|
                                    mount.allow(val)
                                }
                            when "deny":
                                value.split(/\s*,\s*/).each { |val|
                                    mount.deny(val)
                                }
                            else
                                raise Puppet::Error,
                                    "Invalid argument %s at line %s" % [var, count]
                            end
                        else
                            raise Puppet::Error,
                                "Invalid line %s: %s" % [count, line]
                        end
                        count += 1
                    }
                }
            rescue Errno::EACCES => detail
                raise Puppet::Error, "Cannot read %s" % @config
            rescue Errno::ENOENT => detail
                raise Puppet::Error, "%s does not exit" % @config
            end
        end

        def retrieve(file, request = nil)
            mount, path = splitpath(file)

            unless (@mounts.include?(mount))
                # FIXME I really need some better way to pass and handle xmlrpc errors
                raise FileServerError, "%s not mounted" % mount
            end

            fpath = nil
            if path
                fpath = File.join(@mounts[mount].path, path)
            else
                fpath = @mounts[mount].path
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

        def nameswap(name, mount)
            name.sub(/\/#{mount}/, @mounts[mount].path).gsub(%r{//}, '/').sub(
                %r{/$}, ''
            )
            #Puppet.info "Swapped %s to %s" % [name, newname]
            #newname
        end

        # recursive listing function
        def reclist(root, path, recurse)
            #desc = [obj.name.sub(%r{#{root}/?}, '')]
            name = path.sub(root, '')
            if name == ""
                name = "/"
            end

            if name == path
                raise Puppet::FileServerError, "Could not match %s in %s" %
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
                    Dir.entries(path).each { |child|
                        next if child =~ /^\.\.?$/
                        reclist(root, File.join(path, child), recurse).each { |cobj|
                            ary << cobj
                        }
                    }
                end
            end

            return ary.reject { |c| c.nil? }
        end

        def splitpath(dir)
            # the dir is based on one of the mounts
            # so first retrieve the mount path
            mount = nil
            path = nil
            if dir =~ %r{/(\w+)/?}
                mount = $1
                path = dir.sub(%r{/#{mount}/?}, '')

                unless @mounts.include?(mount)
                    raise FileServerError, "%s not mounted" % mount
                end
            else
                raise FileServerError, "Invalid path '%s'" % dir
            end

            if path == ""
                path = nil
            end
            return mount, path
        end

        def subdir(mount, dir)
            basedir = @mounts[mount].path

            dirname = nil
            if dir
                dirname = File.join(basedir, dir.split("/").join(File::SEPARATOR))
            else
                dirname = basedir
            end

            return dirname
        end

        class Mount
            attr_reader :path, :name

            def allow(pattern)
            end

            def allowed?(host)
            end

            def deny(pattern)
            end

            def initialize(name, path = nil)
                unless name =~ %r{^\w+$}
                    raise FileServerError, "Invalid name format '%s'" % name
                end
                @name = name

                @allow = []
                @deny = []

                if path
                    self.path = path
                end
            end

            def path=(path)
                unless FileTest.exists?(path)
                    raise FileServerError, "%s does not exist" % path
                end
                @path = path
            end

            def to_s
                @path
            end
        end
    end
end
end

# $Id$
