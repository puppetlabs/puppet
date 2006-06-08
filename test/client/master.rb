if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/client'
require 'puppet/server'
require 'test/unit'
require 'puppettest.rb'

# $Id$

class TestMasterClient < Test::Unit::TestCase
	include ServerTest

    def mkmaster(file = nil)
        master = nil

        file ||= mktestmanifest()
        # create our master
        assert_nothing_raised() {
            # this is the default server setup
            master = Puppet::Server::Master.new(
                :Manifest => file,
                :UseNodes => false,
                :Local => true
            )
        }
        return master
    end

    def mkclient(master = nil)
        master ||= mkmaster()
        client = nil
        assert_nothing_raised() {
            client = Puppet::Client::MasterClient.new(
                :Master => master
            )
        }

        return client
    end

    def test_disable
        manifest = mktestmanifest

        master = mkmaster(manifest)

        client = mkclient(master)

        assert(! FileTest.exists?(@createdfile))

        assert_nothing_raised {
            client.disable
        }

        assert_nothing_raised {
            client.run
        }

        assert(! FileTest.exists?(@createdfile), "Disabled client ran")

        assert_nothing_raised {
            client.enable
        }

        assert_nothing_raised {
            client.run
        }

        assert(FileTest.exists?(@createdfile), "Enabled client did not run")
    end

    # Make sure we're getting the client version in our list of facts
    def test_clientversionfact
        facts = nil
        assert_nothing_raised {
            facts = Puppet::Client::MasterClient.facts
        }

        assert_equal(Puppet.version.to_s, facts["clientversion"])
        
    end

    # Make sure the client correctly locks itself
    def test_locking
        manifest = mktestmanifest

        master = nil

        # First test with a networked master
        client = Puppet::Client::MasterClient.new(
            :Server => "localhost"
        )

        assert_nothing_raised do
            client.lock do
                pid = nil
                assert(pid = client.locked?, "Client is not locked")
                assert(pid =~ /^\d+$/, "PID is, um, not a pid")
            end
        end
        assert(! client.locked?)

        # Now test with a local client
        client = mkclient

        assert_nothing_raised do
            client.lock do
                pid = nil
                assert(! client.locked?, "Local client is locked")
            end
        end
        assert(! client.locked?)
    end

    # Make sure non-string facts don't make things go kablooie
    def test_nonstring_facts
        # Add a nonstring fact
        Facter.add(:nonstring) do
            setcode { 1 }
        end

        assert_equal(1, Facter.nonstring, "Fact was a string from facter")

        client = mkclient()

        assert(! FileTest.exists?(@createdfile))

        assert_nothing_raised {
            client.run
        }
    end
end
