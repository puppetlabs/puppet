require 'fileutils'
require 'puppet/util/lockfile'

class Puppet::Util::Pidlock

  def initialize(lockfile)
    @lockfile = Puppet::Util::Lockfile.new(lockfile)
  end

  def locked?
    clear_if_stale
    @lockfile.locked?
  end

  def mine?
    Process.pid == lock_pid
  end

  def lock
    return mine? if locked?

    @lockfile.lock(Process.pid)
  end

  def unlock
    if mine?
      return @lockfile.unlock
    else
      false
    end
  end

  def lock_pid
    pid = @lockfile.lock_data
    begin
      Integer(pid)
    rescue ArgumentError, TypeError
      nil
    end
  end

  def file_path
    @lockfile.file_path
  end

  def clear_if_stale
    return @lockfile.unlock if lock_pid.nil?

    errors = [Errno::ESRCH]
    # Win32::Process now throws SystemCallError. Since this could be
    # defined anywhere, only add when on Windows.
    errors << SystemCallError if Puppet::Util::Platform.windows?

    begin
      Process.kill(0, lock_pid)
    rescue *errors
      @lockfile.unlock
    end
  end
  private :clear_if_stale

end
