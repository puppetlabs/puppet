#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'puppettest/support/utils'
require 'puppettest/support/assertions'
require 'puppet/network/client/resource'

class TestResourceClient < Test::Unit::TestCase
    include PuppetTest::ServerTest
    include PuppetTest::Support::Utils

    def setup
        super

        Puppet::Type.type(:user).provider(:directoryservice).stubs(:get_macosx_version_major).returns "10.5"
    end

    def mkresourceserver
        Puppet::Network::Handler.resource.new
    end

    def mkclient
        client = Puppet::Network::Client.resource.new(:Resource => mkresourceserver)
    end

    def test_resources
        file = tempfile()
        text = "yayness\n"
        File.open(file, "w") { |f| f.print text }

        mkresourceserver()

        client = mkclient()

        # Test describing
        tresource = client.describe("file", file)

        assert(tresource, "Did not get response")

        assert_instance_of(Puppet::TransObject, tresource)

        resource = tresource.to_ral
        assert_events([], resource)
        File.unlink(file)
        assert_events([:file_created], resource)
        File.unlink(file)

        # Now test applying
        result = client.apply(tresource)
        assert(FileTest.exists?(file), "File was not created on apply")
    end
end

