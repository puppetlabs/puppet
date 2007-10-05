#!/usr/bin/env ruby

$:.unshift("../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet/daemon'

class TestDaemon < Test::Unit::TestCase
	include PuppetTest

    class FakeDaemon
        include Puppet::Daemon
    end

    def test_pidfile
        daemon = FakeDaemon.new

        assert_nothing_raised("removing non-existent file failed") do
            daemon.rmpidfile
        end

        Puppet[:pidfile] = tempfile()
        assert_nothing_raised "could not lock" do
            daemon.setpidfile
        end

        assert(FileTest.exists?(daemon.pidfile),
            "did not create pidfile")

        assert_nothing_raised("removing non-existent file failed") do
            daemon.rmpidfile
        end

        assert(! FileTest.exists?(daemon.pidfile),
            "did not remove pidfile")
    end

    def test_daemonize
        daemon = FakeDaemon.new
        Puppet[:pidfile] = tempfile()

        exiter = tempfile()

        assert_nothing_raised("Could not fork and daemonize") do
            fork do
                daemon.send(:daemonize)
                # Wait a max of 5 secs
                50.times do
                    if FileTest.exists?(exiter)
                        daemon.rmpidfile
                        exit(0)
                    end
                    sleep 0.1
                end
                exit(0)
            end
        end
        sleep(0.1)
        assert(FileTest.exists?(Puppet[:pidfile]),
            "did not create pidfile on daemonize")

        File.open(exiter, "w") { |f| f.puts "" }

        sleep(0.2)
        assert(! FileTest.exists?(Puppet[:pidfile]),
            "did not remove pidfile on process death")
    end
end


