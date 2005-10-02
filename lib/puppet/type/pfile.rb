require 'digest/md5'
require 'cgi'
require 'etc'
require 'uri'
require 'fileutils'
require 'puppet/type/state'
require 'puppet/server/fileserver'

# We put all of the states in separate files, because there are so many
# of them.
require 'puppet/type/pfile/pfiletype'
require 'puppet/type/pfile/pfilecreate'
require 'puppet/type/pfile/pfilechecksum'
require 'puppet/type/pfile/pfileuid'
require 'puppet/type/pfile/pfilemode'
require 'puppet/type/pfile/pfilegroup'
require 'puppet/type/pfile/pfilesource'

module Puppet
    class Type
        class PFile < Type
            @doc = "Manages local files, including setting ownership and
                permissions, and allowing creation of both files and directories."

            @states = [
                Puppet::State::PFileCreate,
                Puppet::State::PFileChecksum,
                Puppet::State::PFileSource,
                Puppet::State::PFileUID,
                Puppet::State::PFileGroup,
                Puppet::State::PFileMode,
                Puppet::State::PFileType
            ]

            @parameters = [
                :path,
                :backup,
                :linkmaker,
                :recurse,
                :ignore
            ]

            @paramdoc[:path] = "The path to the file to manage.  Must be fully
                qualified."

            @paramdoc[:backup] = "Whether files should be backed up before
                being replaced.  If a ``filebucket`` is specified, files will be
                backed up there; else, they will be backed up in the same directory
                with a ``.puppet-bak`` extension."

            @paramdoc[:linkmaker] = "An internal parameter used by the *symlink*
                type to do recursive link creation."

            @paramdoc[:recurse] = "Whether and how deeply to do recursive
                management.  **false**/*true*/*inf*/*number*"

            @paramdoc[:ignore] = "A parameter which omits action on files matching
                specified patterns during recursion.  Uses Ruby's builtin globbing
                engine, so shell metacharacters are fully supported, e.g. ``[a-z]*``.
                Matches that would descend into the directory structure are ignored,
                e.g., ``*/*``."

          #no longer a parameter
           # @paramdoc[:source] = "Where to retrieve the contents of the files.
           #     Currently only supports local copying, but will eventually
           #     support multiple protocols for copying.  Arguments are specified
           #     using either a full local path or using a URI (currently only
           #     *file* is supported as a protocol)."

            

            @name = :file
            @namevar = :path

            @depthfirst = false

            PINPARAMS = [:mode, :type, :owner, :group, :checksum]


            def argument?(arg)
                @arghash.include?(arg)
            end

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
                    # we don't need to backup directories
                    return true
                when "file":
                    backup = self[:backup]
                    case backup
                    when Puppet::Client::Dipper:
                        sum = backup.backup(file)
                        Puppet.info "Filebucketed %s with sum %s" %
                            [file, sum]
                        return true
                    when String:
                        newfile = file + backup
                        if FileTest.exists?(newfile)
                            begin
                                File.unlink(newfile)
                            rescue => detail
                                Puppet.err "Could not remove old backup: %s" %
                                    detail
                                return false
                            end
                        end
                        begin
                            FileUtils.cp(file,
                                file + backup)
                            return true
                        rescue => detail
                            # since they said they want a backup, let's error out
                            # if we couldn't make one
                            raise Puppet::Error.new("Could not back %s up: %s" %
                                [file, detail.message])
                        end
                    else
                        Puppet.err "Invalid backup type %s" % backup
                        return false
                    end
                else
                    Puppet.notice "Cannot backup files of type %s" %
                        File.stat(file).ftype
                    return false
                end
            end
            
            def handleignore(children)
                @parameters[:ignore].each { |ignore|
                    ignored = []
                    Dir.glob(File.join(self.name,ignore), File::FNM_DOTMATCH) { |match|
                        ignored.push(File.basename(match))
                    }
                    children = children - ignored
                }
                return children
            end
              
            def initialize(hash)
                # clean out as many references to any file paths as possible
                # this was the source of many, many bugs
                
                @arghash = self.argclean(hash)
                @arghash.delete(self.class.namevar)

                if @arghash.include?(:source)
                    @arghash.delete(:source)
                end

                @stat = nil
                @parameters = Hash.new(false)

                # default to true
                self[:backup] = true

                super
            end
            
            def path
                if defined? @parent
                    if @parent.is_a?(self.class)
                        return [@parent.path, File.basename(self.name)].flatten
                    else
                        return [@parent.path, self.name].flatten
                    end
                else
                    return [self.name]
                end
            end

            def parambackup=(value)
                case value
                when false, "false":
                    @parameters[:backup] = false
                when true, "true":
                    @parameters[:backup] = ".puppet-bak"
                when Array:
                    case value[0]
                    when "filebucket":
                        if bucket = Puppet::Type::PFileBucket.bucket(value[1])
                            @parameters[:backup] = bucket
                        else
                            @parameters[:backup] = ".puppet-bak"
                            raise Puppet::Error,
                                "Could not retrieve filebucket %s" %
                                value[1]
                        end
                    else
                        raise Puppet::Error, "Invalid backup object type %s" %
                            value[0].inspect
                    end
                else
                    raise Puppet::Error, "Invalid backup type %s" %
                        value.inspect
                end
            end
            
            def paramignore=(value)
           
                #Make sure the value of ignore is in correct type    
                unless value.is_a?(Array) or value.is_a?(String)
                    raise Puppet::DevError.new("Ignore must be a string or an Array")
                end
            
                @parameters[:ignore] = value
            end

            def newchild(path, hash = {})
                # make local copy of arguments
                args = @arghash.dup

                if path =~ %r{^#{File::SEPARATOR}}
                    raise Puppet::DevError.new(
                        "Must pass relative paths to PFile#newchild()"
                    )
                else
                    path = File.join(self.name, path)
                end

                args[:path] = path

                unless hash.include?(:recurse)
                    if args.include?(:recurse)
                        if args[:recurse].is_a?(Integer)
                            Puppet.notice "Decrementing recurse on %s" % path
                            args[:recurse] -= 1 # reduce the level of recursion
                        end
                    end

                end

                hash.each { |key,value|
                    args[key] = value
                }

                child = nil
                klass = nil
                if @parameters[:linkmaker] and args.include?(:source) and
                    ! FileTest.directory?(args[:source])
                    klass = Puppet::Type::Symlink

                    Puppet.debug "%s is a link" % path
                    # clean up the args a lot for links
                    old = args.dup
                    args = {
                        :target => old[:source],
                        :path => path
                    }
                else
                    klass = self.class
                end

                # The child might already exist because 'localrecurse' runs
                # before 'sourcerecurse'.  I could push the override stuff into
                # a separate method or something, but the work is the same other
                # than this last bit, so it doesn't really make sense.
                if child = klass[path]
                    unless @children.include?(child)
                        Puppet.notice "Not managing more explicit file %s" %
                            path
                        return nil
                    end
                    args.each { |var,value|
                        next if var == :path
                        next if var == :name
                        # behave idempotently
                        unless child.should(var) == value
                            child[var] = value
                        end
                    }
                else # create it anew
                    #notice "Creating new file with args %s" % args.inspect
                    begin
                        child = klass.implicitcreate(args)
                        
                        # implicit creation can return nil
                        if child.nil?
                            return nil
                        end
                        child.parent = self
                        @children << child
                    rescue Puppet::Error => detail
                        Puppet.notice(
                            "Cannot manage %s: %s" %
                                [path,detail.message]
                        )
                        Puppet.debug args.inspect
                        child = nil
                    rescue => detail
                        Puppet.notice(
                            "Cannot manage %s: %s" %
                                [path,detail]
                        )
                        Puppet.debug args.inspect
                        child = nil
                    end
                end
                return child
            end

            # Recurse into the directory.  This basically just calls 'localrecurse'
            # and maybe 'sourcerecurse'.
            def recurse
                recurse = @parameters[:recurse]
                # we might have a string, rather than a number
                if recurse.is_a?(String)
                    if recurse =~ /^[0-9]+$/
                        recurse = Integer(recurse)
                    #elsif recurse =~ /^inf/ # infinite recursion
                    else # anything else is infinite recursion
                        recurse = true
                    end
                end

                # are we at the end of the recursion?
                if recurse == 0
                    Puppet.info "finished recursing"
                    return
                end

                if recurse.is_a?(Integer)
                    recurse -= 1
                end

                self.localrecurse(recurse)
                if @states.include?(:source)
                    self.sourcerecurse(recurse)
                end
            end

            def localrecurse(recurse)
                unless FileTest.exist?(self.name) and self.stat.directory?
                    #Puppet.info "%s is not a directory; not recursing" %
                    #    self.name
                    return
                end

                unless FileTest.directory? self.name
                    raise Puppet::Error.new(
                        "Uh, somehow trying to manage non-dir %s" % self.name
                    )
                end
                unless FileTest.readable? self.name
                    Puppet.notice "Cannot manage %s: permission denied" % self.name
                    return
                end

                children = Dir.entries(self.name)
             
                #Get rid of ignored children
                if @parameters.include?(:ignore)
                    children = handleignore(children)
                end  
            
                added = []
                children.each { |file|
                    file = File.basename(file)
                    next if file =~ /^\.\.?/ # skip . and .. 
                    if child = self.newchild(file, :recurse => recurse)
                        unless @children.include?(child)
                            self.push child
                            added.push file
                        end
                    end
                }
            end

            def sourcerecurse(recurse)
                # FIXME sourcerecurse should support purging non-remote files
                source = @states[:source].source
                
                sourceobj, path = uri2obj(source)

                # we'll set this manually as necessary
                if @arghash.include?(:create)
                    @arghash.delete(:create)
                end

                # okay, we've got our source object; now we need to
                # build up a local file structure to match the remote
                # one

                server = sourceobj.server
                sum = "md5"
                if state = self.state(:checksum)
                    sum = state.checktype
                end
                r = false
                if recurse
                    unless recurse == 0
                        r = 1
                    end
                end

                ignore = @parameters[:ignore]
               
                #Puppet.warning "Listing path %s" % path.inspect
                desc = server.list(path, r, ignore)
               
                desc.split("\n").each { |line|
                    file, type = line.split("\t")
                    next if file == "/"
                    name = file.sub(/^\//, '')
                    #Puppet.warning "child name is %s" % name
                    args = {:source => source + file}
                    if type == file
                        args[:recurse] = nil
                    end
                    self.newchild(name, args)
                    #self.newchild(hash, source, recurse)
                    #hash2child(hash, source, recurse)
                }
            end

            # a wrapper method to make sure the file exists before doing anything
            def retrieve
                if @states.include?(:source)
                    @states[:source].retrieve
                end

                if @parameters.include?(:recurse)
                    self.recurse
                end

                unless stat = self.stat(true)
                    Puppet.debug "File %s does not exist" % self.name
                    @states.each { |name,state|
                        # We've already retreived the source, and we don't
                        # want to overwrite whatever it did.  This is a bit
                        # of a hack, but oh well, source is definitely special.
                        next if name == :source
                        state.is = :notfound
                    }
                    return
                end

                super
            end

            def stat(refresh = false)
                if @stat.nil? or refresh == true
                    begin
                        @stat = File.lstat(self.name)
                    rescue Errno::ENOENT => error
                        @stat = nil
                    rescue => error
                        Puppet.debug "Failed to stat %s: %s" %
                            [self.name,error]
                        @stat = nil
                    end
                end

                return @stat
            end

            def uri2obj(source)
                sourceobj = FileSource.new
                path = nil
                if source =~ /^\//
                    source = "file://localhost/%s" % source
                    sourceobj.mount = "localhost"
                    sourceobj.local = true
                end
                begin
                    uri = URI.parse(source)
                rescue => detail
                    raise Puppet::Error, "Could not understand source %s: %s" %
                        [source, detail.to_s]
                end

                case uri.scheme
                when "file":
                    unless defined? @@localfileserver
                        @@localfileserver = Puppet::Server::FileServer.new(
                            :Local => true,
                            :Mount => { "/" => "localhost" },
                            :Config => false
                        )
                        #@@localfileserver.mount("/", "localhost")
                    end
                    sourceobj.server = @@localfileserver
                    path = "/localhost" + uri.path
                when "puppet":
                    args = { :Server => uri.host }
                    if uri.port
                        args[:Port] = uri.port
                    end
                    # FIXME We should cache a copy of this server
                    #sourceobj.server = Puppet::NetworkClient.new(args)
                    sourceobj.server = Puppet::Client::FileClient.new(args)

                    tmp = uri.path
                    if tmp =~ %r{^/(\w+)}
                        sourceobj.mount = $1
                        path = tmp
                        #path = tmp.sub(%r{^/\w+},'') || "/"
                    else
                        raise Puppet::Error, "Invalid source path %s" % tmp
                    end
                else
                    raise Puppet::Error,
                        "Got other recursive file proto %s from %s" %
                            [uri.scheme, source]
                end

                return [sourceobj, path.sub(/\/\//, '/')]
            end
        end # Puppet::Type::PFile
    end # Puppet::Type

    # the filesource class can't include the path, because the path
    # changes for every file instance
    class FileSource
        attr_accessor :mount, :root, :server, :local
    end
end

# $Id$
