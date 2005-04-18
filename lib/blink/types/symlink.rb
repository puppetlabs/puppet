#!/usr/local/bin/ruby -w

# $Id$

require 'etc'
require 'blink/types/state'
require 'blink/types/file'

module Blink
    # okay, how do we deal with parameters that don't have operations
    # associated with them?
    class State
        class SymlinkTarget < Blink::State
            require 'etc'
            attr_accessor :file

            @name = :target

            def create
                begin
                    Blink.debug("Creating symlink '%s' to '%s'" %
                        [self.object[:path].is,self.should])
                    unless File.symlink(self.should,self.object[:path].is)
                        raise TypeError.new("Could not create symlink '%s'" %
                            self.object[:path].is)
                    end
                rescue => detail
                    raise TypeError.new("Cannot create symlink '%s': %s" %
                        [self.object[:path].is,detail])
                end
            end

            def remove
                if FileTest.symlink?(self.object[:path].is)
                    Blink.debug("Removing symlink '%s'" % self.object[:path].is)
                    begin
                        File.unlink(self.object[:path].is)
                    rescue
                        raise TypeError.new("Failed to remove symlink '%s'" %
                            self.object[:path].is)
                    end
                elsif FileTest.exists?(self.object[:path].is)
                    raise TypeError.new("Cannot remove normal file '%s'" %
                        self.object[:path].is)
                else
                    Blink.debug("Symlink '%s' does not exist" %
                        self.object[:path].is)
                end
            end

            def retrieve
                stat = nil

                if FileTest.symlink?(self.object[:path].is)
                    self.is = File.readlink(self.object[:path].is)
                    Blink.debug("link value is '%s'" % self.is)
                    return
                else
                    self.is = nil
                    return
                end
            end

            # this is somewhat complicated, because it could exist and be
            # a file
            def sync
                if self.should.nil?
                    self.remove()
                else # it should exist and be a symlink
                    if FileTest.symlink?(self.object[:path].is)
                        path = File.readlink(self.object[:path].is)
                        if path != self.should
                            self.remove()
                            self.create()
                        end
                    elsif FileTest.exists?(self.object[:path].is)
                        raise TypeError.new("Cannot replace normal file '%s'" %
                            self.object[:path].is)
                    else
                        self.create()
                    end
                end

                self.object.newevent(:event => :inode_changed)
            end
        end
    end

    class Type
        class Symlink < Type
            attr_reader :stat, :path, :params
            # class instance variable
            @params = [
                Blink::State::FileUID,
                Blink::State::FileGroup,
                Blink::State::FileMode,
                Blink::State::SymlinkTarget,
                :path
            ]

            @name = :symlink
            @namevar = :path
        end # Blink::Type::Symlink
    end # Blink::Type

end
