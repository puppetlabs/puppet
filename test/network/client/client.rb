#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'mocha'
require 'puppet/network/client'

class TestClient < Test::Unit::TestCase
    include PuppetTest::ServerTest
    class FakeClient < Puppet::Network::Client
        @drivername = :Test
    end

    class FakeDriver
    end

    def test_client_loading
        # Make sure we don't get a failure but that we also get nothing back
        assert_nothing_raised do
            assert_nil(Puppet::Network::Client.client(:fake),
                "Got something back from a missing client")
            assert_nil(Puppet::Network::Client.fake,
                "Got something back from missing client method")
        end
        # Make a fake client
        dir = tempfile()
        libdir = File.join([dir, %w{puppet network client}].flatten)
        FileUtils.mkdir_p(libdir)

        file = File.join(libdir, "faker.rb")
        File.open(file, "w") do |f|
            f.puts %{class Puppet::Network::Client
                class Faker < Client
                end
            end
            }
        end

        $: << dir
        cleanup { $:.delete(dir) if $:.include?(dir) }

        client = nil
        assert_nothing_raised do
            client = Puppet::Network::Client.client(:faker)
        end
        assert(client, "did not load client")
        assert_nothing_raised do
            assert_equal(client, Puppet::Network::Client.faker,
                "Did not get client back from client method")
        end

        # Now make sure the client behaves correctly
        assert_equal(:Faker, client.name, "name was not calculated correctly")
    end

    # Make sure we get a client class for each handler type.
    def test_loading_all_clients
        %w{ca dipper file report resource runner status}.each do |name|
            client = nil
            assert_nothing_raised do
                client = Puppet::Network::Client.client(name)
            end
            assert(client, "did not get client for %s" % name)
            [:name, :handler, :drivername].each do |thing|
                assert(client.send(thing), "did not get %s for %s" % [thing, name])
            end
        end
    end
end
