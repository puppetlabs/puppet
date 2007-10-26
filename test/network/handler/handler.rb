#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'puppet/network/handler'

class TestHandler < Test::Unit::TestCase
    include PuppetTest::ServerTest

    def test_load_handlers
        # Make sure we don't get a failure but that we also get nothing back
        assert_nothing_raised do
            assert_nil(Puppet::Network::Handler.handler(:fake),
                "Got something back from a missing handler")
        end
        # Make a fake handler
        dir = tempfile()
        libdir = File.join([dir, %w{puppet network handler}].flatten)
        FileUtils.mkdir_p(libdir)

        file = File.join(libdir, "fake.rb")
        File.open(file, "w") do |f|
            f.puts %{class Puppet::Network::Handler
                class Fake < Handler
                end
            end
            }
        end

        $: << dir
        cleanup { $:.delete(dir) if $:.include?(dir) }

        handler = nil
        assert_nothing_raised do
            handler = Puppet::Network::Handler.handler(:fake)
        end
        assert(handler, "did not load handler")

        # Now make sure the handler behaves correctly
        assert_equal(:Fake, handler.name, "name was not calculated correctly")

        Puppet[:trace] = false
        assert_raise(Puppet::DevError,
            "did not throw an error on missing interface") do
                handler.interface
        end
    end

    def test_handlers_by_name
        %w{ca filebucket fileserver master report resource runner status}.each do |name|
            handler = nil
            assert_nothing_raised do
                handler = Puppet::Network::Handler.handler(name)
            end
            assert(handler, "did not get handler for %s" % name)
            assert(handler.name, "did not get name for %s" % name)
            assert(handler.interface, "did not get interface for %s" % name)
            assert(handler.interface.prefix, "did not get interface prefix for %s" % name)
        end
    end
end

