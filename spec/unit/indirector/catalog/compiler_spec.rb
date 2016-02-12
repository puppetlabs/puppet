#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'
require 'matchers/resource'

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
      @request.options[:code_id] = 'some_code_id'
      @node.environment.stubs(:static_catalogs?).returns true

      catalog = Puppet::Resource::Catalog.new(@node.name, @node.environment)
      Puppet::Parser::Compiler.stubs(:compile).returns catalog

      @compiler.expects(:inline_metadata).never
      @compiler.find(@request)
    end

    it "does not inline metadata when static_catalogs are disabled" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'md5'
      @request.options[:code_id] = 'some_code_id'
      @node.environment.stubs(:static_catalogs?).returns false

      catalog = Puppet::Resource::Catalog.new(@node.name, @node.environment)
      Puppet::Parser::Compiler.stubs(:compile).returns catalog

      @compiler.expects(:inline_metadata).never
      @compiler.find(@request)
    end

    it "does not inline metadata when code_id is not specified" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'md5'
      @node.environment.stubs(:static_catalogs?).returns true

      catalog = Puppet::Resource::Catalog.new(@node.name, @node.environment)
      Puppet::Parser::Compiler.stubs(:compile).returns catalog

      @compiler.expects(:inline_metadata).never
      expect(@compiler.find(@request)).to eq(catalog)
    end

    it "inlines metadata when the static_catalog option is true, static_catalogs are enabled, and a code_id is provided" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'sha256'
      @request.options[:code_id] = 'some_code_id'
      @node.environment.stubs(:static_catalogs?).returns true

      catalog = Puppet::Resource::Catalog.new(@node.name, @node.environment)
      Puppet::Parser::Compiler.stubs(:compile).returns catalog

      @compiler.expects(:inline_metadata).with(catalog, :sha256).returns catalog
      @compiler.find(@request)
    end

    it "inlines metadata with the first common checksum type" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'atime.md5.sha256.mtime'
      @request.options[:code_id] = 'some_code_id'
      @node.environment.stubs(:static_catalogs?).returns true

      catalog = Puppet::Resource::Catalog.new(@node.name, @node.environment)
      Puppet::Parser::Compiler.stubs(:compile).returns catalog

      @compiler.expects(:inline_metadata).with(catalog, :md5).returns catalog
      @compiler.find(@request)
    end

    it "errors if checksum_type contains no shared checksum types" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'atime.sha512'
      @request.options[:code_id] = 'some_code_id'
      @node.environment.stubs(:static_catalogs?).returns true

      expect { @compiler.find(@request) }.to raise_error Puppet::Error,
        "Unable to find a common checksum type between agent 'atime.sha512' and master '[:sha256, :sha256lite, :md5, :md5lite, :sha1, :sha1lite, :mtime, :ctime, :none]'."
    end

    it "errors if checksum_type contains no shared checksum types" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = nil
      @request.options[:code_id] = 'some_code_id'
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
    include PuppetSpec::Compiler
    include Matchers::Resource

    let(:node) { Puppet::Node.new 'me' }
    let(:num_resources) { 3 }
    let(:checksum_type) { 'md5' }
    let(:checksum_value) { 'b1946ac92492d2347c6235b4d2611184' }
    let(:path) { File.expand_path('/foo') }
    let(:resource_ref) { "File[#{path}]" }

    before :each do
      @compiler = Puppet::Resource::Catalog::Compiler.new
    end

    def stubs_file_metadata(checksum_type, sha, relative_path, full_path = nil)
      full_path ||=  File.join(Puppet[:environmentpath], 'production', relative_path)

      metadata = stub 'metadata'
      metadata.stubs(:ftype).returns("file")
      metadata.stubs(:full_path).returns(full_path)
      metadata.stubs(:relative_path).returns(relative_path)
      metadata.stubs(:source).returns("puppet:///#{relative_path}")
      metadata.stubs(:checksum).returns("{#{checksum_type}}#{sha}")
      metadata.stubs(:checksum_type).returns(checksum_type)

      Puppet::Type.type(:file).attrclass(:source).any_instance.stubs(:metadata).returns(metadata)

      metadata
    end

    def stubs_link_metadata(relative_path, destination)
      full_path =  File.join(Puppet[:environmentpath], 'production', relative_path)

      metadata = stub 'metadata'
      metadata.stubs(:ftype).returns("link")
      metadata.stubs(:full_path).returns(full_path)
      metadata.stubs(:relative_path).returns(relative_path)
      metadata.stubs(:source).returns("puppet:///#{relative_path}")
      metadata.stubs(:destination).returns('/tmp/some/absolute/path')

      Puppet::Type.type(:file).attrclass(:source).any_instance.stubs(:metadata).returns(metadata)

      metadata
    end

    def stubs_directory_metadata(relative_path)
      full_path =  File.join(Puppet[:environmentpath], 'production', relative_path)

      metadata = stub 'metadata'
      metadata.stubs(:ftype).returns("directory")
      metadata.stubs(:full_path).returns(full_path)
      metadata.stubs(:relative_path).returns(relative_path)
      metadata.stubs(:source).returns("puppet:///#{relative_path}")

      Puppet::Type.type(:file).attrclass(:source).any_instance.stubs(:metadata).returns(metadata)

      metadata
    end

    def stubs_top_directory_metadata(children)
      Puppet::Type.type(:file).any_instance.stubs(:recurse_remote_metadata).returns(children)

      stubs_directory_metadata('.')
    end

    def expects_no_source_metadata
      Puppet::Type.type(:file).attrclass(:source).any_instance.expects(:metadata).never
    end

    [['md5', 'b1946ac92492d2347c6235b4d2611184'],
     ['sha256', '5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03']].each do |checksum_type, sha|
      describe "with agent requesting checksum_type #{checksum_type}" do
        it "sets checksum and checksum_value for resources with puppet:// source URIs" do
          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { '#{path}':
              ensure => file,
              source => 'puppet:///modules/mymodule/config_file.txt'
            }
          MANIFEST

          stubs_file_metadata(checksum_type, sha, 'modules/mymodule/files/config_file.txt')

          @compiler.send(:inline_metadata, catalog, checksum_type)

          expect(catalog).to have_resource(resource_ref)
            .with_parameter(:ensure, 'file')
            .with_parameter(:checksum, checksum_type)
            .with_parameter(:checksum_value, sha)
            .with_parameter(:source, 'puppet:///modules/mymodule/config_file.txt')
        end
      end
    end

    describe "when inlining symlinks" do
      it "sets ensure and target for links which are managed" do
        catalog = compile_to_catalog(<<-MANIFEST, node)
          file { '#{path}':
            ensure => link,
            links  => manage,
            source => 'puppet:///modules/mymodule/config_file_link.txt'
          }
        MANIFEST

        stubs_link_metadata('modules/mymodule/files/config_file.txt', '/tmp/some/absolute/path')

        @compiler.send(:inline_metadata, catalog, checksum_type)

        expect(catalog).to have_resource(resource_ref)
          .with_parameter(:ensure, 'link')
          .with_parameter(:target, '/tmp/some/absolute/path')
          .with_parameter(:source, nil)
      end

      it "sets checksum and checksum_value for links which are followed" do
        catalog = compile_to_catalog(<<-MANIFEST, node)
           file { '#{path}':
            ensure => link,
            links  => follow,
            source => 'puppet:///modules/mymodule/config_file_link.txt'
          }
        MANIFEST

        stubs_file_metadata(checksum_type, checksum_value, 'modules/mymodule/files/config_file.txt')

        @compiler.send(:inline_metadata, catalog, checksum_type)

        expect(catalog).to have_resource(resource_ref)
          .with_parameter(:ensure, 'file')
          .with_parameter(:checksum, checksum_type)
          .with_parameter(:checksum_value, checksum_value)
          .with_parameter(:source, 'puppet:///modules/mymodule/config_file_link.txt')
      end
    end

    it "skips absent resources" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => absent,
        }
      MANIFEST

      expects_no_source_metadata

      @compiler.send(:inline_metadata, catalog, checksum_type)

      expect(catalog).to have_resource(resource_ref).with_parameter(:ensure, 'absent')
    end

    it "skips resources without a source" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => file,
        }
      MANIFEST

      expects_no_source_metadata

      @compiler.send(:inline_metadata, catalog, checksum_type)

      expect(catalog).to have_resource(resource_ref).with_parameter(:ensure, 'file')
    end

    it "skips resources with a local source" do
      local_source = File.expand_path('/tmp/source')

      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => file,
          source => '#{local_source}',
        }
      MANIFEST

      expects_no_source_metadata

      @compiler.send(:inline_metadata, catalog, checksum_type)

      expect(catalog).to have_resource(resource_ref)
        .with_parameter(:ensure, 'file')
        .with_parameter(:source, local_source)
    end

    it "skips resources with a http source" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => file,
          source => ['http://foo.source.io', 'https://foo.source.io']
        }
      MANIFEST

      expects_no_source_metadata

      @compiler.send(:inline_metadata, catalog, checksum_type)

      expect(catalog).to have_resource(resource_ref)
        .with_parameter(:ensure, 'file')
        .with_parameter(:source, ['http://foo.source.io', 'https://foo.source.io'])
    end

    it "skips resources with a source outside the environment path" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => file,
          source => 'puppet:///modules/mymodule/config_file.txt'
        }
      MANIFEST

      full_path = File.join(Puppet[:codedir], "modules/mymodule/files/config_file.txt")
      stubs_file_metadata(checksum_type, checksum_value, 'modules/mymodule/files/config_file.txt', full_path)

      @compiler.send(:inline_metadata, catalog, checksum_type)

      expect(catalog).to have_resource(resource_ref)
        .with_parameter(:ensure, 'file')
        .with_parameter(:source, 'puppet:///modules/mymodule/config_file.txt')
        .with_parameter(:checksum_value, nil)
    end

    describe "when inlining directories" do
      describe "when recurse is false" do
        it "skips children" do
          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { '#{path}':
              ensure  => directory,
              source  => 'puppet:///modules/mymodule/directory'
            }
          MANIFEST

          stubs_top_directory_metadata([])

          @compiler.send(:inline_metadata, catalog, checksum_type)

          expect(catalog).to have_resource(resource_ref)
            .with_parameter(:ensure, 'directory')
            .with_parameter(:source, 'puppet:///modules/mymodule/directory')
        end
      end

      describe "when recurse is true" do
        it "inlines child metadata" do
          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { '#{path}':
              ensure  => directory,
              recurse => true,
              source  => 'puppet:///modules/mymodule/directory'
            }
          MANIFEST

          child_metadata = stubs_file_metadata(checksum_type, checksum_value, 'myfile.txt')
          stubs_top_directory_metadata([child_metadata])

          @compiler.send(:inline_metadata, catalog, checksum_type)

          expect(catalog).to have_resource(resource_ref)
            .with_parameter(:ensure, 'directory')
            .with_parameter(:recurse, true) # REMIND this is surprising
            .with_parameter(:source, 'puppet:///modules/mymodule/directory')

          expect(catalog).to have_resource("File[#{path}/myfile.txt]")
            .with_parameter(:ensure, 'file')
            .with_parameter(:checksum, checksum_type)
            .with_parameter(:checksum_value, checksum_value)
        end

        it "copies containment relationships from the parent to all generated resources" do
          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { '#{path}':
              ensure  => directory,
              recurse => true,
              source  => 'puppet:///modules/mymodule/directory',
              before  => Notify['hi']
            }
            notify { 'hi' : }
          MANIFEST

          meta_a = stubs_directory_metadata('a')
          meta_b = stubs_file_metadata(checksum_type, checksum_value, 'a/b.txt')

          stubs_top_directory_metadata([meta_a, meta_b])

          @compiler.send(:inline_metadata, catalog, checksum_type)

          notify_hi = catalog.resource('Notify[hi]')
          file_a = catalog.resource("File[#{path}/a]")
          file_b = catalog.resource("File[#{path}/a/b.txt]")

          expect(catalog).to have_resource(resource_ref)
            .with_parameter(:before, [notify_hi, file_a])
          expect(catalog).to have_resource("File[#{path}/a]")
            .with_parameter(:before, [notify_hi, file_b])
        end

        it "copies multiple containment relationships from the parent to all generated resources" do
          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { '#{path}':
              ensure  => directory,
              recurse => true,
              source  => 'puppet:///modules/mymodule/directory',
              before  => [Notify['hi'], Notify['there']]
            }
            notify { 'hi' : }
            notify { 'there': }
          MANIFEST

          meta_a = stubs_directory_metadata('a')
          meta_b = stubs_file_metadata(checksum_type, checksum_value, 'a/b.txt')

          stubs_top_directory_metadata([meta_a, meta_b])

          @compiler.send(:inline_metadata, catalog, checksum_type)

          notify_hi = catalog.resource('Notify[hi]')
          notify_there = catalog.resource('Notify[there]')
          file_a = catalog.resource("File[#{path}/a]")
          file_b = catalog.resource("File[#{path}/a/b.txt]")

          expect(catalog).to have_resource(resource_ref)
            .with_parameter(:before, [notify_hi, notify_there, file_a])
          expect(catalog).to have_resource("File[#{path}/a]")
            .with_parameter(:before, [notify_hi, notify_there, file_b])
        end

        it "adds relationships from the generated child's parent to the child" do
          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { '#{path}':
              ensure  => directory,
              recurse => true,
              source  => 'puppet:///modules/mymodule/directory',
            }
          MANIFEST

          meta_a = stubs_directory_metadata('a')
          meta_b = stubs_file_metadata(checksum_type, checksum_value, 'a/b.txt')

          stubs_top_directory_metadata([meta_a, meta_b])

          @compiler.send(:inline_metadata, catalog, checksum_type)

          file_a = catalog.resource("File[#{path}/a]")
          file_b = catalog.resource("File[#{path}/a/b.txt]")

          expect(catalog).to have_resource(resource_ref)
            .with_parameter(:before, [file_a])
          expect(catalog).to have_resource("File[#{path}/a]")
            .with_parameter(:before, [file_b])
          expect(catalog).to have_resource("File[#{path}/a/b.txt]")
            .with_parameter(:before, [])
        end
      end
    end

    it "skips non-file resources" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
        notify { 'hi': }
      MANIFEST

      @compiler.send(:inline_metadata, catalog, checksum_type)

      expect(catalog).to have_resource('Notify[hi]').with_parameter(:name, 'hi')
    end

    it "preserves relationships to other resources" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
        notify { 'alpha': }
        notify { 'omega': }
        file { '#{path}':
          ensure  => file,
          source  => 'puppet:///modules/mymodule/config_file.txt',
          require => Notify[alpha],
          before  => Notify[omega]
        }
      MANIFEST

      stubs_file_metadata(checksum_type, checksum_value, 'modules/mymodule/files/config_file.txt')

      @compiler.send(:inline_metadata, catalog, checksum_type)

      expect(catalog).to have_resource(resource_ref)
        .with_parameter(:require, catalog.resource('Notify[alpha]'))
        .with_parameter(:before, catalog.resource('Notify[omega]'))
    end

    it "inlines windows file paths" do
      pending "Calling Puppet::Resource#to_ral on windows path is not safe on *nix master"

      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { 'c:/foo':
          ensure => file,
          source => 'puppet:///modules/mymodule/config_file.txt'
        }
      MANIFEST

      stubs_file_metadata(checksum_type, checksum_value, 'modules/mymodule/files/config_file.txt')

      @compiler.send(:inline_metadata, catalog, checksum_type)

      expect(catalog).to have_resource(resource_ref)
        .with_parameter(:ensure, 'file')
        .with_parameter(:checksum, checksum_type)
        .with_parameter(:checksum_value, checksum_value)
        .with_parameter(:source, 'puppet:///modules/mymodule/config_file.txt')
    end
  end
end
