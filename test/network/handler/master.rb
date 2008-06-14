#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'puppet/network/handler/master'

class TestMaster < Test::Unit::TestCase
    include PuppetTest::ServerTest

    def setup
        super
        @master = Puppet::Network::Handler.master.new(:Manifest => tempfile)

        @catalog = stub 'catalog', :extract => ""
        Puppet::Node::Catalog.stubs(:find).returns(@catalog)
    end

    def teardown
        super
        Puppet::Util::Cacher.invalidate
    end

    def test_freshness_is_always_now
        now1 = mock 'now1'
        Time.expects(:now).returns(now1)

        assert_equal(@master.freshness, now1, "Did not return current time as freshness")
    end

    def test_hostname_is_used_if_client_is_missing
        @master.expects(:decode_facts).returns("hostname" => "yay")
        Puppet::Node::Facts.expects(:new).with { |name, facts| name == "yay" }.returns(stub('facts', :save => nil))

        @master.getconfig("facts")
    end

    def test_facts_are_saved
        facts = mock('facts')
        Puppet::Node::Facts.expects(:new).returns(facts)
        facts.expects(:save)

        @master.stubs(:decode_facts)

        @master.getconfig("facts", "yaml", "foo.com")
    end

    def test_catalog_is_used_for_compiling
        facts = stub('facts', :save => nil)
        Puppet::Node::Facts.stubs(:new).returns(facts)

        @master.stubs(:decode_facts)

        Puppet::Node::Catalog.expects(:find).with("foo.com").returns(@catalog)

        @master.getconfig("facts", "yaml", "foo.com")
    end
end
