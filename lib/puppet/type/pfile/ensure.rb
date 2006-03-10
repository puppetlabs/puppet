module Puppet
    Puppet.type(:file).ensurable do
        require 'etc'
        desc "Whether to create files that don't currently exist.
            Possible values are *absent*, *present* (equivalent to *file*),
            *file*, and *directory*.  Specifying 'absent' will delete the file,
            although currently this will not recursively delete directories.

            Anything other than those values will be considered to be a symlink.
            For instance, the following text creates a link::
                
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

        newvalue(:absent) do
            File.unlink(@parent[:path])
        end

        aliasvalue(:false, :absent)

        newvalue(:file) do
            # Make sure we're not managing the content some other way
            if state = @parent.state(:content) or state = @parent.state(:source)
                state.sync
            else
                @parent.write(false) { |f| f.flush }
                mode = @parent.should(:mode)
            end
            return :file_created
        end

        aliasvalue(:present, :file)

        newvalue(:directory) do
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

        # Symlinks.  We pretty much have to match just about anything,
        # in order to match relative links.  Somewhat ugly, but eh, it
        # works.
        newvalue(/./) do
            Dir.chdir(File.dirname(@parent[:path])) do
                target = self.should
                unless FileTest.exists?(target)
                    self.debug "Not linking to non-existent '%s'" % target
                    nil # Grrr, can't return
                else
                    if FileTest.directory?(target) and @parent[:recurse]
                        # If we're pointing to a directory and recursion is
                        # enabled, then make a directory instead of a link.
                        self.set_directory
                    else
                        Puppet::Util.asuser(@parent.asuser()) do
                            mode = @parent.should(:mode)
                            if mode
                                Puppet::Util.withumask(000) do
                                    File.symlink(self.should, @parent[:path])
                                end
                            else
                                File.symlink(self.should, @parent[:path])
                            end
                        end

                        # We can't use "return" here because we're in an anonymous
                        # block.
                        :link_created
                    end
                end
            end
        end

        # Check that we can actually create anything
        def check
            basedir = File.dirname(@parent[:path])

            if ! FileTest.exists?(basedir)
                raise Puppet::Error,
                    "Can not create %s; parent directory does not exist" %
                    @parent.name
            elsif ! FileTest.directory?(basedir)
                raise Puppet::Error,
                    "Can not create %s; %s is not a directory" %
                    [@parent.name, dirname]
            end
        end

        def retrieve
            if stat = @parent.stat(false)
                # If we're a link, set the 'is' value to the destination
                # of the link
                if stat.ftype == "link"
                    @is = File.readlink(@parent[:path])
                else
                    @is = stat.ftype.intern
                end
            else
                if self.should == :false
                    @is = :false
                else
                    @is = :absent
                end
            end
        end
    end
end

# $Id$
