require 'spec_helper'

require 'puppet/resource/catalog'

Puppet::Resource::Catalog.indirection.terminus(:compiler)

describe Puppet::Resource::Catalog::Compiler do
  before do
    allow(Facter).to receive(:value).and_return("something")
    @catalog = Puppet::Resource::Catalog.new("testing", Puppet::Node::Environment::NONE)
    @catalog.add_resource(@one = Puppet::Resource.new(:file, "/one"))
    @catalog.add_resource(@two = Puppet::Resource.new(:file, "/two"))
  end

  it "should remove virtual resources when filtering" do
    @one.virtual = true
    expect(Puppet::Resource::Catalog.indirection.terminus.filter(@catalog).resource_refs).to eq([ @two.ref ])
  end

  it "should not remove exported resources when filtering" do
    @one.exported = true
    expect(Puppet::Resource::Catalog.indirection.terminus.filter(@catalog).resource_refs.sort).to eq([ @one.ref, @two.ref ])
  end

  it "should remove virtual exported resources when filtering" do
    @one.exported = true
    @one.virtual = true
    expect(Puppet::Resource::Catalog.indirection.terminus.filter(@catalog).resource_refs).to eq([ @two.ref ])
  end

  it "should filter out virtual resources when finding a catalog" do
    Puppet[:node_terminus] = :memory
    Puppet::Node.indirection.save(Puppet::Node.new("mynode"))
    allow(Puppet::Resource::Catalog.indirection.terminus).to receive(:extract_facts_from_request)
    allow(Puppet::Resource::Catalog.indirection.terminus).to receive(:compile).and_return(@catalog)

    @one.virtual = true

    expect(Puppet::Resource::Catalog.indirection.find("mynode").resource_refs).to eq([ @two.ref ])
  end

  it "should not filter out exported resources when finding a catalog" do
    Puppet[:node_terminus] = :memory
    Puppet::Node.indirection.save(Puppet::Node.new("mynode"))
    allow(Puppet::Resource::Catalog.indirection.terminus).to receive(:extract_facts_from_request)
    allow(Puppet::Resource::Catalog.indirection.terminus).to receive(:compile).and_return(@catalog)

    @one.exported = true

    expect(Puppet::Resource::Catalog.indirection.find("mynode").resource_refs.sort).to eq([ @one.ref, @two.ref ])
  end

  it "should filter out virtual exported resources when finding a catalog" do
    Puppet[:node_terminus] = :memory
    Puppet::Node.indirection.save(Puppet::Node.new("mynode"))
    allow(Puppet::Resource::Catalog.indirection.terminus).to receive(:extract_facts_from_request)
    allow(Puppet::Resource::Catalog.indirection.terminus).to receive(:compile).and_return(@catalog)

    @one.exported = true
    @one.virtual = true

    expect(Puppet::Resource::Catalog.indirection.find("mynode").resource_refs).to eq([ @two.ref ])
  end

  it "filters out virtual exported resources using the agent's production environment" do
    Puppet[:node_terminus] = :memory
    Puppet::Node.indirection.save(Puppet::Node.new("mynode"))

    catalog_environment = nil
    expect_any_instance_of(Puppet::Parser::Resource::Catalog).to receive(:to_resource) {catalog_environment = Puppet.lookup(:current_environment).name}

    Puppet::Resource::Catalog.indirection.find("mynode")
    expect(catalog_environment).to eq(:production)
  end
end
