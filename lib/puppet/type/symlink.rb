#!/usr/local/bin/ruby -w

# $Id$

require 'etc'
require 'puppet/type/state'
require 'puppet/type/file'

module Puppet
    # okay, how do we deal with parameters that don't have operations
    # associated with them?
    class State
        class SymlinkTarget < Puppet::State
            require 'etc'
            attr_accessor :file

            @name = :target

            def create
                begin
                    Puppet.debug("Creating symlink '%s' to '%s'" %
                        [self.parent[:path],self.should])
                    unless File.symlink(self.should,self.parent[:path])
                        raise TypeError.new("Could not create symlink '%s'" %
                            self.parent[:path])
                    end
                rescue => detail
                    raise TypeError.new("Cannot create symlink '%s': %s" %
                        [self.parent[:path],detail])
                end
            end

            def remove
                if FileTest.symlink?(self.parent[:path])
                    Puppet.debug("Removing symlink '%s'" % self.parent[:path])
                    begin
                        File.unlink(self.parent[:path])
                    rescue
                        raise TypeError.new("Failed to remove symlink '%s'" %
                            self.parent[:path])
                    end
                elsif FileTest.exists?(self.parent[:path])
                    raise TypeError.new("Cannot remove normal file '%s'" %
                        self.parent[:path])
                else
                    Puppet.debug("Symlink '%s' does not exist" %
                        self.parent[:path])
                end
            end

            def retrieve
                stat = nil

                if FileTest.symlink?(self.parent[:path])
                    self.is = File.readlink(self.parent[:path])
                    Puppet.debug("link value is '%s'" % self.is)
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
                    if FileTest.symlink?(self.parent[:path])
                        path = File.readlink(self.parent[:path])
                        if path != self.should
                            self.remove()
                            self.create()
                        end
                    elsif FileTest.exists?(self.parent[:path])
                        raise TypeError.new("Cannot replace normal file '%s'" %
                            self.parent[:path])
                    else
                        self.create()
                    end
                end

                #self.parent.newevent(:event => :inode_changed)
            end
        end
    end

    class Type
        class Symlink < Type
            attr_reader :stat, :path, :params
            # class instance variable
            @states = [
                Puppet::State::FileUID,
                Puppet::State::FileGroup,
                Puppet::State::FileMode,
                Puppet::State::SymlinkTarget
            ]

            @parameters = [
                :path
            ]

            @name = :symlink
            @namevar = :path
        end # Puppet::Type::Symlink
    end # Puppet::Type

end
