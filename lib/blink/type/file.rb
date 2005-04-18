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
        class FileUID < Blink::State
            require 'etc'
            attr_accessor :file
            @name = :owner

            def retrieve
                stat = nil

                begin
                    stat = File.stat(self.object[:path].is)
                rescue
                    # this isn't correct, but what the hell
                    raise "File '%s' does not exist: #{$!}" % self.object[:path].is
                end

                self.is = stat.uid
                unless self.should.is_a?(Integer)
                    begin
                        user = Etc.getpwnam(self.should)
                        if user.gid == ""
                            raise "Could not retrieve uid for %s" % self.object
                        end
                        Blink.debug "converting %s to integer %d" %
                            [self.should,user.uid]
                        self.should = user.uid
                    rescue
                        raise "Could not get any info on user %s" % self.should
                    end
                end
                Blink.debug "chown state is %d" % self.is
            end

            #def <=>(other)
            #    if other.is_a?(Integer)
            #        begin
            #            other = Etc.getpwnam(other).uid
            #        rescue
            #            raise "Could not get uid for #{@params[:uid]}"
            #        end
            #    end
#
#                self.is <=> other
#            end

            def sync
                begin
                    File.chown(self.should,-1,self.object[:path].is)
                rescue
                    raise "failed to sync #{self.object[:path].is}: #{$!}"
                end

                self.object.newevent(:event => :inode_changed)
            end
        end

        # this state should actually somehow turn into many states,
        # one for each bit in the mode
        # I think MetaStates are the answer, but I'm not quite sure
        class FileMode < Blink::State
            require 'etc'

            @name = :mode

            def retrieve
                stat = nil

                begin
                    stat = File.stat(self.object[:path].is)
                rescue => error
                    raise "File %s could not be stat'ed: %s" % [self.object[:path].is,error]
                end

                self.is = stat.mode & 007777
                Blink.debug "chmod state is %o" % self.is
            end

            def sync
                begin
                    File.chmod(self.should,self.object[:path].is)
                rescue
                    raise "failed to chmod #{self.object[:path].is}: #{$!}"
                end
                self.object.newevent(:event => :inode_changed)
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
                    stat = File.stat(self.object[:path].is)
                rescue
                    # this isn't correct, but what the hell
                    raise "File #{self.object[:path].is} does not exist: #{$!}"
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
                            raise "Could not retrieve gid for %s" % self.object
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

#            def <=>(other)
#                # unless we're numeric...
#                if other.is_a?(Integer)
#                    begin
#                        group = Etc.getgrnam(other)
#                        # yeah, don't ask me
#                        # this is retarded
#                        #p group
#                        other = group.gid
#                        if other == ""
#                            raise "Could not retrieve gid for %s" % other
#                        end
#                    rescue
#                        raise "Could not get any info on group %s" % other
#                    end
#                end
#
#                #puts self.should
#                self.is <=> other
#            end

            def sync
                Blink.debug "setting chgrp state to %d" % self.should
                begin
                    # set owner to nil so it's ignored
                    File.chown(nil,self.should,self.object[:path].is)
                rescue
                    raise "failed to chgrp %s to %s: %s" %
                        [self.object[:path].is, self.should, $!]
                end
                self.object.newevent(:event => :inode_changed)
            end
        end
    end
    class Type
        class File < Type
            attr_reader :stat, :path, :params
            # class instance variable
            @params = [
                Blink::State::FileUID,
                Blink::State::FileGroup,
                Blink::State::FileMode,
                Blink::State::FileSetUID,
                :path
            ]

            @name = :file
            @namevar = :path
        end # Blink::Type::File
    end # Blink::Type

end
