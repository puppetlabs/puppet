require 'puppettest/servertest'

module PuppetTest::ExeTest
    include PuppetTest::ServerTest

    def setup
        super
        setbindir
        setlibdir
    end

    def bindir
        File.join(basedir, "bin")
    end

    def sbindir
        File.join(basedir, "sbin")
    end

    def setbindir
        unless ENV["PATH"].split(":").include?(bindir)
            ENV["PATH"] = [bindir, ENV["PATH"]].join(":")
        end
        unless ENV["PATH"].split(":").include?(sbindir)
            ENV["PATH"] = [sbindir, ENV["PATH"]].join(":")
        end
    end

    def setlibdir
        ENV["RUBYLIB"] = $:.find_all { |dir|
            dir =~ /puppet/ or dir =~ /\.\./
        }.join(":")
    end

    # Run a ruby command.  This explicitly uses ruby to run stuff, since we
    # don't necessarily know where our ruby binary is, dernit.
    # Currently unused, because I couldn't get it to work.
    def rundaemon(*cmd)
        @ruby ||= %x{which ruby}.chomp
        cmd = cmd.unshift(@ruby).join(" ")

        out = nil
        Dir.chdir(bindir()) {
            out = %x{#{@ruby} #{cmd}}
        }
        return out
    end

    def startmasterd(args = "")
        output = nil

        manifest = mktestmanifest()
        args += " --manifest %s" % manifest
        args += " --confdir %s" % Puppet[:confdir]
        args += " --rundir %s" % File.join(Puppet[:vardir], "run")
        args += " --vardir %s" % Puppet[:vardir]
        args += " --master_dns_alt_names %s" % Puppet[:certdnsnames]
        args += " --masterport %s" % @@port
        args += " --user %s" % Puppet::Util::SUIDManager.uid
        args += " --group %s" % Puppet::Util::SUIDManager.gid
        args += " --autosign true"

        #if Puppet[:debug]
        #    args += " --debug"
        #end

        cmd = "puppetmasterd %s" % args


        assert_nothing_raised {
            output = %x{#{cmd}}.chomp
        }
        assert_equal("", output, "Puppetmasterd produced output %s" % output)
        assert($? == 0, "Puppetmasterd exit status was %s" % $?)
        sleep(1)

        cleanup do
            stopmasterd
            sleep(1)
        end

        return manifest
    end

    def stopmasterd(running = true)
        ps = Facter["ps"].value || "ps -ef"

        pidfile = File.join(Puppet[:vardir], "run", "puppetmasterd.pid")

        pid = nil
        if FileTest.exists?(pidfile)
            pid = File.read(pidfile).chomp.to_i
            File.unlink(pidfile)
        end

        return unless running
        if running or pid
            runningpid = nil
            %x{#{ps}}.chomp.split(/\n/).each { |line|
                if line =~ /ruby.+puppetmasterd/
                    next if line =~ /\.rb/ # skip the test script itself
                    next if line =~ /^puppet/ # skip masters running as 'puppet'
                    ary = line.sub(/^\s+/, '').split(/\s+/)
                    pid = ary[1].to_i
                end
            }

        end

        # we default to mandating that it's running, but teardown
        # doesn't require that
        if pid
            if pid == $$
                raise Puppet::Error, "Tried to kill own pid"
            end
            begin
                Process.kill(:INT, pid)
            rescue
                # ignore it
            end
        end
    end

    def teardown
        stopmasterd(false)
        super
    end
end

