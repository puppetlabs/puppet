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
            %x{kill #{pid} 2>/dev/null}
        }
        stopmaster
    end

    def startmaster(file, port)
        output = nil
        ssldir = "/tmp/puppetmasterdpuppetdssldirtesting"
        @@tmpfiles << ssldir
        assert_nothing_raised {
            output = %x{puppetmasterd --port #{port} -a --ssldir #{ssldir} --manifest #{file}}.chomp
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
        if pid
            assert_nothing_raised {
                Process.kill("-TERM", pid)
            }
        end
    end

    def test_normalstart
        file = "/tmp/testingmanifest.pp"
        File.open(file, "w") { |f|
            f.puts '
file { "/tmp/puppetdtesting": create => true, mode => 755 }
'
        }

        @@tmpfiles << file
        @@tmpfiles << "/tmp/puppetdtesting"
        port = 8235
        startmaster(file, port)
        output = nil
        ssldir = "/tmp/puppetdssldirtesting"
        @@tmpfiles << ssldir
        client = Puppet::Client.new(:Server => "localhost")
        fqdn = client.fqdn.sub(/^\w+\./, "testing.")
        assert_nothing_raised {
            output = %x{puppetd --fqdn #{fqdn} --port #{port} --ssldir #{ssldir} --server localhost}.chomp
        }
        sleep 1
        assert($? == 0, "Puppetd exited with code %s" % $?)
        #puts output
        assert_equal("", output, "Puppetd produced output %s" % output)

        assert(FileTest.exists?("/tmp/puppetdtesting"),
            "Failed to create config'ed file")
        stopmaster
    end
end
