#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'
require 'matchers/resource'

require 'puppet/indirector/catalog/compiler'

describe Puppet::Resource::Catalog::Compiler do
  let(:compiler) { described_class.new }
  let(:node_name) { "foo" }
  let(:node) { Puppet::Node.new(node_name)}

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

      compiler.stubs(:compile)

      compiler.find(Puppet::Indirector::Request.new(:catalog, :find, 'node1', nil, :node => 'node1'))
      compiler.find(Puppet::Indirector::Request.new(:catalog, :find, 'node2', nil, :node => 'node2'))
    end
  end

  describe "when finding catalogs" do
    before do
      Facter.stubs(:value).returns("whatever")

      node.stubs(:merge)
      Puppet::Node.indirection.stubs(:find).returns(node)
      @request = Puppet::Indirector::Request.new(:catalog, :find, node_name, nil, :node => node_name)
    end

    it "should directly use provided nodes for a local request" do
      Puppet::Node.indirection.expects(:find).never
      compiler.expects(:compile).with(node, anything)
      @request.stubs(:options).returns(:use_node => node)
      @request.stubs(:remote?).returns(false)
      compiler.find(@request)
    end

    it "rejects a provided node if the request is remote" do
      @request.stubs(:options).returns(:use_node => node)
      @request.stubs(:remote?).returns(true)
      expect {
        compiler.find(@request)
      }.to raise_error Puppet::Error, /invalid option use_node/i
    end

    it "should use the authenticated node name if no request key is provided" do
      @request.stubs(:key).returns(nil)
      Puppet::Node.indirection.expects(:find).with(node_name, anything).returns(node)
      compiler.expects(:compile).with(node, anything)
      compiler.find(@request)
    end

    it "should use the provided node name by default" do
      @request.expects(:key).returns "my_node"

      Puppet::Node.indirection.expects(:find).with("my_node", anything).returns node
      compiler.expects(:compile).with(node, anything)
      compiler.find(@request)
    end

    it "should fail if no node is passed and none can be found" do
      Puppet::Node.indirection.stubs(:find).with(node_name, anything).returns(nil)
      expect { compiler.find(@request) }.to raise_error(ArgumentError)
    end

    it "should fail intelligently when searching for a node raises an exception" do
      Puppet::Node.indirection.stubs(:find).with(node_name, anything).raises "eh"
      expect { compiler.find(@request) }.to raise_error(Puppet::Error)
    end

    it "should pass the found node to the compiler for compiling" do
      Puppet::Node.indirection.expects(:find).with(node_name, anything).returns(node)
      Puppet::Parser::Compiler.expects(:compile).with(node, anything)
      compiler.find(@request)
    end

    it "should pass node containing percent character to the compiler" do
      node_with_percent_character = Puppet::Node.new "%6de"
      Puppet::Node.indirection.stubs(:find).returns(node_with_percent_character)
      Puppet::Parser::Compiler.expects(:compile).with(node_with_percent_character, anything)
      compiler.find(@request)
    end

    it "should extract any facts from the request" do
      Puppet::Node.indirection.expects(:find).with(node_name, anything).returns node
      compiler.expects(:extract_facts_from_request).with(@request)
      Puppet::Parser::Compiler.stubs(:compile)
      compiler.find(@request)
    end

    it "requires `facts_format` option if facts are passed in" do
      facts = Puppet::Node::Facts.new("mynode", :afact => "avalue")
      request = Puppet::Indirector::Request.new(:catalog, :find, "mynode", nil, :facts => facts)
      expect {
        compiler.find(request)
      }.to raise_error ArgumentError, /no fact format provided for mynode/
    end

    it "rejects facts in the request from a different node" do
      facts = Puppet::Node::Facts.new("differentnode", :afact => "avalue")
      request = Puppet::Indirector::Request.new(
        :catalog, :find, "mynode", nil, :facts => facts, :facts_format => "unused"
      )
      expect {
        compiler.find(request)
      }.to raise_error Puppet::Error, /fact definition for the wrong node/i
    end

    it "should return the results of compiling as the catalog" do
      Puppet::Node.indirection.stubs(:find).returns(node)
      catalog = Puppet::Resource::Catalog.new(node.name)
      Puppet::Parser::Compiler.stubs(:compile).returns catalog

      expect(compiler.find(@request)).to equal(catalog)
    end

    it "passes the code_id from the request to the compiler" do
      Puppet::Node.indirection.stubs(:find).returns(node)
      code_id = 'b59e5df0578ef411f773ee6c33d8073c50e7b8fe'
      @request.options[:code_id] = code_id

      Puppet::Parser::Compiler.expects(:compile).with(anything, code_id)

      compiler.find(@request)
    end

    it "returns a catalog with the code_id from the request" do
      Puppet::Node.indirection.stubs(:find).returns(node)
      code_id = 'b59e5df0578ef411f773ee6c33d8073c50e7b8fe'
      @request.options[:code_id] = code_id

      catalog = Puppet::Resource::Catalog.new(node.name, node.environment, code_id)
      Puppet::Parser::Compiler.stubs(:compile).returns catalog

      expect(compiler.find(@request).code_id).to eq(code_id)
    end

    it "does not inline metadata when the static_catalog option is false" do
      Puppet::Node.indirection.stubs(:find).returns(node)
      @request.options[:static_catalog] = false
      @request.options[:code_id] = 'some_code_id'
      node.environment.stubs(:static_catalogs?).returns true

      catalog = Puppet::Resource::Catalog.new(node.name, node.environment)
      Puppet::Parser::Compiler.stubs(:compile).returns catalog

      compiler.expects(:inline_metadata).never
      compiler.find(@request)
    end

    it "does not inline metadata when static_catalogs are disabled" do
      Puppet::Node.indirection.stubs(:find).returns(node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'md5'
      @request.options[:code_id] = 'some_code_id'
      node.environment.stubs(:static_catalogs?).returns false

      catalog = Puppet::Resource::Catalog.new(node.name, node.environment)
      Puppet::Parser::Compiler.stubs(:compile).returns catalog

      compiler.expects(:inline_metadata).never
      compiler.find(@request)
    end

    it "does not inline metadata when code_id is not specified" do
      Puppet::Node.indirection.stubs(:find).returns(node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'md5'
      node.environment.stubs(:static_catalogs?).returns true

      catalog = Puppet::Resource::Catalog.new(node.name, node.environment)
      Puppet::Parser::Compiler.stubs(:compile).returns catalog

      compiler.expects(:inline_metadata).never
      expect(compiler.find(@request)).to eq(catalog)
    end

    it "inlines metadata when the static_catalog option is true, static_catalogs are enabled, and a code_id is provided" do
      Puppet::Node.indirection.stubs(:find).returns(node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'sha256'
      @request.options[:code_id] = 'some_code_id'
      node.environment.stubs(:static_catalogs?).returns true

      catalog = Puppet::Resource::Catalog.new(node.name, node.environment)
      Puppet::Parser::Compiler.stubs(:compile).returns catalog

      compiler.expects(:inline_metadata).with(catalog, :sha256).returns catalog
      compiler.find(@request)
    end

    it "inlines metadata with the first common checksum type" do
      Puppet::Node.indirection.stubs(:find).returns(node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'atime.md5.sha256.mtime'
      @request.options[:code_id] = 'some_code_id'
      node.environment.stubs(:static_catalogs?).returns true

      catalog = Puppet::Resource::Catalog.new(node.name, node.environment)
      Puppet::Parser::Compiler.stubs(:compile).returns catalog

      compiler.expects(:inline_metadata).with(catalog, :md5).returns catalog
      compiler.find(@request)
    end

    it "errors if checksum_type contains no shared checksum types" do
      Puppet::Node.indirection.stubs(:find).returns(node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'atime.md2'
      @request.options[:code_id] = 'some_code_id'
      node.environment.stubs(:static_catalogs?).returns true

      expect { compiler.find(@request) }.to raise_error Puppet::Error,
        "Unable to find a common checksum type between agent 'atime.md2' and master '[:sha256, :sha256lite, :md5, :md5lite, :sha1, :sha1lite, :sha512, :sha384, :sha224, :mtime, :ctime, :none]'."
    end

    it "errors if checksum_type contains no shared checksum types" do
      Puppet::Node.indirection.stubs(:find).returns(node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = nil
      @request.options[:code_id] = 'some_code_id'
      node.environment.stubs(:static_catalogs?).returns true

      expect { compiler.find(@request) }.to raise_error Puppet::Error,
        "Unable to find a common checksum type between agent '' and master '[:sha256, :sha256lite, :md5, :md5lite, :sha1, :sha1lite, :sha512, :sha384, :sha224, :mtime, :ctime, :none]'."
    end
  end

  describe "when handling a request with facts" do
    before do
      Puppet::Node::Facts.indirection.terminus_class = :memory
      Facter.stubs(:value).returns "something"

      @facts = Puppet::Node::Facts.new('hostname', "fact" => "value", "architecture" => "i386")
    end

    def a_legacy_request_that_contains(facts, format = :pson)
      request = Puppet::Indirector::Request.new(:catalog, :find, "hostname", nil)
      request.options[:facts_format] = format.to_s
      request.options[:facts] = Puppet::Util.uri_query_encode(facts.render(format))
      request
    end

    def a_request_that_contains(facts)
      request = Puppet::Indirector::Request.new(:catalog, :find, "hostname", nil)
      request.options[:facts_format] = "application/json"
      request.options[:facts] = Puppet::Util.uri_query_encode(facts.render('json'))
      request
    end

    context "when extracting facts from the request" do
      it "should do nothing if no facts are provided" do
        request = Puppet::Indirector::Request.new(:catalog, :find, "hostname", nil)
        request.options[:facts] = nil

        expect(compiler.extract_facts_from_request(request)).to be_nil
      end

      it "should deserialize the facts without changing the timestamp" do
        time = Time.now
        @facts.timestamp = time
        request = a_request_that_contains(@facts)
        facts = compiler.extract_facts_from_request(request)
        expect(facts.timestamp).to eq(time)
      end

      it "accepts PSON facts from older agents" do
        request = a_legacy_request_that_contains(@facts)

        facts = compiler.extract_facts_from_request(request)
        expect(facts).to eq(@facts)
      end

      it "rejects YAML facts" do
        request = a_legacy_request_that_contains(@facts, :yaml)

        expect {
          compiler.extract_facts_from_request(request)
        }.to raise_error(ArgumentError, /Unsupported facts format/)
      end

      it "rejects unknown fact formats" do
        request = a_request_that_contains(@facts)
        request.options[:facts_format] = 'unknown-format'

        expect {
          compiler.extract_facts_from_request(request)
        }.to raise_error(ArgumentError, /Unsupported facts format/)
      end
    end

    context "when saving facts from the request" do
      it "should save facts if they were issued by the request" do
        request = a_request_that_contains(@facts)

        options = {
          :environment => request.environment,
          :transaction_uuid => request.options[:transaction_uuid],
        }

        Puppet::Node::Facts.indirection.expects(:save).with(equals(@facts), nil, options)
        compiler.find(request)
      end

      it "should skip saving facts if none were supplied" do
        request = Puppet::Indirector::Request.new(:catalog, :find, "hostname", nil)

        options = {
          :environment => request.environment,
          :transaction_uuid => request.options[:transaction_uuid],
        }

        Puppet::Node::Facts.indirection.expects(:save).with(equals(@facts), nil, options).never
        compiler.find(request)
      end
    end
  end

  describe "when finding nodes" do
    it "should look node information up via the Node class with the provided key" do
      Facter.stubs(:value).returns("whatever")
      request = Puppet::Indirector::Request.new(:catalog, :find, node_name, nil)
      compiler.stubs(:compile)

      Puppet::Node.indirection.expects(:find).with(node_name, anything).returns(node)

      compiler.find(request)
    end

    it "should pass the transaction_uuid to the node indirection" do
      uuid = '793ff10d-89f8-4527-a645-3302cbc749f3'
      compiler.stubs(:compile)
      request = Puppet::Indirector::Request.new(:catalog, :find, node_name,
                                                nil, :transaction_uuid => uuid)

      Puppet::Node.indirection.expects(:find).with(
        node_name,
        has_entries(:transaction_uuid => uuid)
      ).returns(node)

      compiler.find(request)
    end

    it "should pass the configured_environment to the node indirection" do
      environment = 'foo'
      compiler.stubs(:compile)
      request = Puppet::Indirector::Request.new(:catalog, :find, node_name,
                                                nil, :configured_environment => environment)

      Puppet::Node.indirection.expects(:find).with(
        node_name,
        has_entries(:configured_environment => environment)
      ).returns(node)

      compiler.find(request)
    end

    it "should pass a facts object from the original request facts to the node indirection" do
      facts = Puppet::Node::Facts.new("hostname", :afact => "avalue")
      compiler.expects(:extract_facts_from_request).returns(facts)
      compiler.expects(:save_facts_from_request)

      request = Puppet::Indirector::Request.new(:catalog, :find, "hostname",
                                                nil, :facts_format => "application/json",
                                                :facts => facts.render('json'))

      Puppet::Node.indirection.expects(:find).with("hostname", has_entries(:facts => facts)).returns(node)

      compiler.find(request)
    end
  end

  describe "after finding nodes" do
    before do
      Puppet.expects(:version).returns(1)
      Facter.expects(:value).with('fqdn').returns("my.server.com")
      Facter.expects(:value).with('ipaddress').returns("my.ip.address")
      @request = Puppet::Indirector::Request.new(:catalog, :find, node_name, nil)
      compiler.stubs(:compile)
      Puppet::Node.indirection.stubs(:find).with(node_name, anything).returns(node)
    end

    it "should add the server's Puppet version to the node's parameters as 'serverversion'" do
      node.expects(:merge).with { |args| args["serverversion"] == "1" }
      compiler.find(@request)
    end

    it "should add the server's fqdn to the node's parameters as 'servername'" do
      node.expects(:merge).with { |args| args["servername"] == "my.server.com" }
      compiler.find(@request)
    end

    it "should add the server's IP address to the node's parameters as 'serverip'" do
      node.expects(:merge).with { |args| args["serverip"] == "my.ip.address" }
      compiler.find(@request)
    end
  end

  describe "when filtering resources" do
    before :each do
      Facter.stubs(:value)
      @catalog = stub_everything 'catalog'
      @catalog.stubs(:respond_to?).with(:filter).returns(true)
    end

    it "should delegate to the catalog instance filtering" do
      @catalog.expects(:filter)
      compiler.filter(@catalog)
    end

    it "should filter out virtual resources" do
      resource = mock 'resource', :virtual? => true
      @catalog.stubs(:filter).yields(resource)

      compiler.filter(@catalog)
    end

    it "should return the same catalog if it doesn't support filtering" do
      @catalog.stubs(:respond_to?).with(:filter).returns(false)

      expect(compiler.filter(@catalog)).to eq(@catalog)
    end

    it "should return the filtered catalog" do
      catalog = stub 'filtered catalog'
      @catalog.stubs(:filter).returns(catalog)

      expect(compiler.filter(@catalog)).to eq(catalog)
    end

  end

  describe "when inlining metadata" do
    include PuppetSpec::Compiler

    let(:node) { Puppet::Node.new 'me' }
    let(:checksum_type) { 'md5' }
    let(:checksum_value) { 'b1946ac92492d2347c6235b4d2611184' }
    let(:path) { File.expand_path('/foo') }
    let(:source) { 'puppet:///modules/mymodule/config_file.txt' }

    def stubs_resource_metadata(ftype, relative_path, full_path = nil)
      full_path ||=  File.join(Puppet[:environmentpath], 'production', relative_path)

      metadata = stub 'metadata'
      metadata.stubs(:ftype).returns(ftype)
      metadata.stubs(:full_path).returns(full_path)
      metadata.stubs(:relative_path).returns(relative_path)
      metadata.stubs(:source).returns("puppet:///#{relative_path}")
      metadata.stubs(:source=)
      metadata.stubs(:content_uri=)

      metadata
    end

    def stubs_file_metadata(checksum_type, sha, relative_path, full_path = nil)
      metadata = stubs_resource_metadata('file', relative_path, full_path)
      metadata.stubs(:checksum).returns("{#{checksum_type}}#{sha}")
      metadata.stubs(:checksum_type).returns(checksum_type)
      metadata
    end

    def stubs_link_metadata(relative_path, destination)
      metadata = stubs_resource_metadata('link', relative_path)
      metadata.stubs(:destination).returns(destination)
      metadata
    end

    def stubs_directory_metadata(relative_path)
      metadata = stubs_resource_metadata('directory', relative_path)
      metadata.stubs(:relative_path).returns('.')
      metadata
    end

    it "inlines metadata for a file" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => file,
          source => '#{source}'
        }
      MANIFEST

      metadata = stubs_file_metadata(checksum_type, checksum_value, 'modules/mymodule/files/config_file.txt')
      metadata.expects(:source=).with(source)
      metadata.expects(:content_uri=).with('puppet:///modules/mymodule/files/config_file.txt')

      options = {
        :environment => catalog.environment_instance,
        :links => :manage,
        :checksum_type => checksum_type.to_sym,
        :source_permissions => :ignore
      }
      Puppet::FileServing::Metadata.indirection.expects(:find).with(source, options).returns(metadata)

      compiler.send(:inline_metadata, catalog, checksum_type)

      expect(catalog.metadata[path]).to eq(metadata)
      expect(catalog.recursive_metadata).to be_empty
    end

    it "uses resource parameters when inlining metadata" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => link,
          source => '#{source}',
          links  => follow,
          source_permissions => use,
        }
      MANIFEST

      metadata = stubs_link_metadata('modules/mymodule/files/config_file.txt', '/tmp/some/absolute/path')
      metadata.expects(:source=).with(source)
      metadata.expects(:content_uri=).with('puppet:///modules/mymodule/files/config_file.txt')

      options = {
        :environment        => catalog.environment_instance,
        :links              => :follow,
        :checksum_type      => checksum_type.to_sym,
        :source_permissions => :use
      }
      Puppet::FileServing::Metadata.indirection.expects(:find).with(source, options).returns(metadata)

      compiler.send(:inline_metadata, catalog, checksum_type)

      expect(catalog.metadata[path]).to eq(metadata)
      expect(catalog.recursive_metadata).to be_empty
    end

    it "uses file parameters which match the true file type defaults" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => file,
          source => '#{source}'
        }
      MANIFEST

      if Puppet::Util::Platform.windows?
        default_file = Puppet::Type.type(:file).new(:name => 'C:\defaults')
      else
        default_file = Puppet::Type.type(:file).new(:name => '/defaults')
      end

      metadata = stubs_file_metadata(checksum_type, checksum_value, 'modules/mymodule/files/config_file.txt')

      options = {
        :environment => catalog.environment_instance,
        :links => default_file[:links],
        :checksum_type => checksum_type.to_sym,
        :source_permissions => default_file[:source_permissions]
      }

      Puppet::FileServing::Metadata.indirection.expects(:find).with(source, options).returns(metadata)

      compiler.send(:inline_metadata, catalog, checksum_type)
    end

    it "inlines metadata for the first source found" do
      alt_source = 'puppet:///modules/files/other.txt'
      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => file,
          source => ['#{alt_source}', '#{source}'],
        }
      MANIFEST

      metadata = stubs_file_metadata(checksum_type, checksum_value, 'modules/mymodule/files/config_file.txt')
      metadata.expects(:source=).with(source)
      metadata.expects(:content_uri=).with('puppet:///modules/mymodule/files/config_file.txt')
      Puppet::FileServing::Metadata.indirection.expects(:find).with(source, anything).returns(metadata)
      Puppet::FileServing::Metadata.indirection.expects(:find).with(alt_source, anything).returns(nil)

      compiler.send(:inline_metadata, catalog, checksum_type)

      expect(catalog.metadata[path]).to eq(metadata)
      expect(catalog.recursive_metadata).to be_empty
    end

    [['md5', 'b1946ac92492d2347c6235b4d2611184'],
     ['sha256', '5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03']].each do |checksum_type, sha|
      describe "with agent requesting checksum_type #{checksum_type}" do
        it "sets checksum and checksum_value for resources with puppet:// source URIs" do
          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { '#{path}':
              ensure => file,
              source => '#{source}'
            }
          MANIFEST

          metadata = stubs_file_metadata(checksum_type, sha, 'modules/mymodule/files/config_file.txt')

          options = {
            :environment        => catalog.environment_instance,
            :links              => :manage,
            :checksum_type      => checksum_type.to_sym,
            :source_permissions => :ignore
          }
          Puppet::FileServing::Metadata.indirection.expects(:find).with(source, options).returns(metadata)

          compiler.send(:inline_metadata, catalog, checksum_type)

          expect(catalog.metadata[path]).to eq(metadata)
          expect(catalog.recursive_metadata).to be_empty
        end
      end
    end

    it "preserves source host and port in the content_uri" do
      source = 'puppet://myhost:8888/modules/mymodule/config_file.txt'

      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => file,
          source => '#{source}'
        }
      MANIFEST

      metadata = stubs_file_metadata(checksum_type, checksum_value, 'modules/mymodule/files/config_file.txt')
      metadata.stubs(:source).returns(source)

      metadata.expects(:content_uri=).with('puppet://myhost:8888/modules/mymodule/files/config_file.txt')

      Puppet::FileServing::Metadata.indirection.expects(:find).with(source, anything).returns(metadata)

      compiler.send(:inline_metadata, catalog, checksum_type)
    end

    it "skips absent resources" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => absent,
        }
      MANIFEST

      compiler.send(:inline_metadata, catalog, checksum_type)
      expect(catalog.metadata).to be_empty
      expect(catalog.recursive_metadata).to be_empty
    end

    it "skips resources without a source" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => file,
        }
      MANIFEST

      compiler.send(:inline_metadata, catalog, checksum_type)
      expect(catalog.metadata).to be_empty
      expect(catalog.recursive_metadata).to be_empty
    end

    it "skips resources with a local source" do
      local_source = File.expand_path('/tmp/source')

      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => file,
          source => '#{local_source}',
        }
      MANIFEST

      compiler.send(:inline_metadata, catalog, checksum_type)
      expect(catalog.metadata).to be_empty
      expect(catalog.recursive_metadata).to be_empty
    end

    it "skips resources with a http source" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => file,
          source => ['http://foo.source.io', 'https://foo.source.io']
        }
      MANIFEST

      compiler.send(:inline_metadata, catalog, checksum_type)
      expect(catalog.metadata).to be_empty
      expect(catalog.recursive_metadata).to be_empty
    end

    it "skips resources with a source outside the environment path" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => file,
          source => '#{source}'
        }
      MANIFEST

      full_path = File.join(Puppet[:codedir], "modules/mymodule/files/config_file.txt")
      metadata = stubs_file_metadata(checksum_type, checksum_value, 'modules/mymodule/files/config_file.txt', full_path)
      Puppet::FileServing::Metadata.indirection.expects(:find).with(source, anything).returns(metadata)

      compiler.send(:inline_metadata, catalog, checksum_type)
      expect(catalog.metadata).to be_empty
      expect(catalog.recursive_metadata).to be_empty
    end

    it "skips resources whose mount point is not 'modules'" do
      source = 'puppet:///secure/data'

      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => file,
          source => '#{source}',
        }
      MANIFEST

      metadata = stubs_file_metadata(checksum_type, checksum_value, 'secure/files/data.txt')
      Puppet::FileServing::Metadata.indirection.expects(:find).with(source, anything).returns(metadata)

      compiler.send(:inline_metadata, catalog, checksum_type)
      expect(catalog.metadata).to be_empty
      expect(catalog.recursive_metadata).to be_empty
    end

    it "skips resources with 'modules' mount point resolving to a path not in 'modules/*/files'" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => file,
          source => '#{source}',
        }
      MANIFEST

      metadata = stubs_file_metadata(checksum_type, checksum_value, 'modules/mymodule/not_in_files/config_file.txt')
      Puppet::FileServing::Metadata.indirection.expects(:find).with(source, anything).returns(metadata)

      compiler.send(:inline_metadata, catalog, checksum_type)
      expect(catalog.metadata).to be_empty
      expect(catalog.recursive_metadata).to be_empty
    end

    it "skips resources with 'modules' mount point resolving to a path with an empty module name" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => file,
          source => '#{source}',
        }
      MANIFEST

      # note empty module name "modules//files"
      metadata = stubs_file_metadata(checksum_type, checksum_value, 'modules//files/config_file.txt')
      Puppet::FileServing::Metadata.indirection.expects(:find).with(source, anything).returns(metadata)

      compiler.send(:inline_metadata, catalog, checksum_type)
      expect(catalog.metadata).to be_empty
      expect(catalog.recursive_metadata).to be_empty
    end

    it "inlines resources in 'modules' mount point resolving to a 'site' directory within the per-environment codedir" do
      # example taken from https://github.com/puppetlabs/control-repo/blob/508b9cc/site/profile/manifests/puppetmaster.pp#L45-L49
      source = 'puppet:///modules/profile/puppetmaster/update-classes.sh'

      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => file,
          source => '#{source}'
        }
      MANIFEST

      # See https://github.com/puppetlabs/control-repo/blob/508b9cc/site/profile/files/puppetmaster/update-classes.sh
      metadata = stubs_file_metadata(checksum_type, checksum_value, 'site/profile/files/puppetmaster/update-classes.sh')
      metadata.stubs(:source).returns(source)

      Puppet::FileServing::Metadata.indirection.expects(:find).with(source, anything).returns(metadata)

      compiler.send(:inline_metadata, catalog, checksum_type)
      expect(catalog.metadata[path]).to eq(metadata)
      expect(catalog.recursive_metadata).to be_empty
    end

    # It's bizarre to strip trailing slashes for a file, but it's how
    # puppet currently behaves, so match that.
    it "inlines resources with a trailing slash" do
      source = 'puppet:///modules/mymodule/myfile'

      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { '#{path}':
          ensure => file,
          source => '#{source}/'
        }
      MANIFEST

      metadata = stubs_file_metadata(checksum_type, checksum_value, 'modules/mymodule/files/myfile')
      metadata.stubs(:source).returns(source)

      Puppet::FileServing::Metadata.indirection.expects(:find).with(source, anything).returns(metadata)

      compiler.send(:inline_metadata, catalog, checksum_type)
      expect(catalog.metadata[path]).to eq(metadata)
      expect(catalog.recursive_metadata).to be_empty
    end

    describe "when inlining directories" do
      let(:source_dir) { 'puppet:///modules/mymodule/directory' }
      let(:metadata) { stubs_directory_metadata('modules/mymodule/files/directory') }

      describe "when recurse is false" do
        it "skips children" do
          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { '#{path}':
              ensure  => directory,
              source  => '#{source_dir}'
            }
          MANIFEST

          metadata.expects(:content_uri=).with('puppet:///modules/mymodule/files/directory')
          Puppet::FileServing::Metadata.indirection.expects(:find).with(source_dir, anything).returns(metadata)

          compiler.send(:inline_metadata, catalog, checksum_type)

          expect(catalog.metadata[path]).to eq(metadata)
          expect(catalog.recursive_metadata).to be_empty
        end
      end

      describe "when recurse is true" do
        let(:child_metadata) { stubs_file_metadata(checksum_type, checksum_value, 'myfile.txt') }

        it "inlines child metadata" do
          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { '#{path}':
              ensure  => directory,
              recurse => true,
              source  => '#{source_dir}'
            }
          MANIFEST

          metadata.expects(:content_uri=).with('puppet:///modules/mymodule/files/directory')
          child_metadata.expects(:content_uri=).with('puppet:///modules/mymodule/files/directory/myfile.txt')

          options = {
            :environment        => catalog.environment_instance,
            :links              => :manage,
            :checksum_type      => checksum_type.to_sym,
            :source_permissions => :ignore,
            :recurse            => true,
            :recurselimit       => nil,
            :ignore             => nil,
          }
          Puppet::FileServing::Metadata.indirection.expects(:search).with(source_dir, options).returns([metadata, child_metadata])

          compiler.send(:inline_metadata, catalog, checksum_type)

          expect(catalog.metadata[path]).to be_nil
          expect(catalog.recursive_metadata[path][source_dir]).to eq([metadata, child_metadata])
        end

        it "uses resource parameters when inlining metadata" do
          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { '#{path}':
              ensure  => directory,
              recurse => true,
              source  => '#{source_dir}',
              checksum => sha256,
              source_permissions => use_when_creating,
              recurselimit => 2,
              ignore => 'foo.+',
              links => follow,
            }
          MANIFEST

          options = {
            :environment        => catalog.environment_instance,
            :links              => :follow,
            :checksum_type      => :sha256,
            :source_permissions => :use_when_creating,
            :recurse            => true,
            :recurselimit       => 2,
            :ignore             => 'foo.+',
          }
          Puppet::FileServing::Metadata.indirection.expects(:search).with(source_dir, options).returns([metadata, child_metadata])

          compiler.send(:inline_metadata, catalog, checksum_type)

          expect(catalog.metadata[path]).to be_nil
          expect(catalog.recursive_metadata[path][source_dir]).to eq([metadata, child_metadata])
        end

        it "inlines metadata for all sources if source_select is all" do
          alt_source_dir = 'puppet:///modules/mymodule/other_directory'
          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { '#{path}':
              ensure  => directory,
              recurse => true,
              source  => ['#{source_dir}', '#{alt_source_dir}'],
              sourceselect => all,
            }
          MANIFEST

          Puppet::FileServing::Metadata.indirection.expects(:search).with(source_dir, anything).returns([metadata, child_metadata])
          Puppet::FileServing::Metadata.indirection.expects(:search).with(alt_source_dir, anything).returns([metadata, child_metadata])

          compiler.send(:inline_metadata, catalog, checksum_type)

          expect(catalog.metadata[path]).to be_nil
          expect(catalog.recursive_metadata[path][source_dir]).to eq([metadata, child_metadata])
          expect(catalog.recursive_metadata[path][alt_source_dir]).to eq([metadata, child_metadata])
        end

        it "inlines metadata for the first valid source if source_select is first" do
          alt_source_dir = 'puppet:///modules/mymodule/other_directory'
          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { '#{path}':
              ensure  => directory,
              recurse => true,
              source  => ['#{source_dir}', '#{alt_source_dir}'],
            }
          MANIFEST

          Puppet::FileServing::Metadata.indirection.expects(:search).with(source_dir, anything).returns(nil)
          Puppet::FileServing::Metadata.indirection.expects(:search).with(alt_source_dir, anything).returns([metadata, child_metadata])

          compiler.send(:inline_metadata, catalog, checksum_type)

          expect(catalog.metadata[path]).to be_nil
          expect(catalog.recursive_metadata[path][source_dir]).to be_nil
          expect(catalog.recursive_metadata[path][alt_source_dir]).to eq([metadata, child_metadata])
        end

        it "skips resources whose mount point is not 'modules'" do
          source = 'puppet:///secure/data'

          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { '#{path}':
              ensure  => directory,
              recurse => true,
              source  => '#{source}',
            }
          MANIFEST

          metadata = stubs_directory_metadata('secure/files/data')
          metadata.stubs(:source).returns(source)

          Puppet::FileServing::Metadata.indirection.expects(:search).with(source, anything).returns([metadata])

          compiler.send(:inline_metadata, catalog, checksum_type)
          expect(catalog.metadata).to be_empty
          expect(catalog.recursive_metadata).to be_empty
        end

        it "skips resources with 'modules' mount point resolving to a path not in 'modules/*/files'" do
          source = 'puppet:///modules/mymodule/directory'

          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { '#{path}':
              ensure  => directory,
              recurse => true,
              source  => '#{source}',
            }
          MANIFEST

          metadata = stubs_directory_metadata('modules/mymodule/not_in_files/directory')
          Puppet::FileServing::Metadata.indirection.expects(:search).with(source, anything).returns([metadata])

          compiler.send(:inline_metadata, catalog, checksum_type)
          expect(catalog.metadata).to be_empty
          expect(catalog.recursive_metadata).to be_empty
        end

        it "inlines resources in 'modules' mount point resolving to a 'site' directory within the per-environment codedir" do
          # example adopted from https://github.com/puppetlabs/control-repo/blob/508b9cc/site/profile/manifests/puppetmaster.pp#L45-L49
          source = 'puppet:///modules/profile/puppetmaster'

          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { '#{path}':
              ensure  => file,
              recurse => true,
              source  => '#{source}'
            }
          MANIFEST

          # See https://github.com/puppetlabs/control-repo/blob/508b9cc/site/profile/files/puppetmaster/update-classes.sh
          dir_metadata = stubs_directory_metadata('site/profile/files/puppetmaster')
          dir_metadata.stubs(:source).returns(source)

          child_metadata = stubs_file_metadata(checksum_type, checksum_value, './update-classes.sh')
          child_metadata.stubs(:source).returns("#{source}/update-classes.sh")

          Puppet::FileServing::Metadata.indirection.expects(:search).with(source, anything).returns([dir_metadata, child_metadata])

          compiler.send(:inline_metadata, catalog, checksum_type)
          expect(catalog.metadata).to be_empty
          expect(catalog.recursive_metadata[path][source]).to eq([dir_metadata, child_metadata])
        end

        it "inlines resources with a trailing slash" do
          source = 'puppet:///modules/mymodule/directory'

          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { '#{path}':
              ensure  => directory,
              recurse => true,
              source  => '#{source}/'
            }
          MANIFEST

          dir_metadata = stubs_directory_metadata('modules/mymodule/files/directory')
          dir_metadata.stubs(:source).returns(source)

          child_metadata = stubs_file_metadata(checksum_type, checksum_value, './file')
          child_metadata.stubs(:source).returns("#{source}/file")

          Puppet::FileServing::Metadata.indirection.expects(:search).with(source, anything).returns([dir_metadata, child_metadata])

          compiler.send(:inline_metadata, catalog, checksum_type)

          expect(catalog.metadata).to be_empty
          expect(catalog.recursive_metadata[path][source]).to eq([dir_metadata, child_metadata])
        end
      end
    end

    it "skips non-file resources" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
        notify { 'hi': }
      MANIFEST

      compiler.send(:inline_metadata, catalog, checksum_type)
      expect(catalog.metadata).to be_empty
      expect(catalog.recursive_metadata).to be_empty
    end

    it "inlines windows file paths", :if => Puppet.features.posix? do
      catalog = compile_to_catalog(<<-MANIFEST, node)
        file { 'c:/foo':
          ensure => file,
          source => '#{source}'
        }
      MANIFEST

      metadata = stubs_file_metadata(checksum_type, checksum_value, 'modules/mymodule/files/config_file.txt')
      Puppet::FileServing::Metadata.indirection.expects(:find).with(source, anything).returns(metadata)

      compiler.send(:inline_metadata, catalog, checksum_type)
      expect(catalog.metadata['c:/foo']).to eq(metadata)
      expect(catalog.recursive_metadata).to be_empty
    end
  end
end
