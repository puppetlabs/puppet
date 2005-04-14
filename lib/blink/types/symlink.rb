#!/usr/local/bin/ruby -w

# $Id$

require 'etc'
require 'blink/state'
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
                        [self.object[:path],self.should])
                    unless File.symlink(self.should,self.object[:path])
                        raise TypeError.new("Could not create symlink '%s'" %
                            self.object[:path])
                    end
                rescue => detail
                    raise TypeError.new("Cannot create symlink '%s': %s" %
                        [self.object[:path],detail])
                end
            end

            def remove
                if FileTest.symlink?(self.object[:path])
                    Blink.debug("Removing symlink '%s'" % self.object[:path])
                    begin
                        File.unlink(self.object[:path])
                    rescue
                        raise TypeError.new("Failed to remove symlink '%s'" %
                            self.object[:path])
                    end
                elsif FileTest.exists?(self.object[:path])
                    raise TypeError.new("Cannot remove normal file '%s'" %
                        self.object[:path])
                else
                    Blink.debug("Symlink '%s' does not exist" %
                        self.object[:path])
                end
            end

            def retrieve
                stat = nil

                if FileTest.symlink?(self.object[:path])
                    self.is = File.readlink(self.object[:path])
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
                    if FileTest.symlink?(self.object[:path])
                        path = File.readlink(self.object[:path])
                        if path != self.should
                            self.remove()
                            self.create()
                        end
                    elsif FileTest.exists?(self.object[:path])
                        raise TypeError.new("Cannot replace normal file '%s'" %
                            self.object[:path])
                    else
                        self.create()
                    end
                end

                self.object.newevent(:event => :inode_changed)
            end
        end
    end

    class Types
        class Symlink < Types
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
        end # Blink::Types::File
    end # Blink::Types

end
