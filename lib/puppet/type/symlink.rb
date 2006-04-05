require 'etc'
require 'puppet/type/state'
require 'puppet/type/pfile'

module Puppet
    newtype(:symlink) do
        @doc = "Create symbolic links to existing files.  **This type is deprecated;
            use file_ instead.**"
        #newstate(:ensure) do
        ensurable do
            require 'etc'
            attr_accessor :file

            desc "Create a link to another file.  Currently only symlinks
                are supported, and attempts to replace normal files with
                links will currently fail, while existing but incorrect symlinks
                will be removed."

            validate do |value|
                unless value == :absent or value =~ /^#{File::SEPARATOR}/
                    raise Puppet::Error, "Invalid symlink %s" % value
                end
            end

            nodefault

            def create
                begin
                    unless File.symlink(self.should,self.parent[:path])
                        self.fail "Could not create symlink '%s'" %
                            self.parent[:path]
                    end
                rescue => detail
                    self.fail "Cannot create symlink '%s': %s" %
                        [self.parent[:path],detail]
                end
            end

            def remove
                if FileTest.symlink?(self.parent[:path])
                    begin
                        File.unlink(self.parent[:path])
                    rescue
                        self.fail "Failed to remove symlink '%s'" %
                            self.parent[:path]
                    end
                elsif FileTest.exists?(self.parent[:path])
                    self.fail "Cannot remove normal file '%s'" %
                        self.parent[:path]
                else
                    @parent.debug("Symlink '%s' does not exist" %
                        self.parent[:path])
                end
            end

            def retrieve
                stat = nil

                if FileTest.symlink?(self.parent[:path])
                    self.is = File.readlink(self.parent[:path])
                    return
                else
                    self.is = :absent
                    return
                end
            end

            # this is somewhat complicated, because it could exist and be
            # a link
            def sync
                case self.should
                when :absent
                    self.remove()
                    return :symlink_removed
                when /^#{File::SEPARATOR}/
                    if FileTest.symlink?(self.parent[:path])
                        path = File.readlink(self.parent[:path])
                        if path != self.should
                            self.remove()
                            self.create()
                            return :symlink_changed
                        else
                            self.info "Already in sync"
                            return nil
                        end
                    elsif FileTest.exists?(self.parent[:path])
                        self.fail "Cannot replace normal file '%s'" %
                            self.parent[:path]
                    else
                        self.create()
                        return :symlink_created
                    end
                else
                    raise Puppet::DevError, "Got invalid symlink value %s" %
                        self.should
                end
            end
        end

        attr_reader :stat, :params

        copyparam(Puppet.type(:file), :path)

        newparam(:recurse) do
            attr_reader :setparent

            desc "If target is a directory, recursively create
                directories (using `file`'s `source` parameter) and link all
                contained files.  For instance::

                    # The Solaris Blastwave repository installs everything
                    # in /opt/csw; link it into /usr/local
                    symlink { \"/usr/local\":
                        ensure => \"/opt/csw\",
                        recurse => true
                    }


                Note that this does not link directories -- any directories
                are created in the destination, and any files are linked over."

            munge do |value|
                @stat = nil
                @target = @parent.state(:ensure).should

                self.setparent(@target)
            end

            def setparent(value)
                # we want to remove our state, because we're creating children
                # to do the links
                if FileTest.exist?(@target)
                    @stat = File.lstat(@target)
                else
                    @setparent = false
                    return
                end

                # if we're a directory, then we descend into it; we only actually
                # link to real files
                unless @stat.directory?
                    return
                end

                @parent.delete(:ensure)

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
                    :path => @parent[:path],
                    :linkmaker => true,
                    :recurse => recurse,
                    :source => @target
                }

                dir = Puppet.type(:file).implicitcreate(args)
                dir.parent = @parent
                @parent.push dir
                @setparent = true
            end
        end

        def initialize(hash)
            @arghash = self.argclean(hash.dup)
            @arghash.delete(self.class.namevar)
            super
        end
    end # Puppet.type(:symlink)
end

# $Id$
