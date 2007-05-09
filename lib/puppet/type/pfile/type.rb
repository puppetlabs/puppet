module Puppet
    Puppet.type(:file).newproperty(:type) do
        require 'etc'
        desc "A read-only state to check the file type."

        #munge do |value|
        #    raise Puppet::Error, ":type is read-only"
        #end
        
        def retrieve
            currentvalue = :absent
            if stat = @parent.stat(false)
                currentvalue = stat.ftype
            end
            # so this state is never marked out of sync
            @should = [currentvalue]
            return currentvalue
        end


        def sync
            raise Puppet::Error, ":type is read-only"
        end
    end
end

# $Id$
