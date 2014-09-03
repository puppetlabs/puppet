#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/resource/catalog'

describe "Puppet::Resource::Catalog::Queue" do
  before do
    Puppet::Resource::Catalog.indirection.terminus(:queue)
    @catalog = Puppet::Resource::Catalog.new("foo", Puppet::Node::Environment::NONE)

    @one = Puppet::Resource.new(:file, "/one")
    @two = Puppet::Resource.new(:file, "/two")
    @catalog.add_resource(@one, @two)

    @catalog.add_edge(@one, @two)

    Puppet[:trace] = true
  end

  it "should render catalogs to pson and publish them via the queue client when catalogs are saved" do
    terminus = Puppet::Resource::Catalog.indirection.terminus(:queue)

    client = mock 'client'
    terminus.stubs(:client).returns client

    client.expects(:publish_message).with(:catalog, @catalog.to_pson)

    request = Puppet::Indirector::Request.new(:catalog, :save, "foo", @catalog)

    terminus.save(request)
  end

  it "should intern catalog messages when they are passed via a subscription" do
    client = mock 'client'
    Puppet::Resource::Catalog::Queue.stubs(:client).returns client

    pson = @catalog.to_pson

    client.expects(:subscribe).with(:catalog).yields(pson)

    Puppet.expects(:err).never

    result = []
    Puppet::Resource::Catalog::Queue.subscribe do |catalog|
      result << catalog
    end

    catalog = result.shift
    catalog.should be_instance_of(Puppet::Resource::Catalog)

    catalog.resource(:file, "/one").should be_instance_of(Puppet::Resource)
    catalog.resource(:file, "/two").should be_instance_of(Puppet::Resource)
    catalog.should be_edge(catalog.resource(:file, "/one"), catalog.resource(:file, "/two"))
  end
end
