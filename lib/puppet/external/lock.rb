require 'thread'
require 'sync'

# Gotten from:
# http://path.berkeley.edu/~vjoel/ruby/solaris-bug.rb

# Extensions to the File class for exception-safe file locking in a
# environment with multiple user threads.

# This is here because closing a file on solaris unlocks any locks that
# other threads might have. So we have to make sure that only the last
# reader thread closes the file.
#
# The hash maps inode number to a count of reader threads
$reader_count = Hash.new(0)

class File
    # Get an exclusive (i.e., write) lock on the file, and yield to the block.
    # If the lock is not available, wait for it without blocking other ruby
    # threads.
    def lock_exclusive
        if Thread.list.size == 1
            flock(LOCK_EX)
        else
            # ugly hack because waiting for a lock in a Ruby thread blocks the
            # process
            period = 0.001
            until flock(LOCK_EX|LOCK_NB)
                sleep period
                period *= 2 if period < 1
            end
        end

        yield self
    ensure
        flush
        flock(LOCK_UN)
    end

    # Get a shared (i.e., read) lock on the file, and yield to the block.
    # If the lock is not available, wait for it without blocking other ruby
    # threads.
    def lock_shared
        if Thread.list.size == 1
            flock(LOCK_SH)
        else
            # ugly hack because waiting for a lock in a Ruby thread blocks the
            # process
            period = 0.001
            until flock(LOCK_SH|LOCK_NB)
                sleep period
                period *= 2 if period < 1
            end
        end

        yield self
    ensure
        Thread.exclusive {flock(LOCK_UN) if $reader_count[self.stat.ino] == 1}
        ## for solaris, no need to unlock here--closing does it
        ## but this has no effect on the bug
    end
end

