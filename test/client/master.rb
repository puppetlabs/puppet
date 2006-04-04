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

    def mkmaster(file)
        master = nil
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

    def mkclient(master)
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
end
