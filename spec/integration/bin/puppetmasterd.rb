#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe "puppetmasterd" do
    before do
        # Get a safe temporary file
        file = Tempfile.new("puppetmaster_integration_testing")
        @dir = file.path
        file.delete

        Dir.mkdir(@dir)

        Puppet.settings[:confdir] = @dir
        Puppet.settings[:vardir] = @dir
        Puppet[:certdnsnames] = "localhost"

        @@port = 12345

        Puppet::SSL::Host.instance_eval{
            @value_cache = {}
        }
    end

    after {
        stop

        Puppet::SSL::Host.ca_location = :none

        system("rm -rf %s" % @dir)
        Puppet.settings.clear
    }

    def arguments
        rundir = File.join(Puppet[:vardir], "run")
        @pidfile = File.join(rundir, "testing.pid")
        args = ""
        args += " --confdir %s" % Puppet[:confdir]
        args += " --rundir %s" % rundir
        args += " --pidfile %s" % @pidfile
        args += " --vardir %s" % Puppet[:vardir]
        args += " --master_dns_alt_names %s" % Puppet[:certdnsnames]
        args += " --masterport %s" % @@port
        args += " --user %s" % Puppet::Util::SUIDManager.uid
        args += " --group %s" % Puppet::Util::SUIDManager.gid
        args += " --autosign true"
    end

    def start(addl_args = "")
        Puppet.settings.mkdir(:manifestdir)
        Puppet.settings.write(:manifest) do |f|
            f.puts { "notify { testing: }" }
        end

        args = arguments + " " + addl_args

        bin = File.join(File.dirname(__FILE__), "..", "..", "..", "sbin", "puppetmasterd")
        lib = File.join(File.dirname(__FILE__), "..", "..", "..", "lib")
        output = %x{/usr/bin/env ruby -I #{lib} #{bin} #{args}}.chomp
    end

    def stop
        if @pidfile and File.exist?(@pidfile)
            pid = File.read(@pidfile).chomp.to_i
            Process.kill(:TERM, pid)
            10.times do
                break unless File.exist?(@pidfile)
                sleep 1
            end
            begin
                # sigkill and report if process was still running
                Process.kill(:KILL, pid)

                raise "Process didn't die from SIGTERM after 10 seconds"
            rescue Errno::ESRCH
                # process wasn't running. good.
            end

        end
    end

    it "should create a PID file" do
        start

        FileTest.exist?(@pidfile).should be_true
    end

    it "should be serving status information over REST"

    it "should be serving status information over xmlrpc" do
        start

        sleep 6

        client = Puppet::Network::Client.status.new(:Server => "localhost", :Port => @@port)

        retval = client.status

        retval.should == 1
    end

    it "should exit with return code 0 after parsing if --parseonly is set and there are no errors" do
        start(" --parseonly > /dev/null")
        sleep(1)

        ps = Facter["ps"].value || "ps -ef"
        pid = nil
        %x{#{ps}}.chomp.split(/\n/).each { |line|
            next if line =~ /^puppet/ # skip normal master procs
            if line =~ /puppetmasterd.+--manifest/
                ary = line.split(" ")
                pid = ary[1].to_i
            end
        }

        $?.should == 0

        pid.should be_nil
    end

    it "should exit with return code 1 after parsing if --parseonly is set and there are errors"
end
