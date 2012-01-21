require 'puppet/util/anonymous_filelock'

module Puppet::Agent::Disabler
  # Let the daemon run again, freely in the filesystem.
  def enable
    disable_lockfile.unlock
  end

  # Stop the daemon from making any catalog runs.
  def disable(msg='')
    disable_lockfile.lock(msg)
  end

  def disable_lockfile
    @disable_lockfile ||= Puppet::Util::AnonymousFilelock.new(lockfile_path+".disabled")

    @disable_lockfile
  end

  def disabled?
    disable_lockfile.locked?
  end

  def disable_message
    disable_lockfile.message
  end
end
