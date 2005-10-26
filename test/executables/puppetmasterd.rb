if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
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

class TestPuppetMasterD < Test::Unit::TestCase
	include ExeTest
    def getcerts
        include Puppet::Daemon
        if self.readcerts
            return [@cert, @key, @cacert, @cacertfile]
        else
            raise "Couldn't read certs"
        end
    end

    # start the daemon and verify it responds and such
    def test_normalstart
        startmasterd

        assert_nothing_raised {
            socket = TCPSocket.new("127.0.0.1", @@port)
            socket.close
        }

        client = nil
        assert_nothing_raised() {
            client = Puppet::Client::StatusClient.new(
                :Server => "localhost",
                :Port => @@port
            )
        }

        # set our client up to auto-sign
        assert(Puppet[:autosign] =~ /^#{File::SEPARATOR}/,
            "Autosign is set to %s, not a file" % Puppet[:autosign])

        FileUtils.mkdir_p(File.dirname(Puppet[:autosign]))
        File.open(Puppet[:autosign], "w") { |f|
            f.puts client.fqdn
        }

        retval = nil

        # init the client certs
        assert_nothing_raised() {
            client.initcerts
        }

        # call status
        assert_nothing_raised() {
            retval = client.status
        }
        assert_equal(1, retval, "Status.status return value was %s" % retval)

        # this client shoulduse the same certs
        assert_nothing_raised() {
            client = Puppet::Client::MasterClient.new(
                :Server => "localhost",
                :Port => @@port
            )
        }
        assert_nothing_raised() {
            #Puppet.notice "calling status"
            #retval = client.call("status.status", "")
            retval = client.getconfig
        }

        objects = nil
        assert_instance_of(Puppet::TransBucket, retval,
            "Retrieved non-transportable object")
        stopmasterd
        sleep(1)
    end

    # verify that we can run puppetmasterd in parse-only mode
    def test_parseonly
        startmasterd("--parseonly")
        sleep(1)

        pid = nil
        ps = Facter["ps"].value || "ps -ef"
        %x{#{ps}}.chomp.split(/\n/).each { |line|
            if line =~ /puppetmasterd --manifest/
                ary = line.split(" ")
                pid = ary[1].to_i
            end
        }

        assert($? == 0, "Puppetmasterd ended with non-zero exit status")

        assert_nil(pid, "Puppetmasterd is still running after parseonly")
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
        assert_equal(1, retval, "return value was %s" % retval)
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
