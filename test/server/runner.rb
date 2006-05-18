if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/server/runner'
require 'test/unit'
require 'puppettest.rb'

class TestServerRunner < Test::Unit::TestCase
	include TestPuppet

    def mkclient(file)
        master = nil
        client = nil
        # create our master
        assert_nothing_raised() {
            # this is the default server setup
            master = Puppet::Server::Master.new(
                :Manifest => file,
                :UseNodes => false,
                :Local => true
            )
        }

        # and our client
        assert_nothing_raised() {
            client = Puppet::Client::MasterClient.new(
                :Master => master
            )
        }

        client
    end

    def test_runner
        # Okay, make our manifest
        file = tempfile()
        created = tempfile()
        File.open(file, "w") do |f|
            f.puts %{file { "#{created}": ensure => file }}
        end

        client = mkclient(file)

        runner = nil
        assert_nothing_raised {
            runner = Puppet::Server::Runner.new
        }

        assert_nothing_raised {
            # Try it without backgrounding
            runner.run(nil, nil, false)
        }

        assert(FileTest.exists?(created), "File did not get created")

        # Now background it
        File.unlink(created)

        assert_nothing_raised {
            runner.run(nil, nil, true)
        }

        Puppet.join

        assert(FileTest.exists?(created), "File did not get created")

    end
end

# $Id$

