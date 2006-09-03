module Puppet
    Puppet.type(:file).ensurable do
        require 'etc'
        desc "Whether to create files that don't currently exist.
            Possible values are *absent*, *present* (equivalent to ``exists`` in
            most file tests -- will match any form of file existence, and if the
            file is missing will create an empty file), *file*, and
            *directory*.  Specifying ``absent`` will delete the file, although
            currently this will not recursively delete directories.

            Anything other than those values will be considered to be a symlink.
            For instance, the following text creates a link:
                
                # Useful on solaris
                file { \"/etc/inetd.conf\":
                    ensure => \"/etc/inet/inetd.conf\"
                }
            
            You can make relative links:
                
                # Useful on solaris
                file { \"/etc/inetd.conf\":
                    ensure => \"inet/inetd.conf\"
                }

            If you need to make a relative link to a file named the same
            as one of the valid values, you must prefix it with ``./`` or
            something similar.

            You can also make recursive symlinks, which will create a
            directory structure that maps to the target directory,
            with directories corresponding to each directory
            and links corresponding to each file."

        # Most 'ensure' states have a default, but with files we, um, don't.
        nodefault

        newvalue(:absent, :event => :file_deleted) do
            File.unlink(@parent[:path])
        end

        aliasvalue(:false, :absent)

        newvalue(:file, :event => :file_created) do
            # Make sure we're not managing the content some other way
            if state = (@parent.state(:content) || @parent.state(:source))
                # Manually sync the state, and reset its is value to it knows it's
                # in sync.
                should = state.should
                state.commit

                # The 'sync' method here syncs any states that might still be
                # out of sync like 'mode', so we need to mark this in sync.
                state.is = should
            else
                @parent.write(false) { |f| f.flush }
            end
            return :file_created
        end

        #aliasvalue(:present, :file)
        newvalue(:present) do
            # Make a file if they want something, but this will match almost
            # anything.
            set_file
        end

        newvalue(:directory, :event => :directory_created) do
            mode = @parent.should(:mode)
            parent = File.dirname(@parent[:path])
            unless FileTest.exists? parent
                raise Puppet::Error,
                    "Cannot create %s; parent directory %s does not exist" %
                        [@parent[:path], parent]
            end
            Puppet::Util.asuser(@parent.asuser()) {
                if mode
                    Puppet::Util.withumask(000) do
                        Dir.mkdir(@parent[:path],mode)
                    end
                else
                    Dir.mkdir(@parent[:path])
                end
            }
            @parent.setchecksum
            return :directory_created
        end


        newvalue(:link, :event => :link_created) do
            if state = @parent.state(:target)
                state.retrieve

                if state.linkmaker
                    self.set_directory
                    return :directory_created
                else
                    return state.mklink
                end
            else
                self.fail "Cannot create a symlink without a target"
            end
        end

        # Symlinks.
        newvalue(/./, :event => :link_created) do
            # This code never gets executed.  We need the regex to support
            # specifying it, but the work is done in the 'symlink' code block.
        end

        munge do |value|
            value = super(value)

            return value if value.is_a? Symbol

            @parent[:target] = value

            return :link
        end

        # Check that we can actually create anything
        def check
            basedir = File.dirname(@parent[:path])

            if ! FileTest.exists?(basedir)
                raise Puppet::Error,
                    "Can not create %s; parent directory does not exist" %
                    @parent.title
            elsif ! FileTest.directory?(basedir)
                raise Puppet::Error,
                    "Can not create %s; %s is not a directory" %
                    [@parent.title, dirname]
            end
        end

        # We have to treat :present specially, because it works with any
        # type of file.
        def insync?
            is = self.is
            if self.should == :present
                if is.nil? or is == :absent
                    return false
                else
                    return true
                end
            else
                return super
            end
        end

        def retrieve
            retval = nil
            if stat = @parent.stat(false)
                retval = stat.ftype.intern
            else
                if self.should == :false
                    retval = :false
                else
                    retval = :absent
                end
            end

            return retval
        end

        def sync(value)
            event = super(value)

            # There are some cases where all of the work does not get done on
            # file creation, so we have to do some extra checking.
            @parent.each do |thing|
                next unless thing.is_a? Puppet::State
                next if thing == self

                thing.retrieve
                unless thing.insync?
                    thing.commit
                end
            end

            return event
        end
    end
end

# $Id$
