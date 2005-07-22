#!/usr/local/bin/ruby -w

# $Id$

require 'etc'
require 'puppet/type/state'
require 'puppet/type/pfile'

module Puppet
    # okay, how do we deal with parameters that don't have operations
    # associated with them?
    class State
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
                elsif FileTest.exists?(@link)
                    Puppet.err "Cannot replace %s with a link" % @link
                    @should = nil
                    @is = nil
                else
                    self.is = nil
                    return
                end
            end

            # we know the link should exist, but it should also point back
            # to us
            def should=(link)
                @link = link
                @should = @parent[:path]

                # unless we're fully qualified or we've specifically allowed
                # relative links.  Relative links are currently disabled, until
                # someone actually asks for them
                #unless @should =~ /^\// or @parent[:relativelinks]
                unless @should =~ /^\//
                    @should = File.expand_path @should
                end
            end

            # this is somewhat complicated, because it could exist and be
            # a file
            def sync
                if @is
                    self.class.remove(@link)
                end
                self.class.create(@should,@link)

                return :link_created
            end
        end

        class SymlinkTarget < Puppet::State
            require 'etc'
            attr_accessor :file

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

            @name = :symlink
            @namevar = :path

            def initialize(hash)
                @arghash = self.argclean(hash.dup)
                @arghash.delete(self.class.namevar)

                super
            end

            def newchild(path, hash = {})
                if path =~ %r{^#{File::SEPARATOR}}
                    raise Puppet::DevError.new(
                        "Must pass relative paths to Symlink#newchild()"
                    )
                else
                    path = File.join(self.name, path)
                end

                args = @arghash.dup

                args[:path] = path

                unless hash.include?(:recurse)
                    if args.include?(:recurse)
                        if args[:recurse].is_a?(Integer)
                            Puppet.notice "Decrementing recurse on %s" % path
                            args[:recurse] -= 1 # reduce the level of recursion
                        end
                    end

                end

                hash.each { |key,value|
                    args[key] = value
                }

                child = nil
                if child = self.class[path]
                    #raise "Ruh-roh"
                    args.each { |var,value|
                        next if var == :path
                        next if var == :name
                        child[var] = value
                    }
                else # create it anew
                    #notice "Creating new file with args %s" % args.inspect
                    begin
                        child = self.class.new(args)
                    rescue Puppet::Error => detail
                        Puppet.notice(
                            "Cannot manage %s: %s" %
                                [path,detail.message]
                        )
                        Puppet.debug args.inspect
                        child = nil
                    rescue => detail
                        Puppet.notice(
                            "Cannot manage %s: %s" %
                                [path,detail]
                        )
                        Puppet.debug args.inspect
                        child = nil
                    end
                end
                if child
                    child.parent = self
                end
                return child
            end

            def newsource(source)
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
