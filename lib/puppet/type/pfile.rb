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
                if stat = self.parent.stat(true)
                    @is = stat.ftype
                else
                    @is = -1
                end

                #Puppet.debug "'exists' state is %s" % self.is
            end


            def sync
                if defined? @synced
                    Puppet.err "We've already been synced?"
                end
                event = nil
                begin
                    case @should
                    when "file":
                        File.open(self.parent[:path],"w") { # just create an empty file
                        }
                        event = :file_created
                    when "directory":
                        Dir.mkdir(self.parent.name)
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
                @synced = true
                return event
            end
        end

        class PFileChecksum < Puppet::State
            attr_accessor :checktype

            @name = :checksum
            @event = :file_modified

            def should=(value)
                @checktype = value
                state = Puppet::Storage.state(self)
                if hash = state[self.parent[:path]]
                    if hash.include?(@checktype)
                        @should = hash[@checktype]
                        Puppet.debug "Found checksum %s for %s" %
                            [@should,self.parent[:path]]
                    else
                        Puppet.debug "Found checksum for %s but not of type %s" %
                            [self.parent[:path],@checktype]
                        @should = nil
                    end
                else
                    Puppet.debug "No checksum for %s" % self.parent[:path]
                end
            end

            def retrieve
                unless defined? @checktype
                    @checktype = "md5"
                end

                unless FileTest.exists?(self.parent.name)
                    Puppet.info "File %s does not exist" % self.parent.name
                    self.is = -1
                    return
                end

                sum = ""
                case @checktype
                when "md5":
                    if FileTest.directory?(self.parent[:path])
                        #Puppet.info "Cannot MD5 sum directory %s" %
                        #    self.parent[:path]

                        # because we cannot sum directories, just delete ourselves
                        # from the file
                        # is/should so we won't sync
                        self.parent.delete(self.name)
                        return
                    else
                        File.open(self.parent[:path]) { |file|
                            sum = Digest::MD5.hexdigest(file.read)
                        }
                    end
                when "md5lite":
                    if FileTest.directory?(self.parent[:path])
                        #Puppet.info "Cannot MD5 sum directory %s" %
                        #    self.parent[:path]

                        # because we cannot sum directories, just delete ourselves
                        # from the file
                        # is/should so we won't sync
                        return
                    else
                        File.open(self.parent[:path]) { |file|
                            text = file.read(512)
                            if text.nil?
                                Puppet.info "Not checksumming empty file %s" %
                                    self.parent.name
                                sum = 0
                            else
                                sum = Digest::MD5.hexdigest(text)
                            end
                        }
                    end
                when "timestamp","mtime":
                    sum = File.stat(self.parent[:path]).mtime.to_s
                when "time":
                    sum = File.stat(self.parent[:path]).ctime.to_s
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
                        self.parent.name
                    raise error
                end

                if @is == -1
                    self.retrieve
                    Puppet.debug "%s(%s): after refresh, is '%s'" %
                        [self.class.name,self.parent.name,@is]

                    # if we still can't retrieve a checksum, it means that
                    # the file still doesn't exist
                    if @is == -1
                        Puppet.warning "File %s does not exist -- cannot checksum" %
                            self.parent.name
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
                unless state.include?(self.parent.name)
                    Puppet.debug "Initializing state hash for %s" %
                        self.parent.name

                    state[self.parent.name] = Hash.new
                end

                if @is == -1
                    error = Puppet::Error.new("%s has invalid checksum" %
                        self.parent.name)
                    raise error
                #elsif @should == -1
                #    error = Puppet::Error.new("%s has invalid 'should' checksum" %
                #        self.parent.name)
                #    raise error
                end

                # if we're replacing, vs. updating
                if state[self.parent.name].include?(@checktype)
                    unless defined? @should
                        raise Puppet::Error.new(
                            ("@should is not initialized for %s, even though we " +
                            "found a checksum") % self.parent[:path]
                        )
                    end
                    Puppet.debug "Replacing checksum %s with %s" %
                        [state[self.parent.name][@checktype],@is]
                    Puppet.debug "@is: %s; @should: %s" % [@is,@should]
                    result = true
                else
                    Puppet.debug "Creating checksum %s for %s of type %s" %
                        [self.is,self.parent.name,@checktype]
                    result = false
                end
                state[self.parent.name][@checktype] = @is
                return result
            end
        end

        class PFileLink < Puppet::State
            require 'etc'
            attr_reader :link

            @name = :link

            # create the link
            def self.create(file,link)
                begin
                    Puppet.debug("Creating symlink '%s' to '%s'" % [file, link])
                    unless File.symlink(file,link)
                        raise Puppet::Error.new(
                            "Could not create symlink '%s'" % link
                        )
                    end
                rescue => detail
                    raise Puppet::Error.new(
                        "Cannot create symlink '%s': %s" % [file,detail]
                    )
                end
            end

            # remove an existing link
            def self.remove(link)
                if FileTest.symlink?(link)
                    Puppet.debug("Removing symlink '%s'" % link)
                    begin
                        File.unlink(link)
                    rescue
                        raise Puppet::Error.new(
                            "Failed to remove symlink '%s'" % link
                        )
                    end
                elsif FileTest.exists?(link)
                    error = Puppet::Error.new(
                        "Cannot remove normal file '%s'" % link)
                    raise error
                else
                    Puppet.debug("Symlink '%s' does not exist" % link)
                end
            end

            def retrieve
                if FileTest.symlink?(@link)
                    self.is = File.readlink(@link)
                    return
                else
                    self.is = nil
                    return
                end
            end

            # we know the link should exist, but it should also point back
            # to us
            def should=(link)
                @link = link
                @should = self.parent[:path]

                # unless we're fully qualified or we've specifically allowed
                # relative links.  Relative links are currently disabled, until
                # someone actually asks for them
                #unless @should =~ /^\// or self.parent[:relativelinks]
                unless @should =~ /^\//
                    @should = File.expand_path @should
                end
            end

            # this is somewhat complicated, because it could exist and be
            # a file
            def sync
                if @is
                    self.class.remove(@is)
                end
                self.class.create(@should,@link)

                return :link_created
            end
        end

        class PFileUID < Puppet::State
            require 'etc'
            @name = :owner
            @event = :inode_changed

            def retrieve
                unless stat = self.parent.stat(true)
                    @is = -1
                    return
                end

                self.is = stat.uid
                if defined? @should
                    unless @should.is_a?(Integer)
                        begin
                            user = Etc.getpwnam(@should)
                            if user.gid == ""
                                error = Puppet::Error.new(
                                    "Could not retrieve uid for '%s'" %
                                        self.parent.name)
                                raise error
                            end
                            #Puppet.debug "converting %s to integer '%d'" %
                            #    [@should,user.uid]
                            @should = user.uid
                        rescue => detail
                            error = Puppet::Error.new(
                                "Could not get any info on user '%s'" % @should)
                            raise error
                        end
                    end
                end

                #Puppet.debug "chown state is %d" % self.is
            end

            def sync
                if @is == -1
                    self.parent.stat(true)
                    self.retrieve
                    Puppet.debug "%s: after refresh, is '%s'" % [self.class.name,@is]
                end

                unless self.parent.stat
                    Puppet.err "PFile '%s' does not exist; cannot chown" %
                        self.parent[:path]
                end

                begin
                    File.chown(self.should,-1,self.parent[:path])
                rescue => detail
                    error = Puppet::Error.new("failed to chown '%s' to '%s': %s" %
                        [self.parent[:path],self.should,detail])
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
            end

            def retrieve
                stat = self.parent.stat(true)
                self.is = stat.mode & 007777

                #Puppet.debug "chmod state is %o" % self.is
            end

            def sync
                if @is == -1
                    self.parent.stat(true)
                    self.retrieve
                    Puppet.debug "%s: after refresh, is '%s'" % [self.class.name,@is]
                end

                unless self.parent.stat
                    Puppet.err "PFile '%s' does not exist; cannot chmod" %
                        self.parent[:path]
                    return
                end

                begin
                    File.chmod(self.should,self.parent[:path])
                rescue => detail
                    error = Puppet::Error.new("failed to chmod %s: %s" %
                        [self.parent.name, detail.message])
                    raise error
                end
                return :inode_changed
            end
        end

        # not used until I can figure out how to solve the problem with
        # metastates
        class PFileSetUID < Puppet::State
            require 'etc'

            @parent = Puppet::State::PFileMode

            @name = :setuid
            @event = :inode_changed

            def <=>(other)
                self.is <=> @parent.value[11]
            end

            # this just doesn't seem right...
            def sync
                unless defined? @is or @is == -1
                    self.parent.stat(true)
                    self.retrieve
                    Puppet.debug "%s: should is '%s'" % [self.class.name,self.should]
                end
                tmp = 0
                if self.is == true
                    tmp = 1
                end
                @parent.value[11] = tmp
                return :inode_changed
            end
        end

        class PFileGroup < Puppet::State
            require 'etc'

            @name = :group
            @event = :inode_changed

            def retrieve
                stat = self.parent.stat(true)

                self.is = stat.gid

                # we probably shouldn't actually modify the 'should' value
                # but i don't see a good way around it right now
                # mmmm, should
                if defined? @should
                    unless self.should.is_a?(Integer)
                        begin
                            require 'puppet/fact'
                            group = Etc.getgrnam(self.should)
                            # apparently os x is six shades of weird
                            os = Puppet::Fact["Operatingsystem"]

                            gid = ""
                            case os
                            when "Darwin":
                                gid = group.passwd
                            else
                                gid = group.gid
                            end
                            if gid == ""
                                error = Puppet::Error.new(
                                    "Could not retrieve gid for %s" % self.parent.name)
                                raise error
                            end
                            #Puppet.debug "converting %s to integer %d" %
                            #    [self.should,gid]
                            self.should = gid
                        rescue => detail
                            error = Puppet::Error.new(
                                "Could not get any info on group %s: %s" % self.should)
                            raise error
                        end
                    end
                end
                #Puppet.debug "chgrp state is %d" % self.is
            end

            def sync
                Puppet.debug "setting chgrp state to %s" % self.should
                if @is == -1
                    self.parent.stat(true)
                    self.retrieve
                    Puppet.debug "%s: after refresh, is '%s'" % [self.class.name,@is]
                end

                unless self.parent.stat
                    Puppet.err "PFile '%s' does not exist; cannot chgrp" %
                        self.parent[:path]
                    return
                end

                begin
                    # set owner to nil so it's ignored
                    File.chown(nil,self.should,self.parent[:path])
                rescue => detail
                    error = Puppet::Error.new( "failed to chgrp %s to %s: %s" %
                        [self.parent[:path], self.should, detail.message])
                    raise error
                end
                return :inode_changed
            end
        end

        class PFileCopy < Puppet::State
            attr_accessor :source, :local

            @name = :copy

            def retrieve
                sum = nil
                unless sum = self.parent.state(:checksum)
                    raise Puppet::Error.new(
                        "Cannot copy without knowing the sum state of %s" %
                        self.parent.path
                    )
                end
                @is = sum.is
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
                    error = Puppet::Error.new(
                        "Somehow got told to copy dir %s" % self.parent.name)
                    raise error
                else
                    error = Puppet::Error.new(
                        "Cannot use files of type %s as source" % stat.ftype)
                    raise error
                end

                @should = sourcesum
            end

            def sync
                @backed = false
                # try backing ourself up before we overwrite
                if FileTest.file?(self.parent.name)
                    if bucket = self.parent[:filebucket]
                        bucket.backup(self.parent.name)
                        @backed = true
                    elsif str = self.parent[:backup]
                        # back the file up
                        begin
                            FileUtils.cp(self.parent.name,
                                self.parent.name + self.parent[:backup])
                            @backed = true
                        rescue => detail
                            # since they said they want a backup, let's error out
                            # if we couldn't make one
                            error = Puppet::Error.new("Could not back %s up: %s" %
                                [self.parent.name, detail.message])
                            raise error
                        end
                    end
                end

                # okay, we've now got whatever backing up done we might need
                # so just copy the files over
                if @local
                    stat = File.stat(@source)
                    case stat.ftype
                    when "file":
                        begin
                            if FileTest.exists?(self.parent.name)
                                # get the file here
                                FileUtils.cp(@source, self.parent.name + ".tmp")
                                if FileTest.exists?(self.parent.name + ".puppet-bak")
                                    Puppet.warning "Deleting backup of %s" %
                                        self.parent.name
                                    File.unlink(self.parent.name + ".puppet-bak")
                                end
                                # rename the existing one
                                File.rename(
                                    self.parent.name,
                                    self.parent.name + ".puppet-bak"
                                )
                                # move the new file into place
                                File.rename(
                                    self.parent.name + ".tmp",
                                    self.parent.name
                                )
                                # if we've made a backup, then delete the old file
                                if @backed
                                    File.unlink(self.parent.name + ".puppet-bak")
                                end
                            else
                                # the easy case
                                FileUtils.cp(@source, self.parent.name)
                            end
                        rescue => detail
                            # since they said they want a backup, let's error out
                            # if we couldn't make one
                            error = Puppet::Error.new("Could not copy %s to %s: %s" %
                                [@source, self.parent.name, detail.message])
                            raise error
                        end
                    when "directory":
                        raise Puppet::Error.new(
                            "Somehow got told to copy directory %s" %
                                self.parent.name)
                    when "link":
                        dest = File.readlink(@source)
                        Puppet::State::PFileLink.create(@dest,self.parent.path)
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
            attr_reader :params, :source

            # class instance variable
                #Puppet::State::PFileSource,
            @states = [
                Puppet::State::PFileCreate,
                Puppet::State::PFileCopy,
                Puppet::State::PFileChecksum,
                Puppet::State::PFileUID,
                Puppet::State::PFileGroup,
                Puppet::State::PFileMode,
                Puppet::State::PFileSetUID,
                Puppet::State::PFileLink
            ]

            @parameters = [
                :path,
                :source,
                :recurse,
                :filebucket,
                :backup
            ]

            @name = :file
            @namevar = :path

            @depthfirst = false

            def initialize(hash)
                @arghash = self.argclean(hash)
                @arghash.delete(self.class.namevar)

                @stat = nil
                super
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
                        Puppet.notice "Rewriting source for %s" % path
                        name = File.basename(path)
                        dirname = args[:source]
                        Puppet.notice "Old: %s" % args[:source]
                        Puppet.notice "New: %s" % File.join(dirname,name)
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

                child = nil
                if child = self.class[path]
                    args.each { |var,value|
                        next if var == :path
                        next if var == :name
                        child[var] = value
                    }
                else # create it anew
                    #notice "Creating new file with args %s" % args.inspect
                    begin
                        child = self.class.new(args)
                    rescue Puppet::Error => detail
                        Puppet.notice(
                            "Cannot manage %s: %s" %
                                [path,detail.message]
                        )
                        Puppet.debug args.inspect
                        puts detail.stack
                        child = nil
                    rescue => detail
                        Puppet.notice(
                            "Cannot manage %s: %s" %
                                [path,detail]
                        )
                        Puppet.debug args.inspect
                        Puppet.err detail.class
                        child = nil
                    end
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

                pinparams = [:mode, :owner, :group, :checksum]

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
                        pinparams.each { |param|
                            unless obj.state(param)
                                check.push param
                            end
                        }

                        obj[:check] = check
                    end
                else # the obj does not exist yet...
                    #Puppet.info "%s is not in memory" % @source
                    args = {}

                    args[:check] = pinparams
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
                if File.basename(File.dirname(self.name)) =~ /^[a-z]/
                    raise Puppet::Error.new("Somehow got lower-case directory")
                end
                @parameters[:source] = source
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

                # Check whether we'll be creating the file or whether it already
                # exists.  The root of the destination tree will cause the
                # recursive creation of all of the objects, and then all the
                # children of the tree will just pull existing objects
                unless @sourceobj = self.newsource(@source)
                    return
                end

                # okay, now we've got the object; retrieve its values, so we
                # can make them our 'should' values
                @sourceobj.retrieve

                # if the pin states, these can be done easily
                [:owner, :group, :mode].each { |state|
                    unless @states.include?(state)
                        # this copies the source's 'is' value to our 'should'
                        # but doesn't override existing settings
                        self[state] = @sourceobj[state]
                    end
                }

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

                            if curchildren.include?(name) # the file's in both places
                                # set the source accordingly
                                #Puppet.info "Adding %s as an existing child" % name
                                curchildren[name][:source] = child.name
                            else # they have it but we don't
                                #Puppet.info "Adding %s as a new child" % child.name
                                fullname = File.join(self.name, name)

                                if FileTest.exists?(self.name) and ! FileTest.directory?(self.name)
                                    Puppet.err "Source: %s" % @source
                                    Puppet.err "Dest: %s" % self.name
                                    Puppet.err "Child: %s" % name
                                    Puppet.err "Child: %s" % child.name
                                    caller
                                    exit
                                end
                                if kid = self.newchild(name,:source => child.name)
                                    self.push kid
                                end
                            end
                        end
                    }

                else
                    # checksums are, like, special
                    if @states.include?(:checksum) and @sourceobj.state(:checksum)
                        sourcesum = @sourceobj.state(:checksum)
                        destsum = @states[:checksum]

                        # this is weird, because normally setting a 'should' state
                        # on checksums just manipulates the contents of the state
                        # database
                        begin
                        if destsum.checktype == sourcesum.checktype
                            destsum.should = sourcesum.is
                        else
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
                                    file.name
                                sourcesum.should = "md5"
                            end

                            unless destsum.checktype == "md5"
                                Puppet.warning "Changing checktype on %s to md5" %
                                    self.name
                                destsum.should = "md5"
                            end
                        end
                        rescue => detail
                            Puppet.err detail
                            exit
                        end
                    else
                        self[:check] = [:checksum]
                        #self[:checksum] = @sourceobj.state(:checksum).checktype
                        #@states[:checksum].should = @sourceobj[:checksum]
                    end

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
                Dir.foreach(self.name) { |file|
                    next if file =~ /^\.\.?/ # skip . and ..
                    # XXX it's right here
                    if child = self.newchild(file, :recurse => recurse)
                        self.push child
                    end
                }
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
