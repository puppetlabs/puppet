module Puppet
    Puppet.type(:file).newproperty(:type) do
        require 'etc'
        desc "A read-only state to check the file type."

        #munge do |value|
        #    raise Puppet::Error, ":type is read-only"
        #end
        
        def retrieve
            if stat = @parent.stat(false)
                @is = stat.ftype
            else
                @is = :absent
            end

            # so this state is never marked out of sync
            @should = [@is]
        end


        def sync
            raise Puppet::Error, ":type is read-only"
        end
    end
end

# $Id$
