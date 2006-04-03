module Puppet
    Puppet.type(:file).newstate(:target) do
        attr_accessor :linkmaker

        desc "The target for creating a link.  Currently, symlinks are the
            only type supported."

        munge do |value|
            value
        end

        def retrieve
            if @parent.state(:ensure).should == :directory
                @is = self.should
                @linkmaker = true
            else
                if stat = @parent.stat
                    if File.exists?(self.should) and tstat = File.lstat(self.should) and tstat.ftype == "directory" and @parent.recurse?
                        @parent[:ensure] = :directory
                        @is = self.should
                        @linkmaker = true
                    else
                        @is = File.readlink(@parent[:path])
                        @linkmaker = false
                    end
                else
                    @is = :absent
                end
            end
        end

        def sync
            target = self.should

            if stat = @parent.stat
                unless stat.ftype == "link"
                    self.fail "Not replacing non-symlink"
                end
                File.unlink(@parent[:path])
            end
            Dir.chdir(File.dirname(@parent[:path])) do

                unless FileTest.exists?(target)
                    self.debug "Not linking to non-existent '%s'" % target
                    return nil # Grrr, can't return
                else
                    Puppet::Util.asuser(@parent.asuser()) do
                        mode = @parent.should(:mode)
                        if mode
                            Puppet::Util.withumask(000) do
                                File.symlink(target, @parent[:path])
                            end
                        else
                            File.symlink(target, @parent[:path])
                        end
                    end

                    # We can't use "return" here because we're in an anonymous
                    # block.
                    return :link_created
                end
            end
        end
    end
end

# $Id$
