if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/server'
require 'test/unit'
require 'puppettest.rb'
require 'socket'
require 'facter'

class TestPuppetDExe < Test::Unit::TestCase
	include ExeTest
    def test_normalstart
        # start the master
        file = startmasterd

        # create the client
        client = Puppet::Client.new(:Server => "localhost", :Port => @@port)

        # make a new fqdn
        fqdn = client.fqdn.sub(/^\w+\./, "testing.")

        cmd = "puppetd"
        cmd += " --verbose"
        #cmd += " --fqdn %s" % fqdn
        cmd += " --port %s" % @@port
        cmd += " --confdir %s" % Puppet[:puppetconf]
        cmd += " --vardir %s" % Puppet[:puppetvar]
        cmd += " --server localhost"

        # and verify our daemon runs
        assert_nothing_raised {
            output = %x{#{cmd}}.chomp
            puts output
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
