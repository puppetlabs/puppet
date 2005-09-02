#!/usr/local/bin/ruby -w

# $Id$

require 'etc'
require 'puppet/type/state'
require 'puppet/type/pfile'

module Puppet
    # okay, how do we deal with parameters that don't have operations
    # associated with them?
    class State
        class SymlinkTarget < Puppet::State
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
        class Symlink < Type
            attr_reader :stat, :path, :params
            # class instance variable
            @states = [
                Puppet::State::SymlinkTarget
            ]

            @parameters = [
                :path,
                :recurse
            ]

            @paramdoc[:path] = "Path of link to create."
            @paramdoc[:recurse] = "If target is a directory, recursively create
                directories (using `file`'s `source` parameter) and link all
                contained files."
            @doc = "Create symbolic links to existing files."
            @name = :symlink
            @namevar = :path

            def initialize(hash)
                @arghash = self.argclean(hash.dup)
                @arghash.delete(self.class.namevar)

                super
            end

            def paramrecurse=(value)
                @stat = nil
                @target = self.state(:target).should

                # we want to remove our state, because we're creating children
                # to do the links
                if FileTest.exist?(@target)
                    @stat = File.stat(@target)
                else
                    Puppet.info "Target %s must exist for recursive links" %
                        @target
                    return
                end

                # if we're a directory, then we descend into it; we only actually
                # link to real files
                unless @stat.directory?
                    return
                end

                self.delete(:target)

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

                # okay, we're not going to recurse ourselves here; instead, we're
                # going to rely on the fact that we've already got all of that
                # working in pfile

                args = {
                    :name => self.name,
                    :linkmaker => true,
                    :recurse => recurse,
                    :source => @target
                }

                dir = Puppet::Type::PFile.new(args)
                dir.parent = self
                Puppet.debug "Got dir %s" % dir.name
                self.push dir
                #Dir.foreach(@target) { |file|
                #    next if file =~ /^\.\.?$/ # skip . and ..
                #    newtarget = File.join(@target,file)
                #    #stat = File.stat(File.join(@target,file))
                #    self.newchild(file, :target => newtarget)
                #}
            end
        end # Puppet::Type::Symlink
    end # Puppet::Type
end
