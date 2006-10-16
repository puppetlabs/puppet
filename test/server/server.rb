#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/server'
require 'puppettest'

# $Id$

if ARGV.length > 0 and ARGV[0] == "short"
    $short = true
else
    $short = false
end

class TestServer < Test::Unit::TestCase
    include PuppetTest::ServerTest

    # test that we can connect to the server
    # we have to use fork here, because we apparently can't use threads
    # to talk to other threads
    def test_connect_with_fork
        Puppet[:autosign] = true
        serverpid, server = mk_status_server

        # create a status client, and verify it can talk
        client = mk_status_client

        retval = nil
        assert_nothing_raised() {
            retval = client.status
        }
        assert_equal(1, retval)
    end

    # similar to the last test, but this time actually run getconfig
    def test_getconfig_with_fork
        Puppet[:autosign] = true
        serverpid = nil

        file = mktestmanifest()

        server = nil
        # make our server again
        assert_nothing_raised() {
            server = Puppet::Server.new(
                :Port => @@port,
                :Handlers => {
                    :CA => {}, # so that certs autogenerate
                    :Master => {
                        :UseNodes => false,
                        :Manifest => file
                    },
                    :Status => nil
                }
            )

        }
        serverpid = fork {
            assert_nothing_raised() {
                #trap(:INT) { server.shutdown; Kernel.exit! }
                trap(:INT) { server.shutdown }
                server.start
            }
        }
        @@tmppids << serverpid

        client = nil

        # and then start a masterclient
        assert_nothing_raised() {
            client = Puppet::Client::MasterClient.new(
                :Server => "localhost",
                :Port => @@port
            )
        }
        retval = nil

        # and run getconfig a couple of times
        assert_nothing_raised() {
            retval = client.getconfig
        }

        # Try it again, just for kicks
        assert_nothing_raised() {
            retval = client.getconfig
        }
    end

    def test_setpidfile_setting
        Puppet[:setpidfile] = false
        server = nil
        assert_nothing_raised() {
            server = Puppet::Server.new(
                :Port => @@port,
                :Handlers => {
                    :CA => {}, # so that certs autogenerate
                    :Status => nil
                }
            )

        }

        assert_nothing_raised {
            server.setpidfile
        }

        assert(! FileTest.exists?(server.pidfile), "PID file was created")
        Puppet[:setpidfile] = true

        assert_nothing_raised {
            server.setpidfile
        }
        assert(FileTest.exists?(server.pidfile), "PID file was not created")
    end


    # Test that a client whose cert has been revoked really can't connect
    def test_certificate_revocation
        Puppet[:autosign] = true

        serverpid, server = mk_status_server

        client = mk_status_client

        status = nil
        assert_nothing_raised() {
            status = client.status
        }
        assert_equal(1, status)
        client.shutdown

        # Revoke the client's cert
        ca = Puppet::SSLCertificates::CA.new()
        fqdn = client.fqdn
        ca.revoke(ca.getclientcert(fqdn)[0].serial)

        # Restart the server
        @@port += 1
        Puppet[:autosign] = false
        kill_and_wait(serverpid, server.pidfile)
        serverpid, server = mk_status_server

        client = mk_status_client
        # This time the client should be denied
        assert_raise(Puppet::NetworkClientError) {
            client.status
        }
    end
    
    def mk_status_client
        client = nil
        # Otherwise, the client initalization will trip over itself
        # since elements created in the last run are still around
        Puppet::Type::allclear

        assert_nothing_raised() {
            client = Puppet::Client::StatusClient.new(
                :Server => "localhost",
                :Port => @@port
            )
        }
        client
    end

    def mk_status_server
        server = nil
        assert_nothing_raised() {
            server = Puppet::Server.new(
                :Port => @@port,
                :Handlers => {
                    :CA => {}, # so that certs autogenerate
                    :Status => nil
                }
            )

        }
        pid = fork {
            assert_nothing_raised() {
                trap(:INT) { server.shutdown }
                server.start
            }
        }
        @@tmppids << pid
        [pid, server]
    end

    def kill_and_wait(pid, file)
        %x{kill -INT #{pid} 2>/dev/null}
        count = 0
        while count < 30 && File::exist?(file)
            count += 1
            sleep(1)
        end
        assert(count < 30, "Killing server #{pid} failed")
    end
end
