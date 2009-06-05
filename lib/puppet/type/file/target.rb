module Puppet
    Puppet::Type.type(:file).newproperty(:target) do
        desc "The target for creating a link.  Currently, symlinks are the
            only type supported."

        newvalue(:notlink) do
            # We do nothing if the value is absent
            return :nochange
        end

        # Anything else, basically
        newvalue(/./) do
            if ! @resource.should(:ensure)
                @resource[:ensure] = :link
            end

            # Only call mklink if ensure() didn't call us in the first place.
            currentensure  = @resource.property(:ensure).retrieve
            if @resource.property(:ensure).insync?(currentensure)
                mklink()
            end
        end

        # Create our link.
        def mklink
            target = self.should

            # Clean up any existing objects.  The argument is just for logging,
            # it doesn't determine what's removed.
            @resource.remove_existing(target)

            if FileTest.exists?(@resource[:path])
                raise Puppet::Error, "Could not remove existing file"
            end

            Dir.chdir(File.dirname(@resource[:path])) do
                Puppet::Util::SUIDManager.asuser(@resource.asuser()) do
                    mode = @resource.should(:mode)
                    if mode
                        Puppet::Util.withumask(000) do
                            File.symlink(target, @resource[:path])
                        end
                    else
                        File.symlink(target, @resource[:path])
                    end
                end

                @resource.send(:property_fix)

                :link_created
            end
        end

        def insync?(currentvalue)
            if [:nochange, :notlink].include?(self.should) or @resource.recurse?
                return true
            elsif ! @resource.replace? and File.exists?(@resource[:path])
                return true
            else
                return super(currentvalue)
            end
        end


        def retrieve
            if stat = @resource.stat
                if stat.ftype == "link"
                    return File.readlink(@resource[:path])
                else
                    return :notlink
                end
            else
                return :absent
            end
        end
    end
end

