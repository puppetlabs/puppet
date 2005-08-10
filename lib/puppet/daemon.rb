# helper functions for daemons

require 'puppet'

module Puppet
    module Daemon
        def daemonize
            if pid = fork()
                Process.detach(pid)
                exit(0)
            end

            Process.setsid
            Dir.chdir("/")
            begin
                $stdin.reopen "/dev/null"
                $stdout.reopen "/dev/null", "a"
                $stderr.reopen $stdin
            rescue => detail
                Puppet.err "Could not start %s: %s" % [$0, detail]
                exit(12)
            end
        end
    end
end

# $Id$
