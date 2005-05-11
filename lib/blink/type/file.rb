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

            def retrieve
                stat = nil

                self.is = FileTest.exist?(self.parent[:path])
                Blink.debug "exists state is %s" % self.is
            end


            def sync
                begin
                    File.open(self.path,"w") { # just create an empty file
                    }
                rescue => detail
                    raise detail
                end
                #self.parent.newevent(:event => :inode_changed)
            end
        end

        class FileUID < Blink::State
            require 'etc'
            attr_accessor :file
            @name = :owner

            def retrieve
                stat = nil

                begin
                    stat = File.stat(self.parent[:path])
                rescue
                    self.is = -1
                    Blink.debug "chown state is %d" % self.is
                    return
                end

                self.is = stat.uid
                unless self.should.is_a?(Integer)
                    begin
                        user = Etc.getpwnam(self.should)
                        if user.gid == ""
                            raise "Could not retrieve uid for '%s'" % self.parent
                        end
                        Blink.debug "converting %s to integer '%d'" %
                            [self.should,user.uid]
                        self.should = user.uid
                    rescue
                        raise "Could not get any info on user '%s'" % self.should
                    end
                end
                Blink.debug "chown state is %d" % self.is
            end

            def sync
                begin
                    stat = File.stat(self.parent[:path])
                rescue => error
                    Blink.error "File '%s' does not exist; cannot chown" %
                        self.parent[:path]
                    return
                end

                begin
                    File.chown(self.should,-1,self.parent[:path])
                rescue
                    raise "failed to sync #{self.parent[:path]}: #{$!}"
                end

                #self.parent.newevent(:event => :inode_changed)
            end
        end

        # this state should actually somehow turn into many states,
        # one for each bit in the mode
        # I think MetaStates are the answer, but I'm not quite sure
        class FileMode < Blink::State
            require 'etc'

            @name = :mode

            def initialize(should)
                # this is pretty hackish, but i need to make sure the number is in
                # octal, yet the number can only be specified as a string right now
                unless should =~ /^0/
                    should = "0" + should
                end
                should = Integer(should)
                super(should)
            end

            def retrieve
                stat = nil

                begin
                    stat = File.stat(self.parent[:path])
                    self.is = stat.mode & 007777
                rescue => error
                    # a value we know we'll never get in reality
                    self.is = -1
                    return
                end

                Blink.debug "chmod state is %o" % self.is
            end

            def sync
                begin
                    stat = File.stat(self.parent[:path])
                rescue => error
                    Blink.error "File '%s' does not exist; cannot chmod" %
                        self.parent[:path]
                    return
                end

                begin
                    File.chmod(self.should,self.parent[:path])
                rescue
                    raise "failed to chmod #{self.parent[:path]}: #{$!}"
                end
                #self.parent.newevent(:event => :inode_changed)
            end
        end

        # not used until I can figure out how to solve the problem with
        # metastates
        class FileSetUID < Blink::State
            require 'etc'

            @parent = Blink::State::FileMode

            @name = :setuid

            def <=>(other)
                self.is <=> @parent.value[11]
            end

            # this just doesn't seem right...
            def sync
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

            def retrieve
                stat = nil

                begin
                    stat = File.stat(self.parent[:path])
                rescue
                    self.is = -1
                    Blink.debug "chgrp state is %d" % self.is
                    return
                end

                self.is = stat.gid

                # we probably shouldn't actually modify the 'should' value
                # but i don't see a good way around it right now
                # mmmm, should
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
                Blink.debug "chgrp state is %d" % self.is
            end

            def sync
                Blink.debug "setting chgrp state to %d" % self.should
                begin
                    stat = File.stat(self.parent[:path])
                rescue => error
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
                #self.parent.newevent(:event => :inode_changed)
            end
        end
    end
    class Type
        class File < Type
            attr_reader :stat, :path, :params
            # class instance variable
            @states = [
                Blink::State::FileCreate,
                Blink::State::FileUID,
                Blink::State::FileGroup,
                Blink::State::FileMode,
                Blink::State::FileSetUID
            ]

            @parameters = [
                :path
            ]

            @name = :file
            @namevar = :path

            def sync
                if self.create and ! FileTest.exist?(self.path)
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
