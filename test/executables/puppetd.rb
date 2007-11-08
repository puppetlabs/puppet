#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'puppet'
require 'puppet/network/client'
require 'puppettest'
require 'socket'
require 'facter'

class TestPuppetDExe < Test::Unit::TestCase
    include PuppetTest::ExeTest
    def setup
        super
        # start the master
        @manifest = startmasterd

        @cmd = "puppetd"
        @cmd += " --verbose"
        @cmd += " --test"
        @cmd += " --masterport %s" % @@port
        @cmd += " --confdir %s" % Puppet[:confdir]
        @cmd += " --rundir %s" % File.join(Puppet[:vardir], "run")
        @cmd += " --vardir %s" % Puppet[:vardir]
        @cmd += " --server localhost"
    end

    def test_normalstart
        # and verify our daemon runs
        output = nil
        assert_nothing_raised {
            output = %x{#{@cmd} 2>&1}
        }
        sleep 1
        assert($? == 0, "Puppetd exited with code %s" % $?)

        assert(FileTest.exists?(@createdfile), "Failed to create file %s" % @createdfile)
    end

    # now verify that --noop works
    def test_noop_start
        @cmd += " --noop"
        assert_nothing_raised {
            output = %x{#{@cmd}}.chomp
        }
        sleep 1
        assert($? == 0, "Puppetd exited with code %s" % $?)

        assert(! FileTest.exists?(@createdfile),
            "Noop created config'ed file")
    end
end

