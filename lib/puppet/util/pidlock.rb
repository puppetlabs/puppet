require 'fileutils'
require 'puppet/util/anonymous_filelock'

class Puppet::Util::Pidlock < Puppet::Util::AnonymousFilelock

  def locked?
    clear_if_stale
    File.exists? @lockfile
  end

  def mine?
    Process.pid == lock_pid
  end

  def anonymous?
    false
  end

  def lock
    return mine? if locked?

    File.open(@lockfile, "w") { |fd| fd.write(Process.pid) }
    true
  end

  def unlock(opts = {})
    if mine?
      begin
        File.unlink(@lockfile)
      rescue Errno::ENOENT
        # Someone deleted it for us ...and so we do nothing.  No point whining
        # about a problem that the user can't actually do anything about.
      rescue SystemCallError => e
        # This one is a real failure though.  No idea what went wrong, but it
        # is most likely "read only file(system)" or wrong permissions or
        # something like that.
        Puppet.err "Could not remove PID file #{@lockfile}: #{e}"
        puts e.backtrace if Puppet[:trace]
      end
      true
    else
      false
    end
  end

  def lock_pid
    if File.exists? @lockfile
      File.read(@lockfile).to_i
    else
      nil
    end
  end

  private
  def clear_if_stale
    return if lock_pid.nil?

    errors = [Errno::ESRCH]
    # Process::Error can only happen, and is only defined, on Windows
    errors << Process::Error if defined? Process::Error

    begin
      Process.kill(0, lock_pid)
    rescue *errors
      File.unlink(@lockfile)
    end
  end
end
