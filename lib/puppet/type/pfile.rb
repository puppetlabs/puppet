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

                Puppet.debug "'exists' state is %s" % self.is
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
                        Puppet.info "Cannot MD5 sum directory %s" %
                            self.parent[:path]

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
                        Puppet.info "Cannot MD5 sum directory %s" %
                            self.parent[:path]

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

                Puppet.debug "checksum state is %s" % self.is
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
                        Puppet.warning "File %s still does not exist" % self.parent.name
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
                            "@should is not initialized for %s, even though we found a checksum" % self.parent[:path]
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
                            Puppet.debug "converting %s to integer '%d'" %
                                [@should,user.uid]
                            @should = user.uid
                        rescue => detail
                            error = Puppet::Error.new(
                                "Could not get any info on user '%s'" % @should)
                            raise error
                        end
                    end
                end

                Puppet.debug "chown state is %d" % self.is
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

                Puppet.debug "chmod state is %o" % self.is
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
                            Puppet.debug "converting %s to integer %d" %
                                [self.should,gid]
                            self.should = gid
                        rescue => detail
                            error = Puppet::Error.new(
                                "Could not get any info on group %s: %s" % self.should)
                            raise error
                        end
                    end
                end
                Puppet.debug "chgrp state is %d" % self.is
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

        class PFileSource < Puppet::State
            attr_accessor :source, :local

            @name = :source

            def localshould=(value)
                # in order to know if we need to sync, we need to compare our file's
                # checksum to the source file's checksum
                type = Puppet::Type.type(:file)
                file = nil

                @source = value
                # if the file is already being managed through some other mechanism...
                if file = type[value]
                    error = Puppet::Error.new(
                        "Cannot currently use managed files (%s) as sources" % value)
                    raise error
                else
                    self.parent.pin(@source)
                end
            end

            def retrieve
                type = Puppet::Type.type(:file)

                stat = File.stat(@source)
                case stat.ftype
                when "file":
                    @should = type[@source].state(:checksum).is || -1
                    @is = self.parent[:checksum]
                when "directory":
                    error = Puppet::Error.new(
                        "Somehow got told to create dir %s" % self.parent.name)
                    raise error
                else
                    error = Puppet::Error.new(
                        "Cannot use files of type %s as source" % stat.ftype)
                    raise error
                end
            end

            def should=(value)
                lreg = Regexp.new("^file://")
                oreg = Regexp.new("^(\s+)://")

                # if we're a local file...
                if value =~ /^\// or value =~ lreg
                    @local = true

                    # if they passed a uri instead of just a filename...
                    if value =~ lreg
                        value.sub(lreg,'')
                        unless value =~ /\//
                            error = Puppet::Error.new("Invalid file name: %s" % value)
                            raise error
                        end
                    end

                    # XXX for now, only allow files that already exist
                    unless FileTest.exist?(value)
                        Puppet.err "Cannot use non-existent file %s as source" %
                            value
                        @should = nil
                        @nil = nil
                        return nil
                    end
                elsif value =~ oreg
                    @local = false

                    # currently, we only support local sources
                    error = Puppet::Error.new("No support for proto %s" % $1)
                    raise error
                else
                    error = Puppet::Error.new("Invalid URI %s" % value)
                    raise error
                end

                # if they haven't already specified a checksum type to us, then
                # specify that we need to collect checksums and default to md5
                unless self.parent[:checksum]
                    self.parent[:checksum] = "md5"
                end

                self.localshould = value
            end

            def sync
                # this method is kind of interesting
                # we could choose to do this two ways:  either directly
                # compare and then copy over, as we currently are, or we could
                # just define a 'refresh' method for this state and let the existing
                # event mechanisms notify us when there's a change

                unless defined? @source
                    Puppet.err "No source set for %s" % self.parent.name
                    return nil
                end

                unless FileTest.exists?(@source)
                    Puppet.err "Source %s does not exist -- cannot copy to %s" %
                        [@source, self.parent.name]
                    return nil
                end

                if @should == -1
                    Puppet.warning "Trying again for source checksum"
                    type = Puppet::Type.type(:file)
                    file = nil

                    if file = type[@source]
                        @should = file.state(:checksum).is
                        if @should.nil? or @should == -1
                            error = Puppet::Error.new(
                                "Could not retrieve checksum state for %s(%s)" %
                                    [file.name,@should])
                            raise error
                        end
                    else
                        error = Puppet::Error.new("%s is somehow not managed" % @source)
                        raise error
                    end
                end

                if FileTest.file?(@source)
                    if bucket = self.parent[:filebucket]
                        bucket.backup(self.parent.name)
                    elsif str = self.parent[:backup]
                        # back the file up
                        begin
                            FileUtils.cp(self.parent.name,
                                self.parent.name + self.parent[:backup])
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
                            FileUtils.cp(@source, self.parent.name)
                        rescue => detail
                            # since they said they want a backup, let's error out
                            # if we couldn't make one
                            error = Puppet::Error.new("Could not copy %s to %s: %s" %
                                [@source, self.parent.name, detail.message])
                            raise error
                        end
                    when "directory":
                        error = Puppet::Error.new(
                            "Somehow got told to sync directory %s" %
                                self.parent.name)
                        raise error
                    when "link":
                        dest = File.readlink(@source)
                        Puppet::State::PFileLink.create(@dest,self.parent.path)
                    else
                        error = Puppet::Error.new("Cannot use files of type %s as source" %
                            stat.ftype)
                        raise error
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
            @states = [
                Puppet::State::PFileCreate,
                Puppet::State::PFileSource,
                Puppet::State::PFileUID,
                Puppet::State::PFileGroup,
                Puppet::State::PFileMode,
                Puppet::State::PFileChecksum,
                Puppet::State::PFileSetUID,
                Puppet::State::PFileLink
            ]

            @parameters = [
                :path,
                :recurse,
                :filebucket,
                :backup
            ]

            @name = :file
            @namevar = :path

            def initialize(hash)
                arghash = hash.dup
                super

                @stat = nil

                # if recursion is enabled and we're a directory...
                if @parameters[:recurse]
                    if FileTest.exist?(self.name) and self.stat.directory?
                        self.recurse(arghash)
                    elsif @states.include?(:source) # uh, yeah, uh...
                        Puppet.err "Ugh!"
                        self.recurse(arghash)
                    else
                        Puppet.err "No recursion or source for %s" % self.name
                    end
                end

                # yay, super-hack!
                if @states.include?(:create)
                    if @states[:create].should == "directory"
                        if @states.include?(:source)
                            Puppet.warning "Deleting source for directory %s" %
                                self.name
                            @states.delete(:source)
                        end

                        if @states.include?(:checksum)
                            Puppet.warning "Deleting checksum for directory %s" %
                                self.name
                            @states.delete(:checksum)
                        end
                    else
                        Puppet.info "Create is %s for %s" %
                            [@states[:create].should,self.name]
                    end
                end
            end

            # this is kind of equivalent to copying the actual file
            def pin(path)
                pinparams = [:owner, :group, :mode, :checksum]

                obj = Puppet::Type::PFile.new(
                    :name => path,
                    :check => pinparams
                )
                obj.evaluate # XXX *shudder*

                # only copy the inode and content states, not all of the metastates
                [:owner, :group, :mode].each { |state|
                    unless @states.include?(state)
                        # this copies the source's 'is' value to our 'should'
                        self[state] = obj[state]
                    end
                }

                if FileTest.directory?(path)
                    self[:create] = "directory"
                    # see amazingly crappy hack in initialize()
                    #self.delete(:source)
                    Puppet.info "Not sourcing checksum of directory %s" % path
                else
                    # checksums are, like, special
                    if @states.include?(:checksum)
                        if @states[:checksum].checktype ==
                            obj.state(:checksum).checktype
                            @states[:checksum].should = obj[:checksum]
                        else
                            Puppet.warning "Source file '%s' checksum type '%s' is incompatible with destination file '%s' checksum type '%s'; defaulting to md5 for both" %
                                [obj.name, obj.state(:checksum).checktype,
                                    self.name, self[:checksum].checktype]

                            # and then, um, default to md5 for everyone?
                            unless @source.state[:checksum].checktype == "md5"
                                Puppet.warning "Changing checktype on %s to md5" %
                                    file.name
                                @source.state[:checksum].should = "md5"
                            end

                            unless @states[:ckecksum].checktype == "md5"
                                Puppet.warning "Changing checktype on %s to md5" %
                                    self.name
                                @states[:ckecksum].should = "md5"
                            end
                        end
                    else
                        self[:checksum] = obj.state(:checksum).checktype
                        @states[:checksum].should = obj[:checksum]
                    end
                end
            end

            def recurse(arghash)
                Puppet.err "Recursing!"
                recurse = self[:recurse]
                # we might have a string, rather than a number
                if recurse.is_a?(String)
                    if recurse =~ /^[0-9]+$/
                        recurse = Integer(recurse)
                    elsif recurse =~ /^inf/ # infinite recursion
                        recurse = true
                    end
                end

                # unless we're at the end of the recursion
                if recurse != 0
                    arghash.delete("recurse")
                    if recurse.is_a?(Integer)
                        recurse -= 1 # reduce the level of recursion
                    end

                    arghash[:recurse] = recurse

                    # now make each contained file/dir a child
                    unless defined? @children
                        @children = []
                    end

                    # make sure we don't have any remaining ':name' params
                    self.nameclean(arghash)

                    Dir.foreach(self.name) { |file|
                        next if file =~ /^\.\.?/ # skip . and ..

                        arghash[:path] = File.join(self.name,file)

                        child = nil
                        # if the file already exists...
                        if child = self.class[arghash[:path]]
                            arghash.each { |var,value|
                                next if var == :path
                                child[var] = value
                            }
                        else # create it anew
                            #notice "Creating new file with args %s" %
                            #    arghash.inspect
                            child = self.class.new(arghash)
                        end
                        @children.push child
                    }
                end
            end

            # I don't currently understand the problems of dependencies in this space
            # to know how to handle having 'refresh' called here
#            def refresh
#                unless @states.include?(:source)
#                    return nil
#                end
#
#                self.pin(@states[:source].source)
#
#                self.retrieve
#            end

            # a wrapper method to make sure the file exists before doing anything
            def retrieve
                unless stat = self.stat(true)
                    Puppet.debug "File %s does not exist" % self[:path]
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
                        @stat = File.stat(self[:path])
                    rescue => error
                        Puppet.debug "Failed to stat %s: %s" %
                            [self[:path],error]
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
