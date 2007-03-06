#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/network/client'
require 'puppettest'
require 'socket'
require 'facter'

class TestPuppetDExe < Test::Unit::TestCase
    include PuppetTest::ExeTest
    def test_normalstart
        # start the master
        file = startmasterd

        # create the client
        client = Puppet::Network::Client.master.new(:Server => "localhost", :Port => @@port)

        # make a new fqdn
        fqdn = Puppet[:certname].sub(/^\w+\./, "testing.")

        cmd = "puppetd"
        cmd += " --verbose"
        cmd += " --onetime"
        cmd += " --masterport %s" % @@port
        cmd += " --confdir %s" % Puppet[:confdir]
        cmd += " --rundir %s" % File.join(Puppet[:vardir], "run")
        cmd += " --vardir %s" % Puppet[:vardir]
        cmd += " --server localhost"

        # and verify our daemon runs
        assert_nothing_raised {
            %x{#{cmd} 2>&1}
        }
        sleep 1
        assert($? == 0, "Puppetd exited with code %s" % $?)

        assert(FileTest.exists?(@createdfile),
            "Failed to create config'ed file")

        # now verify that --noop works
        File.unlink(@createdfile)

        cmd += " --noop"
        assert_nothing_raised {
            output = %x{#{cmd}}.chomp
        }
        sleep 1
        assert($? == 0, "Puppetd exited with code %s" % $?)

        assert(! FileTest.exists?(@createdfile),
            "Noop created config'ed file")

        stopmasterd
    end
end

# $Id$
