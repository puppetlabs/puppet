#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'
require 'puppet/resource/catalog'
require 'puppet/indirector/catalog/json'

describe Puppet::Resource::Catalog::Json do
  include PuppetSpec::Files

  # This is it for local functionality
  it "should be registered with the catalog store indirection" do
    expect(Puppet::Resource::Catalog.indirection.terminus(:json)).
      to be_an_instance_of described_class
  end

  describe "when handling requests" do
    let(:binary) { "\xC0\xFF".force_encoding(Encoding::BINARY) }
    let(:key)    { 'foo' }
    let(:file)   { subject.path(key) }
    let(:catalog) do
      catalog = Puppet::Resource::Catalog.new(key, Puppet::Node::Environment.create(:testing, []))
      catalog.add_resource(Puppet::Resource.new(:file, '/tmp/a_file', :parameters => { :content => binary }))
      catalog
    end

    before :each do
      Puppet.run_mode.stubs(:master?).returns(true)
      Puppet[:server_datadir] = tmpdir('jsondir')
      FileUtils.mkdir_p(File.join(Puppet[:server_datadir], 'indirector_testing'))
    end

    it 'saves a catalog containing binary content' do
      request = subject.indirection.request(:save, key, catalog)

      subject.save(request)
    end

    it 'finds a catalog containing binary content' do
      request = subject.indirection.request(:save, key, catalog)
      subject.save(request)

      request = subject.indirection.request(:find, key, nil)
      parsed_catalog = subject.find(request)

      content = parsed_catalog.resource(:file, '/tmp/a_file')[:content]
      expect(content.bytes.to_a).to eq(binary.bytes.to_a)
    end

    it 'searches for catalogs contains binary content' do
      request = subject.indirection.request(:save, key, catalog)
      subject.save(request)

      request = subject.indirection.request(:search, '*', nil)
      parsed_catalogs = subject.search(request)

      expect(parsed_catalogs.size).to eq(1)
      content = parsed_catalogs.first.resource(:file, '/tmp/a_file')[:content]
      expect(content.bytes.to_a).to eq(binary.bytes.to_a)
    end
  end
end
