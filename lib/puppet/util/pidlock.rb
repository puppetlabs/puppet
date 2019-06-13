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
      return @lockfile.unlock
    end

    # Ensure the process associated with this pid is our process. If
    # not, we can unlock the lockfile. For now this is only done on
    # POSIX and Windows platforms (PUP-9247).
    if Puppet.features.posix?
      procname = Puppet::Util::Execution.execute(["ps", "-p", lock_pid, "-o", "comm="]).strip
      args     = Puppet::Util::Execution.execute(["ps", "-p", lock_pid, "-o", "args="]).strip
      @lockfile.unlock unless procname =~ /ruby/ && args =~ /puppet/ || procname =~ /puppet(-.*)?$/
    elsif Puppet.features.microsoft_windows?
      # On Windows, we're checking if the filesystem path name of the running
      # process is our vendored ruby:
      exe_path = Puppet::Util::Windows::Process::get_process_image_name_by_pid(lock_pid)
      @lockfile.unlock unless exe_path =~ /\\bin\\ruby.exe$/
    end
  end
  private :clear_if_stale

end
