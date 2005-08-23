if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '../../../../library/trunk/lib/'
    $:.unshift '../../../../library/trunk/test/'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/server'
require 'puppet/daemon'
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

class TestPuppetMasterD < Test::Unit::TestCase
    def getcerts
        include Puppet::Daemon
        if self.readcerts
            return [@cert, @key, @cacert, @cacertfile]
        else
            raise "Couldn't read certs"
        end
    end

    def setup
        if __FILE__ == $0
            Puppet[:loglevel] = :debug
        end
        @@tmpfiles = []
    end

    def startmasterd(args)
        output = nil
        cmd = "puppetmasterd %s" % args
        #if Puppet[:debug]
        #    Puppet.debug "turning daemon debugging on"
        #    cmd += " --debug"
        #end
        assert_nothing_raised {
            output = %x{puppetmasterd #{args}}.chomp
        }
        assert($? == 0)
        assert_equal("", output)
    end

    def stopmasterd(running = true)
        ps = Facter["ps"].value || "ps -ef"

        pid = nil
        %x{#{ps}}.chomp.split(/\n/).each { |line|
            if line =~ /puppetmasterd --manifest/
                ary = line.split(" ")
                pid = ary[1].to_i
            end
        }

        # we default to mandating that it's running, but teardown
        # doesn't require that
        if running or pid
            assert(pid)

            assert_nothing_raised {
                Process.kill("-INT", pid)
            }
        end
    end

    def teardown
        @@tmpfiles.flatten.each { |file|
            if File.exists?(file)
                system("rm -rf %s" % file)
            end
        }

        stopmasterd(false)
    end

    def test_normalstart
        file = File.join($puppetbase, "examples", "code", "head")
        startmasterd("--manifest #{file}")

        assert_nothing_raised {
            socket = TCPSocket.new("127.0.0.1", Puppet[:masterport])
            socket.close
        }

        client = nil
        assert_nothing_raised() {
            client = XMLRPC::Client.new("localhost", "/RPC2", Puppet[:masterport],
                nil, nil, nil, nil, true, 5)
        }
        retval = nil

        assert_nothing_raised() {
            retval = client.call("status.status", "")
        }
        assert_equal(1, retval)
        facts = {}
        Facter.each { |p,v|
            facts[p] = v
        }
        textfacts = CGI.escape(Marshal::dump(facts))
        assert_nothing_raised() {
            #Puppet.notice "calling status"
            #retval = client.call("status.status", "")
            retval = client.call("puppetmaster.getconfig", textfacts)
        }

        objects = nil
        assert_nothing_raised {
            Marshal::load(CGI.unescape(retval))
        }
        #stopmasterd
    end

    def disabled_test_sslconnection
        #file = File.join($puppetbase, "examples", "code", "head")
        #startmasterd("--manifest #{file}")

        #assert_nothing_raised {
        #    socket = TCPSocket.new("127.0.0.1", Puppet[:masterport])
        #    socket.close
        #}

        client = nil
        cert, key, cacert, cacertfile = getcerts()

        assert_nothing_raised() {
            client = Net::HTTP.new("localhost", Puppet[:masterport])
            client.cert = cert
            client.key = key
            client.ca_file = cacertfile
            client.use_ssl = true
            client.start_immediately = true
        }
        retval = nil

        assert_nothing_raised() {
            retval = client.nothing
        }
        assert_equal(1, retval)
        facts = {}
        Facter.each { |p,v|
            facts[p] = v
        }
        textfacts = CGI.escape(Marshal::dump(facts))
        assert_nothing_raised() {
            #Puppet.notice "calling status"
            #retval = client.call("status.status", "")
            retval = client.call("puppetmaster.getconfig", textfacts)
        }

        objects = nil
        assert_nothing_raised {
            Marshal::load(CGI.unescape(retval))
        }
        #stopmasterd
    end
end
