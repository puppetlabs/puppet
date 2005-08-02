#!/usr/local/bin/ruby -w

# $Id$

require 'digest/md5'
require 'etc'
require 'fileutils'
require 'puppet/type/state'

module Puppet
    # we first define all of the state that our file will use
    # because the objects must be defined for us to use them in our
    # definition of the file object
    class State
        class PFileCreate < Puppet::State
            require 'etc'
            @doc = "Whether to create files that don't currently exist.
                **false**/*true*/*file*/*directory*"
            @name = :create
            @event = :file_created

            def should=(value)
                # default to just about anything meaning 'true'
                case value
                when "false", false, nil:
                    @should = false
                when "true", true, "file", "plain", /^f/:
                    @should = "file"
                when "directory", /^d/:
                    @should = "directory"
                else
                    error = Puppet::Error.new "Cannot create files of type %s" %
                        value
                    raise error
                end
            end

            def retrieve
                if stat = @parent.stat(true)
                    @is = stat.ftype
                else
                    @is = -1
                end

                #Puppet.debug "'exists' state is %s" % self.is
            end


            def sync
                event = nil
                mode = nil
                if mstate = @parent.state(:mode)
                    mode = mstate.should
                    Puppet.notice "Mode is %s" % mode
                end
                begin
                    case @should
                    when "file":
                        # just create an empty file
                        if mode
                            File.open(@parent[:path],"w", mode) {
                            }
                        else
                            File.open(@parent[:path],"w") {
                            }
                        end
                        event = :file_created
                    when "directory":
                        if mode
                            Dir.mkdir(@parent.name,mode)
                        else
                            Dir.mkdir(@parent.name)
                        end
                        event = :directory_created
                    else
                        error = Puppet::Error.new(
                            "Somehow got told to create a %s file" % @should)
                        raise error
                    end
                rescue => detail
                    error = Puppet::Error.new "Could not create %s: %s" %
                        [@should, detail]
                    raise error
                end
                return event
            end
        end

        class PFileChecksum < Puppet::State
            attr_accessor :checktype
            @doc = "How to check whether a file has changed.  **md5**/*lite-md5*/
                *time*/*mtime*"
            @name = :checksum
            @event = :file_modified

            @unmanaged = true

            def should=(value)
                @checktype = value
                state = Puppet::Storage.state(self)
                if hash = state[@parent[:path]]
                    if hash.include?(@checktype)
                        @should = hash[@checktype]
                        #Puppet.debug "Found checksum %s for %s" %
                        #    [@should,@parent[:path]]
                    else
                        #Puppet.debug "Found checksum for %s but not of type %s" %
                        #    [@parent[:path],@checktype]
                        @should = -1
                    end
                else
                    @should = -1
                    #Puppet.debug "No checksum for %s" % @parent[:path]
                end
            end

            def retrieve
                unless defined? @checktype
                    @checktype = "md5"
                end

                unless FileTest.exists?(@parent.name)
                    Puppet.info "File %s does not exist" % @parent.name
                    self.is = -1
                    return
                end

                sum = ""
                case @checktype
                when "md5", "md5lite":
                    if FileTest.directory?(@parent[:path])
                        #Puppet.info "Cannot MD5 sum directory %s" %
                        #    @parent[:path]

                        # because we cannot sum directories, just delete ourselves
                        # from the file
                        # is/should so we won't sync
                        @parent.delete(self.name)
                        return
                    else
                        begin
                            File.open(@parent[:path]) { |file|
                                text = nil
                                if @checktype == "md5"
                                    text = file.read
                                else
                                    text = file.read(512)
                                end
                                if text.nil?
                                    Puppet.info "Not checksumming empty file %s" %
                                        @parent.name
                                    sum = 0
                                else
                                    sum = Digest::MD5.hexdigest(text)
                                end
                            }
                        rescue Errno::EACCES => detail
                            Puppet.notice "Cannot checksum %s: permission denied" %
                                @parent.name
                            @parent.delete(self.class.name)
                        rescue => detail
                            Puppet.notice "Cannot checksum %s: %s" %
                                detail
                            @parent.delete(self.class.name)
                        end
                    end
                when "timestamp","mtime":
                    sum = File.stat(@parent[:path]).mtime.to_s
                when "time":
                    sum = File.stat(@parent[:path]).ctime.to_s
                end

                self.is = sum

                #Puppet.debug "checksum state is %s" % self.is
            end


            # at this point, we don't actually modify the system, we modify
            # the stored state to reflect the current state, and then kick
            # off an event to mark any changes
            def sync
                if @is.nil?
                    error = Puppet::Error.new "Checksum state for %s is somehow nil" %
                        @parent.name
                    raise error
                end

                if @is == -1
                    self.retrieve
                    #Puppet.debug "%s(%s): after refresh, is '%s'" %
                    #    [self.class.name,@parent.name,@is]

                    # if we still can't retrieve a checksum, it means that
                    # the file still doesn't exist
                    if @is == -1
                        # if they're copying, then we won't worry about the file
                        # not existing yet
                        unless @parent.state(:copy) or @parent.state(:create)
                            Puppet.warning "File %s does not exist -- cannot checksum" %
                                @parent.name
                        end
                        return nil
                    end
                end

                if self.updatesum
                    # set the @should value to the new @is value
                    # most important for testing
                    @should = @is
                    return :file_modified
                else
                    # set the @should value, because it starts out as nil
                    @should = @is
                    return nil
                end
            end

            def updatesum
                result = false
                state = Puppet::Storage.state(self)
                unless state.include?(@parent.name)
                    Puppet.debug "Initializing state hash for %s" %
                        @parent.name

                    state[@parent.name] = Hash.new
                end

                if @is == -1
                    error = Puppet::Error.new("%s has invalid checksum" %
                        @parent.name)
                    raise error
                #elsif @should == -1
                #    error = Puppet::Error.new("%s has invalid 'should' checksum" %
                #        @parent.name)
                #    raise error
                end

                # if we're replacing, vs. updating
                if state[@parent.name].include?(@checktype)
                    unless defined? @should
                        raise Puppet::Error.new(
                            ("@should is not initialized for %s, even though we " +
                            "found a checksum") % @parent[:path]
                        )
                    end
                    Puppet.debug "Replacing checksum %s with %s" %
                        [state[@parent.name][@checktype],@is]
                    #Puppet.debug "@is: %s; @should: %s" % [@is,@should]
                    result = true
                else
                    Puppet.debug "Creating checksum %s for %s of type %s" %
                        [self.is,@parent.name,@checktype]
                    result = false
                end
                state[@parent.name][@checktype] = @is
                return result
            end
        end

        class PFileUID < Puppet::State
            require 'etc'
            @doc = "To whom the file should belong.  Argument can be user name or
                user ID."
            @name = :owner
            @event = :inode_changed

            def retrieve
                # if we're not root, then we can't chown anyway
                unless Process.uid == 0
                    @parent.delete(self.name)
                    @should = nil
                    @is = nil
                    unless defined? @@notified
                        Puppet.notice "Cannot manage ownership unless running as root"
                        @@notified = true
                        return
                    end
                end

                unless stat = @parent.stat(true)
                    @is = -1
                    return
                end

                self.is = stat.uid
            end

            def should=(value)
                unless Process.uid == 0
                    @should = nil
                    @is = nil
                    unless defined? @@notified
                        Puppet.notice "Cannot manage ownership unless running as root"
                        #@parent.delete(self.name)
                        @@notified = true
                        return
                    end
                    raise Puppet::Error.new(
                        "Cannot manage ownership unless running as root"
                    )
                end
                if value.is_a?(Integer)
                    # verify the user is a valid user
                    begin
                        user = Etc.getpwuid(value)
                        if user.uid == ""
                            error = Puppet::Error.new(
                                "Could not retrieve uid for '%s'" %
                                    @parent.name)
                            raise error
                        end
                    rescue ArgumentError => detail
                        raise Puppet::Error.new("User ID %s does not exist" %
                            value
                        )
                    rescue => detail
                        raise Puppet::Error.new(
                            "Could not find user '%s': %s" % [value, detail])
                        raise error
                    end
                else
                    begin
                        user = Etc.getpwnam(value)
                        if user.uid == ""
                            error = Puppet::Error.new(
                                "Could not retrieve uid for '%s'" %
                                    @parent.name)
                            raise error
                        end
                        value = user.uid
                    rescue ArgumentError => detail
                        raise Puppet::Error.new("User %s does not exist" %
                            value
                        )
                    rescue => detail
                        error = Puppet::Error.new(
                            "Could not find user '%s': %s" % [value, detail])
                        raise error
                    end
                end

                @should = value
            end

            def sync
                unless Process.uid == 0
                    # there's a possibility that we never got retrieve() called
                    # e.g., if the file didn't exist
                    # thus, just delete ourselves now and don't do any work
                    @parent.delete(self.name)
                    return nil
                end

                if @is == -1
                    @parent.stat(true)
                    self.retrieve
                    #Puppet.debug "%s: after refresh, is '%s'" % [self.class.name,@is]
                end

                unless @parent.stat
                    Puppet.err "File '%s' does not exist; cannot chown" %
                        @parent[:path]
                end

                begin
                    File.chown(self.should,-1,@parent[:path])
                rescue => detail
                    error = Puppet::Error.new("failed to chown '%s' to '%s': %s" %
                        [@parent[:path],self.should,detail])
                    raise error
                end

                return :inode_changed
            end
        end

        # this state should actually somehow turn into many states,
        # one for each bit in the mode
        # I think MetaStates are the answer, but I'm not quite sure
        class PFileMode < Puppet::State
            require 'etc'
            @doc = "Mode the file should be.  Currently relatively limited:
                you must specify the exact mode the file should be."
            @name = :mode
            @event = :inode_changed

            def should=(should)
                # this is pretty hackish, but i need to make sure the number is in
                # octal, yet the number can only be specified as a string right now
                unless should.is_a?(Integer) # i've already converted it correctly
                    unless should =~ /^0/
                        should = "0" + should
                    end
                    should = Integer(should)
                end
                @should = should
                if FileTest.exists?(@parent.name)
                    self.dirfix
                end
            end

            def dirfix
                # if we're a directory, we need to be executable for all cases
                # that are readable
                if FileTest.directory?(@parent.name)
                    if @should & 0400
                        @should |= 0100
                    end
                    if @should & 040
                        @should |= 010
                    end
                    if @should & 04
                        @should |= 01
                    end
                end

                @fixed = true
            end

            def retrieve
                if stat = @parent.stat(true)
                    self.is = stat.mode & 007777
                    unless defined? @fixed
                        self.dirfix
                    end
                else
                    self.is = -1
                end

                #Puppet.debug "chmod state is %o" % self.is
            end

            def sync
                if @is == -1
                    @parent.stat(true)
                    self.retrieve
                    #Puppet.debug "%s: after refresh, is '%s'" % [self.class.name,@is]
                end

                unless @parent.stat
                    Puppet.err "File '%s' does not exist; cannot chmod" %
                        @parent[:path]
                    return nil
                end

                unless defined? @fixed
                    self.dirfix
                end

                begin
                    File.chmod(@should,@parent[:path])
                rescue => detail
                    error = Puppet::Error.new("failed to chmod %s: %s" %
                        [@parent.name, detail.message])
                    raise error
                end
                return :inode_changed
            end
        end

        class PFileGroup < Puppet::State
            require 'etc'
            @doc = "Which group should own the file.  Argument can be either group
                name or group ID."
            @name = :group
            @event = :inode_changed

            def retrieve
                stat = @parent.stat(true)

                self.is = stat.gid

                # we probably shouldn't actually modify the 'should' value
                # but i don't see a good way around it right now
                # mmmm, should
                #if defined? @should
                #else
                #    @parent.delete(self.name)
                #end
            end

            def should=(value)
                require 'puppet/fact'
                method = nil
                gid = nil
                gname = nil

                if value.is_a?(Integer)
                    method = :getgrgid
                else
                    method = :getgrnam
                end

                begin
                    group = Etc.send(method,value)
                    # apparently os x is six shades of weird
                    os = Puppet::Fact["Operatingsystem"]

                    case os
                    when "Darwin":
                        gid = group.passwd
                    else
                        gid = group.gid
                    end
                    gname = group.name

                    if gid.nil?
                        raise Puppet::Error.new(
                            "Could not retrieve gid for %s" % @parent.name)
                    end
                rescue ArgumentError => detail
                    raise Puppet::Error.new(
                        "Could not find group %s" % value)
                rescue => detail
                    raise Puppet::Error.new(
                        "Could not find group %s: %s" % [self.should,detail])
                end

                # now make sure the user is allowed to change to that group
                unless Process.uid == 0
                    groups = %x{groups}.chomp.split(/\s/)
                    unless groups.include?(gname)
                        Puppet.notice "Cannot chgrp: not in group %s" % gname
                        raise Puppet::Error.new(
                            "Cannot chgrp: not in group %s" % gname)
                    end
                end

                if gid.nil?
                    raise Puppet::Error.new(
                        "Nil gid for %s" % @parent.name)
                else
                    @should = gid
                end
            end

            def sync
                Puppet.debug "setting chgrp state to %s" % self.should
                if @is == -1
                    @parent.stat(true)
                    self.retrieve
                    #Puppet.debug "%s: after refresh, is '%s'" % [self.class.name,@is]
                end

                unless @parent.stat
                    Puppet.err "File '%s' does not exist; cannot chgrp" %
                        @parent[:path]
                    return nil
                end

                begin
                    # set owner to nil so it's ignored
                    File.chown(nil,self.should,@parent[:path])
                rescue => detail
                    error = Puppet::Error.new( "failed to chgrp %s to %s: %s" %
                        [@parent[:path], self.should, detail.message])
                    raise error
                end
                return :inode_changed
            end
        end

        class PFileCopy < Puppet::State
            attr_accessor :source, :local
            @doc = "Copy a file over the current file.  Uses `checksum` to
                determine when a file should be copied.  This is largely a support
                state for the `source` parameter, which is what should generally
                be used instead of `copy`."
            @name = :copy

            def retrieve
                sum = nil
                if sum = @parent.state(:checksum)
                    if sum.is
                        if sum.is == -1
                            sum.retrieve
                        end
                        @is = sum.is
                    else
                        @is = -1
                    end
                else
                    @is = -1
                end
            end

            def should=(source)
                @local = true # redundant for now
                @source = source
                type = Puppet::Type.type(:file)

                sourcesum = nil
                stat = File.stat(@source)
                case stat.ftype
                when "file":
                    unless sourcesum = type[@source].state(:checksum).is
                        raise Puppet::Error.new(
                            "Could not retrieve checksum of source %s" %
                            @source
                        )
                    end
                when "directory":
                    raise Puppet::Error.new(
                        "Somehow got told to copy dir %s" % @parent.name)
                else
                    raise Puppet::Error.new(
                        "Cannot use files of type %s as source" % stat.ftype)
                end

                @should = sourcesum
            end

            def sync
                if @is == -1
                    self.retrieve # try again
                    if @is == @should
                        return nil
                    end
                end
                @backed = false
                bak = @parent[:backup] || ".puppet-bak"

                # try backing ourself up before we overwrite
                if FileTest.file?(@parent.name)
                    if bucket = @parent[:filebucket]
                        bucket.backup(@parent.name)
                        @backed = true
                    elsif @parent[:backup]
                        # back the file up
                        begin
                            FileUtils.cp(@parent.name,
                                @parent.name + bak)
                            @backed = true
                        rescue => detail
                            # since they said they want a backup, let's error out
                            # if we couldn't make one
                            error = Puppet::Error.new("Could not back %s up: %s" %
                                [@parent.name, detail.message])
                            raise error
                        end
                    end
                end

                unless @parent[:backup]
                    @backed = true
                end

                #Puppet.notice "@is: %s; @should: %s" % [@is,@should]
                #Puppet.err "@is: %s; @should: %s" % [@is,@should]
                # okay, we've now got whatever backing up done we might need
                # so just copy the files over
                if @local
                    stat = File.stat(@source)
                    case stat.ftype
                    when "file":
                        begin
                            if FileTest.exists?(@parent.name)
                                # get the file here
                                FileUtils.cp(@source, @parent.name + ".tmp")
                                if FileTest.exists?(@parent.name + bak)
                                    Puppet.warning "Deleting backup of %s" %
                                        @parent.name
                                    File.unlink(@parent.name + bak)
                                end
                                # rename the existing one
                                File.rename(
                                    @parent.name,
                                    @parent.name + ".puppet-bak"
                                )
                                # move the new file into place
                                File.rename(
                                    @parent.name + ".tmp",
                                    @parent.name
                                )
                                # if we've made a backup, then delete the old file
                                if @backed
                                    #Puppet.err "Unlinking backup"
                                    File.unlink(@parent.name + bak)
                                #else
                                    #Puppet.err "Not unlinking backup"
                                end
                            else
                                # the easy case
                                FileUtils.cp(@source, @parent.name)
                            end
                        rescue => detail
                            # since they said they want a backup, let's error out
                            # if we couldn't make one
                            error = Puppet::Error.new("Could not copy %s to %s: %s" %
                                [@source, @parent.name, detail.message])
                            raise error
                        end
                    when "directory":
                        raise Puppet::Error.new(
                            "Somehow got told to copy directory %s" %
                                @parent.name)
                    when "link":
                        dest = File.readlink(@source)
                        Puppet::State::PFileLink.create(@dest,@parent.path)
                    else
                        raise Puppet::Error.new(
                            "Cannot use files of type %s as source" % stat.ftype)
                    end
                else
                    raise Puppet::Error.new("Somehow got a non-local source")
                end
                return :file_changed
            end
        end
    end
    class Type
        class PFile < Type
            attr_reader :params, :source, :srcbase
            @doc = "Manages local files, including setting ownership and
                permissions, and allowing creation of both files and directories."
            # class instance variable
                #Puppet::State::PFileSource,
            @states = [
                Puppet::State::PFileCreate,
                Puppet::State::PFileChecksum,
                Puppet::State::PFileCopy,
                Puppet::State::PFileUID,
                Puppet::State::PFileGroup,
                Puppet::State::PFileMode
            ]

            @parameters = [
                :path,
                :backup,
                :linkmaker,
                :recurse,
                :source,
                :filebucket
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

            @paramdoc[:source] = "Where to retrieve the contents of the files.
                Currently only supports local copying, but will eventually
                support multiple protocols for copying.  Arguments are specified
                using either a full local path or using a URI (currently only
                *file* is supported as a protocol)."

            @paramdoc[:filebucket] = "A repository for backing up files, including
                over the network.  Argument must the name of an existing
                filebucket."

            @name = :file
            @namevar = :path

            @depthfirst = false

            if Process.uid == 0
                @@pinparams = [:mode, :owner, :group, :checksum]
            else
                @@pinparams = [:mode, :group, :checksum]
            end


            def self.recursecompare(source,dest)
                if FileTest.directory?(source.name)
                    # find all of the children of our source
                    mkchilds = source.reject { |schild|
                        schild.is_a?(Puppet::State)
                    }.collect { |schild|
                        File.basename(schild.name)
                    }

                    # add them to our repository
                    dest.reject { |child|
                        child.is_a?(Puppet::State)
                    }.collect { |schild|
                        name = File.basename(child.name)
                        if mkchilds.include?(name)
                            mkchilds.delete(name)
                        end
                    }

                    # okay, now we know which ones we still need to make
                    mkchilds.each { |child|
                        Puppet.notice "Making non-existent file %s" % child
                        child = self.newchild(child)
                        child.parent = self
                    }
                end
            end

            def initialize(hash)
                @arghash = self.argclean(hash)
                @arghash.delete(self.class.namevar)

                if @arghash.include?(:source)
                    @arghash.delete(:source)
                end

                @stat = nil
                @parameters = Hash.new(false)

                # default to a string, which is true
                @parameters[:backup] = ".puppet-bak"
                @srcbase = nil
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
                if value == false or value == "false"
                    @parameters[:backup] = false
                elsif value == true or value == "true"
                    @parameters[:backup] = ".puppet-bak"
                else
                    @parameters[:backup] = value
                end
            end

            def paramfilebucket=(name)
                if bucket = Puppet::Type::PFileBucket.bucket(name)
                    @parameters[:filebucket]  = bucket
                else
                    raise Puppet::Error.new("Could not find filebucket %s" % name)
                end
            end

            def newchild(path, hash = {})
                if path =~ %r{^#{File::SEPARATOR}}
                    raise Puppet::DevError.new(
                        "Must pass relative paths to PFile#newchild()"
                    )
                else
                    path = File.join(self.name, path)
                end

                args = @arghash.dup

                args[:path] = path

                unless hash.include?(:source) # it's being manually overridden

                    if args.include?(:source)
                        #Puppet.notice "Rewriting source for %s" % path
                        name = File.basename(path)
                        dirname = args[:source]
                        #Puppet.notice "Old: %s" % args[:source]
                        #Puppet.notice "New: %s" % File.join(dirname,name)
                        if FileTest.exists?(dirname) and ! FileTest.directory?(dirname)
                            Puppet.err "Cannot make a child of %s" % dirname
                            exit
                        end
                        args[:source] = File.join(dirname,name)
                    end

                end

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

                #if @states.include?(:checksum)
                #    args[:checksum] = @states[:checksum].checktype
                #end

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
                    klass = Puppet::Type::PFile
                end
                if child = klass[path]
                    #raise "Ruh-roh"
                    args.each { |var,value|
                        next if var == :path
                        next if var == :name
                        child[var] = value
                    }
                else # create it anew
                    #notice "Creating new file with args %s" % args.inspect
                    begin
                        child = klass.new(args)
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
                if child
                    child.parent = self
                end
                return child
            end

            def newsource(path)
                # if the path is relative, then we're making a child
                if path !~ %r{^#{File::SEPARATOR}}
                    Puppet.err "Cannot use a child %s file as a source for %s" %
                        [path,self.name]
                    return nil
                end

                obj = nil
                # XXX i'm pretty sure this breaks the closure rules, doesn't it?
                # shouldn't i be looking it up through other mechanisms?
                if obj = self.class[path]
                    #Puppet.info "%s is already in memory" % @source
                    if obj.managed?
                        raise Puppet::Error.new(
                            "You cannot currently use managed files as sources;" +
                            "%s is managed" % path
                        )
                    else
                        # verify they're looking up the correct info
                        check = []
                        @@pinparams.each { |param|
                            unless obj.state(param)
                                check.push param
                            end
                        }

                        obj[:check] = check
                    end
                else # the obj does not exist yet...
                    #Puppet.info "%s is not in memory" % @source
                    args = {}

                    args[:check] = @@pinparams
                    args[:name] = @source

                    if @arghash.include?(:recurse)
                        args[:recurse] = @parameters[:recurse]
                    end

                    # if the checksum got specified...
                    if @states.include?(:checksum)
                        args[:checksum] = @states[:checksum].checktype
                    else # default to md5
                        args[:checksum] = "md5"
                    end

                    # now create the tree of objects
                    # if recursion is turned on, this will create the whole tree
                    # and we'll just pick it up as our own recursive stuff
                    begin
                        obj = self.class.new(args)
                    rescue => detail
                        Puppet.notice "Cannot copy %s: %s" % [path,detail]
                        Puppet.debug args.inspect
                        return nil
                    end
                end

                return obj
            end

            # pinning is like recursion, except that it's recursion across
            # the pinned file's tree, instead of our own
            # if recursion is turned off, then this whole thing is pretty easy
            def paramsource=(source)
                @parameters[:source] = source
                @arghash.delete(:source)
                @source = source

                # verify we support the proto
                if @source =~ /^file:\/\/(\/.+)/
                    @source = $1
                elsif @source =~ /(\w+):\/\/(\/.+)/
                    raise Puppet::Error.new("Protocol %s not supported" % $1)
                end

                # verify that the source exists
                unless FileTest.exists?(@source)
                    raise Puppet::Error.new(
                        "Files must exist to be sources; %s does not" % @source
                    )
                end

                # ...and that it's readable
                unless FileTest.readable?(@source)
                    Puppet.notice "Skipping unreadable %s" % @source
                    #raise Puppet::Error.new(
                    #    "Files must exist to be sources; %s does not" % @source
                    #)
                    return
                end

                unless @sourceobj = self.newsource(@source)
                    return
                end

                # okay, now we've got the object; retrieve its values, so we
                # can make them our 'should' values
                @sourceobj.retrieve

                @@pinparams.each { |state|
                    next if state == :checksum
                    next if Process.uid != 0 and state == :owner
                    next if Process.uid != 0 and state == :group
                    unless @states.include?(state)
                        # this copies the source's 'is' value to our 'should'
                        # but doesn't override existing settings
                        # it might be nil -- e.g., we might not be root
                        if value = @sourceobj[state]
                            self[state] = @sourceobj[state]
                        end
                    end
                }

                # now, checksum and copy kind of work in tandem
                # first, make sure we're using the same mechanisms for retrieving
                # checksums

                # we'll come out of this with a value set or through an error
                checktype = nil

                if @states.include?(:checksum) and @sourceobj.state(:checksum)
                    sourcesum = @sourceobj.state(:checksum)
                    destsum = @states[:checksum]

                    unless destsum.checktype == sourcesum.checktype
                        Puppet.warning(("Source file '%s' checksum type %s is " +
                            "incompatible with destination file '%s' checksum " +
                            "type '%s'; defaulting to md5 for both") %
                            [
                                @sourceobj.name,
                                sourcesum.checktype.inspect,
                                self.name,
                                destsum.checktype.inspect
                            ]
                        )

                        # and then, um, default to md5 for everyone?
                        unless sourcesum.checktype == "md5"
                            Puppet.warning "Changing checktype on %s to md5" %
                                @source
                            sourcesum.should = "md5"
                        end

                        unless destsum.checktype == "md5"
                            Puppet.warning "Changing checktype on %s to md5" %
                                self.name
                            destsum.should = "md5"
                        end
                        checktype = "md5"
                    end
                elsif @sourceobj.state(:checksum)
                    checktype = @sourceobj.state(:checksum).checktype
                    self[:checksum] = checktype
                elsif @states.include?(:checksum)
                    @sourceobj[:checksum] = @states[:checksum].checktype
                    checktype = @states[:checksum].checktype
                else
                    checktype = "md5"
                end

                @arghash[:checksum] = checktype

                if FileTest.directory?(@source)
                    self[:create] = "directory"

                    # now, make sure that if they've got children we model those, too
                    curchildren = {}
                    if defined? @children
                        #Puppet.info "Collecting info about existing children"
                        @children.each { |child|
                            name = File.basename(child.name)
                            curchildren[name] = child
                        }
                    end
                    @sourceobj.each { |child|
                        #Puppet.info "Looking at %s => %s" %
                        #    [@sourceobj.name, child.name]
                        if child.is_a?(Puppet::Type::PFile)
                            name = File.basename(child.name)

                            if curchildren.include?(name)
                                # the file's in both places
                                # set the source accordingly
                                curchildren[name][:source] = child.name
                            else # they have it but we don't
                                fullname = File.join(self.name, name)
                                if kid = self.newchild(name,:source => child.name)
                                    if @children.include?(kid)
                                        Puppet.notice "Child already included"
                                    else
                                        self.push kid
                                    end
                                end
                            end
                        end
                    }

                else
                    self[:copy] = @sourceobj.name
                end
            end

            def paramrecurse=(value)
                @parameters[:recurse] = value
                unless FileTest.exist?(self.name) and self.stat.directory?
                    #Puppet.info "%s is not a directory; not recursing" %
                    #    self.name
                    return
                end

                recurse = value
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

                added = []
                Dir.foreach(self.name) { |file|
                    next if file =~ /^\.\.?/ # skip . and ..
                    if child = self.newchild(file, :recurse => recurse)
                        if @children.include?(child)
                            Puppet.notice "Child already included"
                        else
                            self.push child
                            added.push file
                        end
                    end
                }

                # here's where we handle sources; it's special, because it can
                # require us to build a structure of files that don't yet exist
                if @parameters.include?(:source)
                    unless FileTest.directory?(@parameters[:source])
                        raise Puppet::Error("Cannot use file %s as a source for a dir" %
                            @parameters[:source])
                    end
                    Dir.foreach(@parameters[:source]) { |file|
                        next if file =~ /^\.\.?$/ # skip . and ..
                        unless added.include?(file)
                            Puppet.notice "Adding absent source-file %s" % file
                            if child = self.newchild(file,
                                :recurse => recurse,
                                :source => File.join(self.name, file)
                            )
                                if @children.include?(child)
                                    Puppet.notice "Child already included"
                                else
                                    self.push child
                                    added.push file
                                end
                            end
                        end
                    }
                end
            end

            # a wrapper method to make sure the file exists before doing anything
            def retrieve
                unless stat = self.stat(true)
                    Puppet.debug "File %s does not exist" % self.name
                    @states.each { |name,state|
                        state.is = -1
                    }
                    return
                end
                super
            end

            def stat(refresh = false)
                if @stat.nil? or refresh == true
                    begin
                        @stat = File.stat(self.name)
                    rescue Errno::ENOENT => error
                        #Puppet.debug "Failed to stat %s: No such file or directory" %
                        #    [self.name]
                        @stat = nil
                    rescue => error
                        Puppet.debug "Failed to stat %s: %s" %
                            [self.name,error]
                        @stat = nil
                    end
                end

                return @stat
            end
        end # Puppet::Type::PFile
    end # Puppet::Type

    class PFileSource
        attr_accessor :name

        @sources = Hash.new(nil)

        def PFileSource.[]=(name,sub)
            @sources[name] = sub
        end

        def PFileSource.[](name)
            return @sources[name]
        end

        def initialize(name)
            @name = name

            if block_given?
                yield self
            end

            PFileSource[name] = self
        end
    end
end
