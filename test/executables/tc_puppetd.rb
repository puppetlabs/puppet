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

# $Id$

# ok, we have to add the bin directory to our search path
ENV["PATH"] += ":" + File.join($puppetbase, "bin")

# and then the library directories
libdirs = $:.find_all { |dir|
    dir =~ /puppet/ or dir =~ /\.\./
}
ENV["RUBYLIB"] = libdirs.join(":")

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
        cmd += " --fqdn %s" % fqdn
        cmd += " --port %s" % @@port
        cmd += " --ssldir %s" % Puppet[:ssldir]
        cmd += " --server localhost"

        # and verify our daemon runs
        assert_nothing_raised {
            output = %x{#{cmd}}.chomp
        }
        sleep 1
        assert($? == 0, "Puppetd exited with code %s" % $?)
        #puts output
        #assert_equal("", output, "Puppetd produced output %s" % output)

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
