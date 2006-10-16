#!/usr/bin/env ruby -I../lib -I../../lib

require 'puppet'
require 'puppet/server'
require 'puppettest'
require 'socket'
require 'facter'

class TestPuppetDExe < Test::Unit::TestCase
    include PuppetTest::ExeTest
    def test_normalstart
        # start the master
        file = startmasterd

        # create the client
        client = Puppet::Client::MasterClient.new(:Server => "localhost", :Port => @@port)

        # make a new fqdn
        fqdn = client.fqdn.sub(/^\w+\./, "testing.")

        cmd = "puppetd"
        cmd += " --verbose"
        cmd += " --onetime"
        #cmd += " --fqdn %s" % fqdn
        cmd += " --masterport %s" % @@port
        cmd += " --confdir %s" % Puppet[:confdir]
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
