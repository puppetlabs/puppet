require 'puppet'
require 'cgi'

module Puppet
class Server
    class FileServerError < Puppet::Error; end
    class FileServer < Handler
        attr_accessor :local

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

        def describe(file)
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
        end

        def list(dir, recurse = false, sum = "md5")
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
            desc = self.reclist(rmdir, subdir, recurse)

            if desc.length == 0
                Puppet.notice "Got no information on //%s/%s" %
                    [mount, path]
                return ""
            end
            
            desc.collect { |sub|
                sub.join("\t")
            }.join("\n")
        end

        def mount(dir, name)
            if @mounts.include?(name)
                if @mounts[name] != dir
                    raise FileServerError, "%s is already mounted at %s" %
                        [@mounts[name], name]
                else
                    # it's already mounted; no problem
                    return
                end
            end

            unless name =~ %r{^\w+$}
                raise FileServerError, "Invalid name format '%s'" % name
            end

            unless FileTest.exists?(dir)
                raise FileServerError, "%s does not exist" % dir
            end

            if FileTest.directory?(dir)
                if FileTest.readable?(dir)
                    Puppet.info "Mounting %s at %s" % [dir, name]
                    @mounts[name] = dir
                else
                    raise FileServerError, "%s is not readable" % dir
                end
            else
                raise FileServerError, "%s is not a directory" % dir
            end
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
                        self.reclist(root, File.join(path, child), recurse).each { |cobj|
                            ary << cobj
                        }
                    }
                end
            end

            return ary.reject { |c| c.nil? }
        end

        def retrieve(file)
            mount, path = splitpath(file)

            unless (@mounts.include?(mount))
                # FIXME I really need some better way to pass and handle xmlrpc errors
                raise FileServerError, "%s not mounted" % mount
            end

            fpath = nil
            if path
                fpath = File.join(@mounts[mount], path)
            else
                fpath = @mounts[mount]
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
            name.sub(/\/#{mount}/, @mounts[mount]).gsub(%r{//}, '/').sub(
                %r{/$}, ''
            )
            #Puppet.info "Swapped %s to %s" % [name, newname]
            #newname
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
            basedir = @mounts[mount]

            dirname = nil
            if dir
                dirname = File.join(basedir, dir.split("/").join(File::SEPARATOR))
            else
                dirname = basedir
            end

            return dirname
        end
    end
end
end

# $Id$
