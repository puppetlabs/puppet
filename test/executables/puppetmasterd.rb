#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'puppet'
require 'puppet/network/client'
require 'puppettest'
require 'socket'

class TestPuppetMasterD < Test::Unit::TestCase
    include PuppetTest::ExeTest
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

        pidfile = File.join(Puppet[:vardir], "run", "puppetmasterd.pid")
        assert(FileTest.exists?(pidfile), "PID file does not exist")

        sleep(1)
        assert_nothing_raised {
            socket = TCPSocket.new("127.0.0.1", @@port)
            socket.close
        }

        client = nil
        assert_nothing_raised() {
            client = Puppet::Network::Client.status.new(
                :Server => "localhost",
                :Port => @@port
            )
        }

        # set our client up to auto-sign
        assert(Puppet[:autosign] =~ /^#{File::SEPARATOR}/,
            "Autosign is set to %s, not a file" % Puppet[:autosign])

        FileUtils.mkdir_p(File.dirname(Puppet[:autosign]))
        File.open(Puppet[:autosign], "w") { |f|
            f.puts Puppet[:certname]
        }

        retval = nil

        # init the client certs
        assert_nothing_raised() {
            client.cert
        }

        # call status
        assert_nothing_raised() {
            retval = client.status
        }
        assert_equal(1, retval, "Status.status return value was %s" % retval)

        # this client shoulduse the same certs
        assert_nothing_raised() {
            client = Puppet::Network::Client.master.new(
                :Server => "localhost",
                :Port => @@port
            )
        }
        assert_nothing_raised() {
            retval = client.getconfig
        }

        objects = nil
    end

    # verify that we can run puppetmasterd in parse-only mode
    def test_parseonly
        startmasterd("--parseonly > /dev/null")
        sleep(1)

        pid = nil
        ps = Facter["ps"].value || "ps -ef"
        %x{#{ps}}.chomp.split(/\n/).each { |line|
            next if line =~ /^puppet/ # skip normal master procs
            if line =~ /puppetmasterd.+--manifest/
                ary = line.split(" ")
                pid = ary[1].to_i
            end
        }

        assert($? == 0, "Puppetmasterd ended with non-zero exit status")

        assert_nil(pid, "Puppetmasterd is still running after parseonly")
    end

    def disabled_test_sslconnection
        #file = File.join(exampledir, "code", "head")
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
        textfacts = CGI.escape(YAML.dump(facts))
        assert_nothing_raised() {
            #Puppet.notice "calling status"
            #retval = client.call("status.status", "")
            retval = client.call("puppetmaster.getconfig", textfacts, "yaml")
        }

        objects = nil
        assert_nothing_raised {
            YAML.load(CGI.unescape(retval))
        }
        #stopmasterd
    end
end

