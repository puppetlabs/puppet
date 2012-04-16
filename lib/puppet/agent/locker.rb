require 'puppet/util/pidlock'

# This module is responsible for encapsulating the logic for
#  "locking" the puppet agent during a run; in other words,
#  keeping track of enough state to answer the question
#  "is there a puppet agent currently running?"
module Puppet::Agent::Locker

  # Yield if we get a lock, else do nothing.  Return
  # true/false depending on whether we get the lock.
  def lock
    if lockfile.lock
      begin
        yield
      ensure
        lockfile.unlock
      end
    end
  end

  def running?
    lockfile.locked? and !lockfile.anonymous?
  end

  def lockfile
    @lockfile ||= Puppet::Util::Pidlock.new(Puppet[:agent_running_lockfile])

    @lockfile
  end
  private :lockfile


end
