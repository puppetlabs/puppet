require 'puppet/util/pidlock'
require 'puppet/error'

# This module is responsible for encapsulating the logic for "locking" the
# puppet agent during a catalog run; in other words, keeping track of enough
# state to answer the question "is there a puppet agent currently applying a
# catalog?"
#
# The implementation involves writing a lockfile whose contents are simply the
# PID of the running agent process.  This is considered part of the public
# Puppet API because it used by external tools such as mcollective.
#
# For more information, please see docs on the website.
#  http://links.puppetlabs.com/agent_lockfiles
module Puppet::Agent::Locker
  # Yield if we get a lock, else raise Puppet::LockError. Return
  # value of block yielded.
  def lock
    if lockfile.lock
      begin
        yield
      ensure
        lockfile.unlock
      end
    else
      fail Puppet::LockError, 'Failed to aquire lock'
    end
  end

  # @deprecated
  def running?
    Puppet.deprecation_warning <<-ENDHEREDOC
Puppet::Agent::Locker.running? is deprecated as it is inherently unsafe.
The only safe way to know if the lock is locked is to try lock and perform some
action and then handle the LockError that may result.
ENDHEREDOC
    lockfile.locked?
  end

  def lockfile_path
    @lockfile_path ||= Puppet[:agent_catalog_run_lockfile]
  end

  def lockfile
    @lockfile ||= Puppet::Util::Pidlock.new(lockfile_path)

    @lockfile
  end
  private :lockfile


end
