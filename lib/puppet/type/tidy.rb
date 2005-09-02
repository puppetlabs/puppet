#!/usr/local/bin/ruby -w

# $Id$

require 'etc'
require 'puppet/type/state'
require 'puppet/type/pfile'

module Puppet
    # okay, how do we deal with parameters that don't have operations
    # associated with them?
    class State
        class TidyUp < Puppet::State
            require 'etc'
            attr_accessor :file

            @doc = "Create a link to another file.  Currently only symlinks
                are supported, and attempts to replace normal files with
                links will currently fail, while existing but incorrect symlinks
                will be removed."
            @name = :target

            def create
                begin
                    debug("Creating symlink '%s' to '%s'" %
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
                    debug("Removing symlink '%s'" % self.parent[:path])
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
                    debug("Symlink '%s' does not exist" %
                        self.parent[:path])
                end
            end

            def retrieve
                stat = nil

                if FileTest.symlink?(self.parent[:path])
                    self.is = File.readlink(self.parent[:path])
                    debug("link value is '%s'" % self.is)
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
        class Tidy < PFile

            # class instance variable
            @states = [
                Puppet::State::TidyUp
            ]

            @parameters = [
                :age,
                :size,
                :type,
                :backup,
                :recurse
            ]

            @paramdoc[:age] = "Tidy files whose age is equal to or greater than
                the specified number of days."
            @paramdoc[:size] = "Tidy files whose size is equal to or greater than
                the specified size.  Unqualified values are in kilobytes, but
                *b*, *k*, and *m* can be appended to specify *bytes*, *kilobytes*,
                and *megabytes*, respectively.  Only the first character is
                significant, so the full word can also be used."
            @paramdoc[:type] = "Set the mechanism for determining age.  Access
                time is the default mechanism, but modification."
            @paramdoc[:recurse] = "If target is a directory, recursively descend
                into the directory looking for files to tidy."
            @doc = "Remove unwanted files based on specific criteria."
            @name = :tidy
            @namevar = :path

            def initialize(hash)
                super
            end

            def paramage=(age)
                @parameters[:age] = age
            end

        end # Puppet::Type::Symlink
    end # Puppet::Type
end
