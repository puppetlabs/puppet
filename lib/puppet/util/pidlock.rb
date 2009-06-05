require 'fileutils'

class Puppet::Util::Pidlock
    attr_reader :lockfile

    def initialize(lockfile)
        @lockfile = lockfile
    end

    def locked?
        clear_if_stale
        File.exists? @lockfile
    end

    def mine?
        Process.pid == lock_pid
    end

    def anonymous?
        return false unless File.exists?(@lockfile)
        File.read(@lockfile) == ""
    end

    def lock(opts = {})
        opts = {:anonymous => false}.merge(opts)

        if locked?
            mine?
        else
            if opts[:anonymous]
                File.open(@lockfile, 'w') { |fd| true }
            else
                File.open(@lockfile, "w") { |fd| fd.write(Process.pid) }
            end
            true
        end
    end

    def unlock(opts = {})
        opts = {:anonymous => false}.merge(opts)

        if mine? or (opts[:anonymous] and anonymous?)
            File.unlink(@lockfile)
            true
        else
            false
        end
    end

    private
    def lock_pid
        if File.exists? @lockfile
            File.read(@lockfile).to_i
        else
            nil
        end
    end

    def clear_if_stale
        return if lock_pid.nil?

        begin
            Process.kill(0, lock_pid)
        rescue Errno::ESRCH
            File.unlink(@lockfile)
        end
    end
end
