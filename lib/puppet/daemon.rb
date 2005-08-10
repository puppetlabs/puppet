# helper functions for daemons

require 'puppet'

module Puppet
    module Daemon
        def daemonize
            unless Puppet[:logdest] == :file
                Puppet.err "You must reset log destination before daemonizing"
            end
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
                Log.reopen
            rescue => detail
                File.open("/tmp/daemonout", "w") { |f|
                    f.puts "Could not start %s: %s" % [$0, detail]
                }
                Puppet.err "Could not start %s: %s" % [$0, detail]
                exit(12)
            end
        end

        def httplog
            args = []
            # yuck; separate http logs
            if self.is_a?(Puppet::Server)
                args << Puppet[:masterhttplog]
            else
                args << Puppet[:httplog]
            end
            if Puppet[:debug]
                args << WEBrick::Log::DEBUG
            end
            log = WEBrick::Log.new(*args)

            return log
        end
    end
end

# $Id$
