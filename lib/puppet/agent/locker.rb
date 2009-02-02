require 'puppet/util/pidlock'

# Break out the code related to locking the agent.  This module is just
# included into the agent, but having it here makes it easier to test.
module Puppet::Agent::Locker
    # Let the daemon run again, freely in the filesystem.
    def enable
        lockfile.unlock(:anonymous => true)
    end

    # Stop the daemon from making any catalog runs.
    def disable
        lockfile.lock(:anonymous => true)
    end

    # Yield if we get a lock, else do nothing.  Return
    # true/false depending on whether we get the lock.
    def lock
        if lockfile.lock
            begin
                yield
            ensure
                lockfile.unlock
            end
            return true
        else
            return false
        end
    end

    def lockfile
        unless defined?(@lockfile)
            @lockfile = Puppet::Util::Pidlock.new(lockfile_path)
        end

        @lockfile
    end

    def running?
        lockfile.locked?
    end
end
