#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/catalog/compiler'

describe Puppet::Resource::Catalog::Compiler do
  before do
    Facter.stubs(:to_hash).returns({})
  end

  describe "when initializing" do
    before do
      Puppet.expects(:version).returns(1)
      Facter.expects(:value).with('fqdn').returns("my.server.com")
      Facter.expects(:value).with('ipaddress').returns("my.ip.address")
    end

    it "should gather data about itself" do
      Puppet::Resource::Catalog::Compiler.new
    end

    it "should cache the server metadata and reuse it" do
      Puppet[:node_terminus] = :memory
      Puppet::Node.indirection.save(Puppet::Node.new("node1"))
      Puppet::Node.indirection.save(Puppet::Node.new("node2"))

      compiler = Puppet::Resource::Catalog::Compiler.new
      compiler.stubs(:compile)

      compiler.find(Puppet::Indirector::Request.new(:catalog, :find, 'node1', nil, :node => 'node1'))
      compiler.find(Puppet::Indirector::Request.new(:catalog, :find, 'node2', nil, :node => 'node2'))
    end
  end

  describe "when finding catalogs" do
    before do
      Facter.stubs(:value).returns("whatever")

      @compiler = Puppet::Resource::Catalog::Compiler.new
      @name = "me"
      @node = Puppet::Node.new @name
      @node.stubs(:merge)
      Puppet::Node.indirection.stubs(:find).returns @node
      @request = Puppet::Indirector::Request.new(:catalog, :find, @name, nil, :node => @name)
    end

    it "should directly use provided nodes for a local request" do
      Puppet::Node.indirection.expects(:find).never
      @compiler.expects(:compile).with(@node, anything)
      @request.stubs(:options).returns(:use_node => @node)
      @request.stubs(:remote?).returns(false)
      @compiler.find(@request)
    end

    it "rejects a provided node if the request is remote" do
      @request.stubs(:options).returns(:use_node => @node)
      @request.stubs(:remote?).returns(true)
      expect {
        @compiler.find(@request)
      }.to raise_error Puppet::Error, /invalid option use_node/i
    end

    it "should use the authenticated node name if no request key is provided" do
      @request.stubs(:key).returns(nil)
      Puppet::Node.indirection.expects(:find).with(@name, anything).returns(@node)
      @compiler.expects(:compile).with(@node, anything)
      @compiler.find(@request)
    end

    it "should use the provided node name by default" do
      @request.expects(:key).returns "my_node"

      Puppet::Node.indirection.expects(:find).with("my_node", anything).returns @node
      @compiler.expects(:compile).with(@node, anything)
      @compiler.find(@request)
    end

    it "should fail if no node is passed and none can be found" do
      Puppet::Node.indirection.stubs(:find).with(@name, anything).returns(nil)
      expect { @compiler.find(@request) }.to raise_error(ArgumentError)
    end

    it "should fail intelligently when searching for a node raises an exception" do
      Puppet::Node.indirection.stubs(:find).with(@name, anything).raises "eh"
      expect { @compiler.find(@request) }.to raise_error(Puppet::Error)
    end

    it "should pass the found node to the compiler for compiling" do
      Puppet::Node.indirection.expects(:find).with(@name, anything).returns(@node)
      config = mock 'config'
      Puppet::Parser::Compiler.expects(:compile).with(@node, anything)
      @compiler.find(@request)
    end

    it "should extract and save any facts from the request" do
      Puppet::Node.indirection.expects(:find).with(@name, anything).returns @node
      @compiler.expects(:extract_facts_from_request).with(@request)
      Puppet::Parser::Compiler.stubs(:compile)
      @compiler.find(@request)
    end

    it "requires `facts_format` option if facts are passed in" do
      facts = Puppet::Node::Facts.new("mynode", :afact => "avalue")
      request = Puppet::Indirector::Request.new(:catalog, :find, "mynode", nil, :facts => facts)
      expect {
        @compiler.find(request)
      }.to raise_error ArgumentError, /no fact format provided for mynode/
    end

    it "rejects facts in the request from a different node" do
      facts = Puppet::Node::Facts.new("differentnode", :afact => "avalue")
      request = Puppet::Indirector::Request.new(
        :catalog, :find, "mynode", nil, :facts => facts, :facts_format => "unused"
      )
      expect {
        @compiler.find(request)
      }.to raise_error Puppet::Error, /fact definition for the wrong node/i
    end

    it "should return the results of compiling as the catalog" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      catalog = Puppet::Resource::Catalog.new(@node.name)
      Puppet::Parser::Compiler.stubs(:compile).returns catalog

      expect(@compiler.find(@request)).to equal(catalog)
    end

    it "passes the code_id from the request to the compiler" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      code_id = 'b59e5df0578ef411f773ee6c33d8073c50e7b8fe'
      @request.options[:code_id] = code_id

      Puppet::Parser::Compiler.expects(:compile).with(anything, code_id)

      @compiler.find(@request)
    end

    it "returns a catalog with the code_id from the request" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      code_id = 'b59e5df0578ef411f773ee6c33d8073c50e7b8fe'
      @request.options[:code_id] = code_id

      catalog = Puppet::Resource::Catalog.new(@node.name, @node.environment, code_id)
      Puppet::Parser::Compiler.stubs(:compile).returns catalog

      expect(@compiler.find(@request).code_id).to eq(code_id)
    end

    it "does not inline metadata when the static_catalog option is false" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      @request.options[:static_catalog] = false
      @node.environment.stubs(:static_catalogs?).returns true

      catalog = Puppet::Resource::Catalog.new(@node.name, @node.environment)
      Puppet::Parser::Compiler.stubs(:compile).returns catalog

      @compiler.expects(:inline_metadata).never
      expect(@compiler.find(@request)).to eq(catalog)
    end

    it "does not inline metadata when static_catalogs are disabled" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'md5'
      @node.environment.stubs(:static_catalogs?).returns false

      catalog = Puppet::Resource::Catalog.new(@node.name, @node.environment)
      Puppet::Parser::Compiler.stubs(:compile).returns catalog

      @compiler.expects(:inline_metadata).never
      expect(@compiler.find(@request)).to eq(catalog)
    end

    it "inlines metadata when the static_catalog option is true and static_catalogs are enabled" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'sha256'
      @node.environment.stubs(:static_catalogs?).returns true

      catalog = Puppet::Resource::Catalog.new(@node.name, @node.environment)
      Puppet::Parser::Compiler.stubs(:compile).returns catalog

      @compiler.expects(:inline_metadata).with(catalog, :sha256).returns catalog
      expect(@compiler.find(@request)).to eq(catalog)
    end

    it "inlines metadata with the first common checksum type" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'atime.md5.sha256.mtime'
      @node.environment.stubs(:static_catalogs?).returns true

      catalog = Puppet::Resource::Catalog.new(@node.name, @node.environment)
      Puppet::Parser::Compiler.stubs(:compile).returns catalog

      @compiler.expects(:inline_metadata).with(catalog, :md5).returns catalog
      expect(@compiler.find(@request)).to eq(catalog)
    end

    it "errors if checksum_type contains no shared checksum types" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'atime.sha512'
      @node.environment.stubs(:static_catalogs?).returns true

      expect { @compiler.find(@request) }.to raise_error Puppet::Error,
        "Unable to find a common checksum type between agent 'atime.sha512' and master '[:sha256, :sha256lite, :md5, :md5lite, :sha1, :sha1lite, :mtime, :ctime, :none]'."
    end

    it "errors if checksum_type contains no shared checksum types" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = nil
      @node.environment.stubs(:static_catalogs?).returns true

      expect { @compiler.find(@request) }.to raise_error Puppet::Error,
        "Unable to find a common checksum type between agent '' and master '[:sha256, :sha256lite, :md5, :md5lite, :sha1, :sha1lite, :mtime, :ctime, :none]'."
    end
  end

  describe "when extracting facts from the request" do
    before do
      Puppet::Node::Facts.indirection.terminus_class = :memory
      Facter.stubs(:value).returns "something"
      @compiler = Puppet::Resource::Catalog::Compiler.new

      @facts = Puppet::Node::Facts.new('hostname', "fact" => "value", "architecture" => "i386")
    end

    def a_request_that_contains(facts)
      request = Puppet::Indirector::Request.new(:catalog, :find, "hostname", nil)
      request.options[:facts_format] = "pson"
      request.options[:facts] = CGI.escape(facts.render(:pson))
      request
    end

    it "should do nothing if no facts are provided" do
      request = Puppet::Indirector::Request.new(:catalog, :find, "hostname", nil)
      request.options[:facts] = nil

      expect(@compiler.extract_facts_from_request(request)).to be_nil
    end

    it "should deserialize the facts without changing the timestamp" do
      time = Time.now
      @facts.timestamp = time
      request = a_request_that_contains(@facts)
      facts = @compiler.extract_facts_from_request(request)
      expect(facts.timestamp).to eq(time)
    end

    it "should convert the facts into a fact instance and save it" do
      request = a_request_that_contains(@facts)

      options = {
        :environment => request.environment,
        :transaction_uuid => request.options[:transaction_uuid],
      }

      Puppet::Node::Facts.indirection.expects(:save).with(equals(@facts), nil, options)

      @compiler.extract_facts_from_request(request)
    end
  end

  describe "when finding nodes" do
    it "should look node information up via the Node class with the provided key" do
      Facter.stubs(:value).returns("whatever")
      node = Puppet::Node.new('node')
      compiler = Puppet::Resource::Catalog::Compiler.new
      request = Puppet::Indirector::Request.new(:catalog, :find, "me", nil)
      compiler.stubs(:compile)

      Puppet::Node.indirection.expects(:find).with("me", anything).returns(node)

      compiler.find(request)
    end

    it "should pass the transaction_uuid to the node indirection" do
      uuid = '793ff10d-89f8-4527-a645-3302cbc749f3'
      node = Puppet::Node.new("thing")
      compiler = Puppet::Resource::Catalog::Compiler.new
      compiler.stubs(:compile)
      request = Puppet::Indirector::Request.new(:catalog, :find, "thing",
                                                nil, :transaction_uuid => uuid)

      Puppet::Node.indirection.expects(:find).with(
        "thing",
        has_entries(:transaction_uuid => uuid)
      ).returns(node)

      compiler.find(request)
    end

    it "should pass the configured_environment to the node indirection" do
      environment = 'foo'
      node = Puppet::Node.new("thing")
      compiler = Puppet::Resource::Catalog::Compiler.new
      compiler.stubs(:compile)
      request = Puppet::Indirector::Request.new(:catalog, :find, "thing",
                                                nil, :configured_environment => environment)

      Puppet::Node.indirection.expects(:find).with(
        "thing",
        has_entries(:configured_environment => environment)
      ).returns(node)

      compiler.find(request)
    end
  end

  describe "after finding nodes" do
    before do
      Puppet.expects(:version).returns(1)
      Facter.expects(:value).with('fqdn').returns("my.server.com")
      Facter.expects(:value).with('ipaddress').returns("my.ip.address")
      @compiler = Puppet::Resource::Catalog::Compiler.new
      @node = Puppet::Node.new("me")
      @request = Puppet::Indirector::Request.new(:catalog, :find, "me", nil)
      @compiler.stubs(:compile)
      Puppet::Node.indirection.stubs(:find).with("me", anything).returns(@node)
    end

    it "should add the server's Puppet version to the node's parameters as 'serverversion'" do
      @node.expects(:merge).with { |args| args["serverversion"] == "1" }
      @compiler.find(@request)
    end

    it "should add the server's fqdn to the node's parameters as 'servername'" do
      @node.expects(:merge).with { |args| args["servername"] == "my.server.com" }
      @compiler.find(@request)
    end

    it "should add the server's IP address to the node's parameters as 'serverip'" do
      @node.expects(:merge).with { |args| args["serverip"] == "my.ip.address" }
      @compiler.find(@request)
    end
  end

  describe "when filtering resources" do
    before :each do
      Facter.stubs(:value)
      @compiler = Puppet::Resource::Catalog::Compiler.new
      @catalog = stub_everything 'catalog'
      @catalog.stubs(:respond_to?).with(:filter).returns(true)
    end

    it "should delegate to the catalog instance filtering" do
      @catalog.expects(:filter)
      @compiler.filter(@catalog)
    end

    it "should filter out virtual resources" do
      resource = mock 'resource', :virtual? => true
      @catalog.stubs(:filter).yields(resource)

      @compiler.filter(@catalog)
    end

    it "should return the same catalog if it doesn't support filtering" do
      @catalog.stubs(:respond_to?).with(:filter).returns(false)

      expect(@compiler.filter(@catalog)).to eq(@catalog)
    end

    it "should return the filtered catalog" do
      catalog = stub 'filtered catalog'
      @catalog.stubs(:filter).returns(catalog)

      expect(@compiler.filter(@catalog)).to eq(catalog)
    end

  end

  def build_catalog(node, num_resources, sources = nil, parameters = {:ensure => 'file'})
    catalog = Puppet::Resource::Catalog.new(node.name, node.environment)

    resources = []
    resources << Puppet::Resource.new("notify", "alpha")
    resources << Puppet::Resource.new("notify", "omega")

    0.upto(num_resources-1) do |idx|
      parameters.merge! :require => "Notify[alpha]", :before  => "Notify[omega]"
      if sources
        parameters.merge! :source => sources[idx % sources.size]
      end
      # The compiler does not operate on a RAL catalog, so we're
      # using Puppet::Resource to produce a resource catalog.
      agnostic_path = File.expand_path("/tmp/file_#{idx}.txt") # Windows Friendly
      rsrc = Puppet::Resource.new("file", agnostic_path, :parameters => parameters)
      rsrc.file = 'site.pp'
      rsrc.line = idx+1
      resources << rsrc
    end

    resources.each do |rsrc|
      catalog.add_resource(rsrc)
    end
    catalog
  end

  describe "when inlining metadata" do
    let(:node) { Puppet::Node.new 'me' }
    let(:num_resources) { 3 }
    let(:checksum_type) { 'md5' }
    before :each do
      @compiler = Puppet::Resource::Catalog::Compiler.new
    end

    [['md5', 'b1946ac92492d2347c6235b4d2611184'],
     ['sha256', '5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03']].each do |checksum_type, sha|
      describe "with agent requesting checksum_type #{checksum_type}" do
        it "sets checksum and checksum_value for resources with puppet:// source URIs" do
          catalog = build_catalog(node, num_resources, ['puppet:///modules/mymodule/config_file.txt'])
          catalog.resources.select {|r| r.type == 'File'}.each do |r|
            ral = r.to_ral
            r.expects(:to_ral).returns(ral)

            metadata = stub 'metadata'
            metadata.stubs(:checksum).returns("{#{checksum_type}}#{sha}")
            metadata.stubs(:ftype).returns("file")
            metadata.stubs(:inlinable).returns(true)

            source = stub 'source'
            source.stubs(:metadata).returns(metadata)

            ral.expects(:parameter).with(:source).returns(source)
          end

          expect(@compiler.send(:inline_metadata, catalog, checksum_type)).to eq(catalog)
          expect(catalog.resources.select {|r| r[:checksum_value] == sha}.size).to eq(num_resources)
        end
      end
    end

    describe "when inlining symlinks" do
      it "sets ensure and target for links which are managed" do
        catalog = build_catalog(node, 1, ['puppet:///modules/mymodule/config_file_link.txt'], {:ensure => 'link', :links => 'manage'})

        catalog.resources.select {|r| r.type == 'File'}.each do |r|
          ral = r.to_ral
          r.expects(:to_ral).returns(ral)

          metadata = stub 'metadata'
          metadata.stubs(:ftype).returns('link')
          metadata.stubs(:destination).returns('/tmp/some/absolute/path')

          source = stub 'source'
          source.stubs(:metadata).returns(metadata)

          ral.expects(:parameter).with(:source).returns(source)
        end

        expect(@compiler.send(:inline_metadata, catalog, checksum_type)).to eq(catalog)
        catalog.resources.select {|r| r.type == 'File'}.each do |r|
          expect(r[:ensure]).to eq('link')
          expect(r[:target]).to eq('/tmp/some/absolute/path')
          expect(r[:source]).to be_nil
        end
      end

      it "sets checksum and checksum_value for links which are followed" do
        catalog = build_catalog(node, 1, ['puppet:///modules/mymodule/config_file_link.txt'], {:ensure => 'link', :links => 'follow'})

        catalog.resources.select {|r| r.type == 'File'}.each do |r|
          ral = r.to_ral
          r.expects(:to_ral).returns(ral)

          metadata = stub 'metadata'
          metadata.stubs(:ftype).returns('file')
          metadata.stubs(:checksum).returns('{md5}b1946ac92492d2347c6235b4d2611184')

          source = stub 'source'
          source.stubs(:metadata).returns(metadata)

          ral.expects(:parameter).with(:source).returns(source)
        end

        expect(@compiler.send(:inline_metadata, catalog, checksum_type)).to eq(catalog)
        catalog.resources.select {|r| r.type == 'File'}.each do |r|
          expect(r[:checksum_value]).to eq('b1946ac92492d2347c6235b4d2611184')
          expect(r[:ensure]).to eq('file')
        end
      end

    end

    it "skips absent resources" do
      catalog = build_catalog(node, num_resources, nil, :ensure => 'absent')
      catalog.resources.select {|r| r.type == 'File'}.each do |r|
        r.expects(:to_ral).never
      end
      expect(@compiler.send(:inline_metadata, catalog, checksum_type)).to eq(catalog)
    end

    it "skips resources without a source" do
      catalog = build_catalog(node, num_resources)
      catalog.resources.select {|r| r.type == 'File'}.each do |r|
        r.expects(:to_ral).never
      end
      expect(@compiler.send(:inline_metadata, catalog, checksum_type)).to eq(catalog)
    end

    it "skips resources with a local source" do
      catalog = build_catalog(node, num_resources, ['/tmp/foo_source'])
      catalog.resources.select {|r| r.type == 'File'}.each do |r|
        r.expects(:to_ral).never
      end
      expect(@compiler.send(:inline_metadata, catalog, checksum_type)).to eq(catalog)
    end

    it "skips resources with a http source" do
      catalog = build_catalog(node, num_resources, ['http://foo.source.io', 'https://foo.source.io'])
      catalog.resources.select {|r| r.type == 'File'}.each do |r|
        r.expects(:to_ral).never
      end
      expect(@compiler.send(:inline_metadata, catalog, checksum_type)).to eq(catalog)
    end
  end
end
