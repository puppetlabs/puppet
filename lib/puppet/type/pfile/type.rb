module Puppet
    Puppet.type(:file).newstate(:type) do
        require 'etc'
        desc "A read-only state to check the file type."

        #munge do |value|
        #    raise Puppet::Error, ":type is read-only"
        #end
        
        def retrieve
            retval = nil
            if stat = @parent.stat(false)
                retval = stat.ftype
            else
                retval = :absent
            end

            # so this state is never marked out of sync
            @should = [retval]

            return retval
        end


        def sync(value)
            raise Puppet::Error, ":type is read-only"
        end
    end
end

# $Id$
