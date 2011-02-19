#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'puppet/network/handler/master'

class TestMaster < Test::Unit::TestCase
  include PuppetTest::ServerTest

  def setup
    super
    @master = Puppet::Network::Handler.master.new(:Manifest => tempfile)

    @catalog = stub 'catalog', :extract => ""
    Puppet::Resource::Catalog.indirection.stubs(:find).returns(@catalog)
  end

  def teardown
    super
    Puppet::Util::Cacher.expire
  end

  def test_freshness_is_always_now
    now1 = mock 'now1'
    Time.stubs(:now).returns(now1)

    now1.expects(:to_i).returns 10

    assert_equal(@master.freshness, 10, "Did not return current time as freshness")
  end

  def test_hostname_is_used_if_client_is_missing
    @master.expects(:decode_facts).returns("hostname" => "yay")
    facts = Puppet::Node::Facts.new("the_facts")
    Puppet::Node::Facts.indirection.stubs(:save).with(facts)
    Puppet::Node::Facts.expects(:new).with { |name, facts| name == "yay" }.returns(facts)

    @master.getconfig("facts")
  end

  def test_facts_are_saved
    facts = Puppet::Node::Facts.new("the_facts")
    Puppet::Node::Facts.expects(:new).returns(facts)
    Puppet::Node::Facts.indirection.expects(:save).with(facts)

    @master.stubs(:decode_facts)

    @master.getconfig("facts", "yaml", "foo.com")
  end

  def test_catalog_is_used_for_compiling
    facts = Puppet::Node::Facts.new("the_facts")
    Puppet::Node::Facts.indirection.stubs(:save).with(facts)
    Puppet::Node::Facts.stubs(:new).returns(facts)

    @master.stubs(:decode_facts)

    Puppet::Resource::Catalog.indirection.expects(:find).with("foo.com").returns(@catalog)

    @master.getconfig("facts", "yaml", "foo.com")
  end
end

class TestMasterFormats < Test::Unit::TestCase
  def setup
    @facts = Puppet::Node::Facts.new("the_facts")
    Puppet::Node::Facts.stubs(:new).returns(@facts)
    Puppet::Node::Facts.indirection.stubs(:save)

    @master = Puppet::Network::Handler.master.new(:Code => "")
    @master.stubs(:decode_facts)

    @catalog = stub 'catalog', :extract => ""
    Puppet::Resource::Catalog.indirection.stubs(:find).returns(@catalog)
  end

  def test_marshal_can_be_used
    @catalog.expects(:extract).returns "myextract"

    Marshal.expects(:dump).with("myextract").returns "eh"

    @master.getconfig("facts", "marshal", "foo.com")
  end

  def test_yaml_can_be_used
    extract = mock 'extract'
    @catalog.expects(:extract).returns extract

    extract.expects(:to_yaml).returns "myaml"

    @master.getconfig("facts", "yaml", "foo.com")
  end

  def test_failure_when_non_yaml_or_marshal_is_used
    assert_raise(RuntimeError) { @master.getconfig("facts", "blah", "foo.com") }
  end
end
