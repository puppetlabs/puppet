require 'puppet'
require 'puppet/type/nameservice'

module Puppet
    class State
        # The lowest-level state class for managing NSS/POSIX information.  It
        # at least knows how to retrieve information, but it does not know how
        # to sync anything.
        class POSIXState < NSSState
        end
    end
end
