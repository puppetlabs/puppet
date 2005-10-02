module Puppet
    class State
        class PFileType < Puppet::State
            require 'etc'
            @doc = "A read-only state to check the file type."
            @name = :type

            def shouldprocess(value)
                raise Puppet::Error, ":type is read-only"
            end
            
            def retrieve
                if stat = @parent.stat(true)
                    @is = stat.ftype
                else
                    @is = :notfound
                end

                # so this state is never marked out of sync
                @should = [@is]
            end


            def sync
                raise Puppet::Error, ":type is read-only"
            end
        end
    end
end

# $Id$
