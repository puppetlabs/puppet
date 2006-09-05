module Puppet
    Puppet.type(:file).newstate(:target) do
        attr_accessor :linkmaker

        desc "The target for creating a link.  Currently, symlinks are the
            only type supported."

        newvalue(:notlink) do
            # We do nothing if the value is absent
            return :nochange
        end

        # Anything else, basically
        newvalue(/./) do
            if @parent.state(:ensure).insync?
                mklink()
            end
        end

        # Create our link.
        def mklink
            target = self.should

            if stat = @parent.stat
                unless @parent.handlebackup
                    self.fail "Could not back up; will not replace with link"
                end

                case stat.ftype
                when "directory":
                    if @parent[:force] == :true
                        FileUtils.rmtree(@parent[:path])
                    else
                        notice "Not replacing directory with link; use 'force' to override"
                        return :nochange
                    end
                else
                    File.unlink(@parent[:path])
                end
            end
            Dir.chdir(File.dirname(@parent[:path])) do
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

                :link_created
            end
        end

        def retrieve
            if @parent.state(:ensure).should == :directory
                @is = self.should
                @linkmaker = true
            else
                if stat = @parent.stat
                    # If we're just checking the value
                    if (should = self.should) and
                            (should != :notlink) and
                            File.exists?(should) and
                            (tstat = File.lstat(should)) and
                            (tstat.ftype == "directory") and
                            @parent.recurse?
                        unless @parent.recurse?
                            raise "wtf?"
                        end
                        warning "Changing ensure to directory; recurse is %s but %s" %
                            [@parent[:recurse].inspect, @parent.recurse?]
                        @parent[:ensure] = :directory
                        @is = should
                        @linkmaker = true
                    else
                        if stat.ftype == "link"
                            @is = File.readlink(@parent[:path])
                            @linkmaker = false
                        else
                            @is = :notlink
                        end
                    end
                else
                    @is = :absent
                end
            end
        end
    end
end

# $Id$
