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
    def setup
        Puppet[:loglevel] = :debug if __FILE__ == $0
        @@tmpfiles = []
        @@tmppids = []
    end

    def teardown
        @@tmpfiles.flatten.each { |file|
            if File.exists? file
                system("rm -rf %s" % file)
            end
        }

        @@tmppids.each { |pid|
            %x{kill -INT #{pid} 2>/dev/null}
        }
    end

    def startmaster
        file = File.join($puppetbase, "examples", "code", "head")
        output = nil
        assert_nothing_raised {
            output = %x{puppetmasterd --port #{Puppet[:masterport]} --manifest #{file}}.chomp
        }
        assert($? == 0, "Puppetmasterd return status was %s" % $?)
        @@tmppids << $?.pid
        assert_equal("", output)
    end

    def stopmaster
        ps = Facter["ps"].value || "ps -ef"

        pid = nil
        %x{#{ps}}.chomp.split(/\n/).each { |line|
            if line =~ /puppetmasterd/
                ary = line.split(" ")
                pid = ary[1].to_i
            end
        }
        assert(pid, "No puppetmasterd pid")
        
        assert_nothing_raised {
            Process.kill("-INT", pid)
        }
    end

    def test_normalstart
        startmaster
        output = nil
        assert_nothing_raised {
            output = %x{puppetd --server localhost}.chomp
        }
        assert($? == 0, "Puppetd exited with code %s" % $?)
        assert_equal("", output, "Puppetd produced output %s" % output)

        assert_nothing_raised {
            socket = TCPSocket.new("127.0.0.1", Puppet[:masterport])
            socket.close
        }
        stopmaster
    end
end
