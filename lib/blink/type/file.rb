#!/usr/local/bin/ruby -w

# $Id$

require 'digest/md5'
require 'etc'
require 'blink/type/state'

module Blink
    # we first define all of the state that our file will use
    # because the objects must be defined for us to use them in our
    # definition of the file object
    class State
        class FileCreate < Blink::State
            require 'etc'
            attr_accessor :file
            @name = :create
            @event = :file_created

            def retrieve
                stat = nil

                self.is = FileTest.exist?(self.parent[:path])
                Blink.debug "exists state is %s" % self.is
            end


            def sync
                begin
                    File.open(self.parent[:path],"w") { # just create an empty file
                    }
                rescue => detail
                    raise detail
                end
                return :file_created
            end
        end

        class FileUID < Blink::State
            require 'etc'
            attr_accessor :file
            @name = :owner
            @event = :inode_changed

            def retrieve
                stat = nil

                unless stat = self.parent.stat(true)
                    self.is = -1
                    Blink.debug "chown state is %d" % self.is
                    return
                end

                self.is = stat.uid
                if defined? @should
                    unless @should.is_a?(Integer)
                        begin
                            user = Etc.getpwnam(@should)
                            if user.gid == ""
                                raise "Could not retrieve uid for '%s'" % self.parent
                            end
                            Blink.debug "converting %s to integer '%d'" %
                                [@should,user.uid]
                            @should = user.uid
                        rescue
                            raise "Could not get any info on user '%s'" % @should
                        end
                    end
                end

                Blink.debug "chown state is %d" % self.is
            end

            def sync
                if @is == -1
                    self.parent.stat(true)
                    self.retrieve
                    Blink.notice "%s: after refresh, is '%s'" % [self.class.name,@is]
                end

                unless self.parent.stat
                    Blink.error "File '%s' does not exist; cannot chown" %
                        self.parent[:path]
                end

                begin
                    File.chown(self.should,-1,self.parent[:path])
                rescue => detail
                    raise "failed to chown '%s' to '%s': %s" %
                        [self.parent[:path],self.should,detail]
                end

                return :inode_changed
            end
        end

        # this state should actually somehow turn into many states,
        # one for each bit in the mode
        # I think MetaStates are the answer, but I'm not quite sure
        class FileMode < Blink::State
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
                stat = nil

                unless stat = self.parent.stat(true)
                    # a value we know we'll never get in reality
                    self.is = -1
                    return
                end
                self.is = stat.mode & 007777

                Blink.debug "chmod state is %o" % self.is
            end

            def sync
                if @is == -1
                    self.parent.stat(true)
                    self.retrieve
                    Blink.notice "%s: after refresh, is '%s'" % [self.class.name,@is]
                end

                unless self.parent.stat
                    Blink.error "File '%s' does not exist; cannot chmod" %
                        self.parent[:path]
                    return
                end

                begin
                    File.chmod(self.should,self.parent[:path])
                rescue
                    raise "failed to chmod #{self.parent[:path]}: #{$!}"
                end
                return :inode_changed
            end
        end

        # not used until I can figure out how to solve the problem with
        # metastates
        class FileSetUID < Blink::State
            require 'etc'

            @parent = Blink::State::FileMode

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
                    Blink.notice "%s: should is '%s'" % [self.class.name,self.should]
                end
                tmp = 0
                if self.is == true
                    tmp = 1
                end
                @parent.value[11] = tmp
            end
        end

        class FileGroup < Blink::State
            require 'etc'

            @name = :group
            @event = :inode_changed

            def retrieve
                stat = nil

                unless stat = self.parent.stat(true)
                    self.is = -1
                    Blink.debug "chgrp state is %d" % self.is
                    return
                end

                self.is = stat.gid

                # we probably shouldn't actually modify the 'should' value
                # but i don't see a good way around it right now
                # mmmm, should
                if defined? @should
                    unless self.should.is_a?(Integer)
                        begin
                            group = Etc.getgrnam(self.should)
                            # yeah, don't ask me
                            # this is retarded
                            #p group
                            if group.gid == ""
                                raise "Could not retrieve gid for %s" % self.parent
                            end
                            Blink.debug "converting %s to integer %d" %
                                [self.should,group.gid]
                            self.should = group.gid
                        rescue
                            raise "Could not get any info on group %s" % self.should
                        end
                    end
                end
                Blink.debug "chgrp state is %d" % self.is
            end

            def sync
                Blink.debug "setting chgrp state to %s" % self.should
                if @is == -1
                    self.parent.stat(true)
                    self.retrieve
                    Blink.notice "%s: after refresh, is '%s'" % [self.class.name,@is]
                end

                unless self.parent.stat
                    Blink.error "File '%s' does not exist; cannot chgrp" %
                        self.parent[:path]
                    return
                end

                begin
                    # set owner to nil so it's ignored
                    File.chown(nil,self.should,self.parent[:path])
                rescue
                    raise "failed to chgrp %s to %s: %s" %
                        [self.parent[:path], self.should, $!]
                end
                return :inode_changed
            end
        end
    end
    class Type
        class File < Type
            attr_reader :params
            # class instance variable
            @states = [
                Blink::State::FileCreate,
                Blink::State::FileUID,
                Blink::State::FileGroup,
                Blink::State::FileMode,
                Blink::State::FileSetUID
            ]

            @parameters = [
                :path,
                :recurse
            ]

            @name = :file
            @namevar = :path

            def stat(refresh = false)
                if @stat.nil? or refresh == true
                    begin
                        @stat = ::File.stat(self[:path])
                    rescue => error
                        Blink.debug "Failed to stat %s: %s" %
                            [self[:path],error]
                        @stat = nil
                    end
                end

                return @stat
            end

            def initialize(hash)
                arghash = hash.dup
                super
                @stat = nil

                # if recursion is enabled and we're a directory...
                if @parameters[:recurse] and self.stat.directory?
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

                        Dir.foreach(self[:path]) { |file|
                            next if file =~ /^\.\.?/ # skip . and ..

                            arghash[:path] = ::File.join(self[:path],file)

                            # if one of these files already exists, we're going to
                            # fail here, because this will try to clobber, which is bad
                            # mmmkay
                            #@children.push self.class.new(arghash)
                            child = nil
                            # if the file already exists...
                            if child = self.class[arghash[:path]]
                                arghash.each { |var,value|
                                    next if var == :path
                                    child[var] = value
                                }
                            else # create it anew
                                child = self.class.new(arghash)
                            end
                            @children.push child
                        }
                    end
                end
            end

            def sync
                if @states[:create] and ! FileTest.exist?(self.path)
                    begin
                        File.open(self.path,"w") { # just create an empty file
                        }
                    rescue => detail
                        raise detail
                    end
                end
                super
            end
        end # Blink::Type::File
    end # Blink::Type

end
