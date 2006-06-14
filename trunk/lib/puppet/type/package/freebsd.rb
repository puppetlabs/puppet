module Puppet
    Puppet.type(:package).newpkgtype(:freebsd, :openbsd) do
        def listcmd
            "pkg_info"
        end

        def query
            list

            if self[:version]
                return :listed
            else
                return nil
            end
        end
    end
end

# $Id$
