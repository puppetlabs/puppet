if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'puppet'
require 'cgi'
#require 'puppet/server'
require 'facter'
require 'puppet/client'
require 'xmlrpc/client'
require 'test/unit'
require 'puppettest.rb'

# $Id$

if ARGV.length > 0 and ARGV[0] == "short"
    $short = true
else
    $short = false
end

class TestServer < Test::Unit::TestCase
	include ServerTest

    # test that we can connect to the server
    # we have to use fork here, because we apparently can't use threads
    # to talk to other threads
    def test_connect_with_fork
        server = nil
        Puppet[:autosign] = true

        # create a server just serving status
        assert_nothing_raised() {
            server = Puppet::Server.new(
                :Port => @@port,
                :Handlers => {
                    :CA => {}, # so that certs autogenerate
                    :Status => nil
                }
            )

        }

        # and fork
        serverpid = fork {
            assert_nothing_raised() {
                trap(:INT) { server.shutdown }
                server.start
            }
        }
        @@tmppids << serverpid

        # create a status client, and verify it can talk
        client = nil
        assert_nothing_raised() {
            client = Puppet::Client::StatusClient.new(
                :Server => "localhost",
                :Port => @@port
            )
        }
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
                        :File => file
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
end
