#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/resource/catalog'


describe "Puppet::Resource::Catalog::Queue" do
  confine "Missing pson support; cannot test queue" => Puppet.features.pson?

  before do
    Puppet::Resource::Catalog.indirection.terminus(:queue)
    @catalog = Puppet::Resource::Catalog.new

    @one = Puppet::Resource.new(:file, "/one")
    @two = Puppet::Resource.new(:file, "/two")
    @catalog.add_resource(@one, @two)

    @catalog.add_edge(@one, @two)

    Puppet[:trace] = true
  end

  after { Puppet.settings.clear }

  it "should render catalogs to pson and send them via the queue client when catalogs are saved" do
    terminus = Puppet::Resource::Catalog.indirection.terminus(:queue)

    client = mock 'client'
    terminus.stubs(:client).returns client

    client.expects(:send_message).with(:catalog, @catalog.to_pson)

    request = Puppet::Indirector::Request.new(:catalog, :save, "foo", :instance => @catalog)

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
