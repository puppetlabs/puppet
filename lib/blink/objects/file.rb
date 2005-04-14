#!/usr/local/bin/ruby -w

# $Id$

require 'digest/md5'
require 'etc'
require 'blink/attribute'

module Blink
    # we first define all of the attribute that our file will use
    # because the objects must be defined for us to use them in our
    # definition of the file object
    class Attribute
        class FileUID < Blink::Attribute
            require 'etc'
            attr_accessor :file
            @name = :owner

            def retrieve
                stat = nil

                begin
                    stat = File.stat(self.object[:path])
                rescue
                    # this isn't correct, but what the hell
                    raise "File '%s' does not exist: #{$!}" % self.object[:path]
                end

                self.value = stat.uid
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
                Blink.debug "chown state is %d" % self.value
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
#                self.value <=> other
#            end

            def sync
                begin
                    File.chown(value,-1,self.object[:path])
                rescue
                    raise "failed to sync #{@params[:file]}: #{$!}"
                end

                self.object.newevent(:event => :inode_changed)
            end
        end

        # this attribute should actually somehow turn into many attributes,
        # one for each bit in the mode
        # I think MetaAttributes are the answer, but I'm not quite sure
        class FileMode < Blink::Attribute
            require 'etc'

            @name = :mode

            def retrieve
                stat = nil

                begin
                    stat = File.stat(self.object[:path])
                rescue => error
                    raise "File %s could not be stat'ed: %s" % [self.object[:path],error]
                end

                self.value = stat.mode & 007777
                Blink.debug "chmod state is %o" % self.value
            end

            def sync
                begin
                    File.chmod(self.should,self.object[:path])
                rescue
                    raise "failed to chmod #{self.object[:path]}: #{$!}"
                end
                self.object.newevent(:event => :inode_changed)
            end
        end

        # not used until I can figure out how to solve the problem with
        # metaattributes
        class FileSetUID < Blink::Attribute
            require 'etc'

            @parent = Blink::Attribute::FileMode

            @name = :setuid

            def <=>(other)
                self.value <=> @parent.value[11]
            end

            # this just doesn't seem right...
            def sync
                tmp = 0
                if self.value == true
                    tmp = 1
                end
                @parent.value[11] = tmp
            end
        end

        class FileGroup < Blink::Attribute
            require 'etc'

            @name = :group

            def retrieve
                stat = nil

                begin
                    stat = File.stat(self.object[:path])
                rescue
                    # this isn't correct, but what the hell
                    raise "File #{self.object[:path]} does not exist: #{$!}"
                end

                self.value = stat.gid

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
                Blink.debug "chgrp state is %d" % self.value
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
#                self.value <=> other
#            end

            def sync
                Blink.debug "setting chgrp state to %d" % self.should
                begin
                    # set owner to nil so it's ignored
                    File.chown(nil,self.should,self.object[:path])
                rescue
                    raise "failed to chgrp %s to %s: %s" %
                        [self.object[:path], self.should, $!]
                end
                self.object.newevent(:event => :inode_changed)
            end
        end
    end
    class Objects
        class File < Objects
            attr_reader :stat, :path, :params
            # class instance variable
            @params = [
                Blink::Attribute::FileUID,
                Blink::Attribute::FileGroup,
                Blink::Attribute::FileMode,
                Blink::Attribute::FileSetUID,
                :path
            ]

            @name = :file
            @namevar = :path
        end # Blink::Objects::File
    end # Blink::Objects

end
