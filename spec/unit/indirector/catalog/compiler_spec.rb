require 'spec_helper'
require 'puppet_spec/compiler'
require 'matchers/resource'

require 'puppet/indirector/catalog/compiler'

def set_facts(fact_hash)
  fact_hash.each do |key, value|
    allow(Facter).to receive(:value).with(key).and_return(value)
  end
end

describe Puppet::Resource::Catalog::Compiler do
  let(:compiler) { described_class.new }
  let(:node_name) { "foo" }
  let(:node) { Puppet::Node.new(node_name)}

  describe "when initializing" do
    before do
      allow(Puppet).to receive(:version).and_return(1)
    end

    it "should cache the server metadata and reuse it" do
      Puppet[:node_terminus] = :memory
      Puppet::Node.indirection.save(Puppet::Node.new("node1"))
      Puppet::Node.indirection.save(Puppet::Node.new("node2"))

      allow(compiler).to receive(:compile)

      compiler.find(Puppet::Indirector::Request.new(:catalog, :find, 'node1', nil, :node => 'node1'))
      compiler.find(Puppet::Indirector::Request.new(:catalog, :find, 'node2', nil, :node => 'node2'))
    end
  end

  describe "when finding catalogs" do
    before do
      allow(node).to receive(:merge)
      allow(Puppet::Node.indirection).to receive(:find).and_return(node)
      @request = Puppet::Indirector::Request.new(:catalog, :find, node_name, nil, :node => node_name)
    end

    it "should directly use provided nodes for a local request" do
      expect(Puppet::Node.indirection).not_to receive(:find)
      expect(compiler).to receive(:compile).with(node, anything)
      allow(@request).to receive(:options).and_return(:use_node => node)
      allow(@request).to receive(:remote?).and_return(false)
      compiler.find(@request)
    end

    it "rejects a provided node if the request is remote" do
      allow(@request).to receive(:options).and_return(:use_node => node)
      allow(@request).to receive(:remote?).and_return(true)
      expect {
        compiler.find(@request)
      }.to raise_error Puppet::Error, /invalid option use_node/i
    end

    it "should use the authenticated node name if no request key is provided" do
      allow(@request).to receive(:key).and_return(nil)
      expect(Puppet::Node.indirection).to receive(:find).with(node_name, anything).and_return(node)
      expect(compiler).to receive(:compile).with(node, anything)
      compiler.find(@request)
    end

    it "should use the provided node name by default" do
      expect(@request).to receive(:key).and_return("my_node")

      expect(Puppet::Node.indirection).to receive(:find).with("my_node", anything).and_return(node)
      expect(compiler).to receive(:compile).with(node, anything)
      compiler.find(@request)
    end

    it "should fail if no node is passed and none can be found" do
      allow(Puppet::Node.indirection).to receive(:find).with(node_name, anything).and_return(nil)
      expect { compiler.find(@request) }.to raise_error(ArgumentError)
    end

    it "should fail intelligently when searching for a node raises an exception" do
      allow(Puppet::Node.indirection).to receive(:find).with(node_name, anything).and_raise("eh")
      expect { compiler.find(@request) }.to raise_error(Puppet::Error)
    end

    it "should pass the found node to the compiler for compiling" do
      expect(Puppet::Node.indirection).to receive(:find).with(node_name, anything).and_return(node)
      expect(Puppet::Parser::Compiler).to receive(:compile).with(node, anything)
      compiler.find(@request)
    end

    it "should pass node containing percent character to the compiler" do
      node_with_percent_character = Puppet::Node.new "%6de"
      allow(Puppet::Node.indirection).to receive(:find).and_return(node_with_percent_character)
      expect(Puppet::Parser::Compiler).to receive(:compile).with(node_with_percent_character, anything)
      compiler.find(@request)
    end

    it "should extract any facts from the request" do
      expect(Puppet::Node.indirection).to receive(:find).with(node_name, anything).and_return(node)
      expect(compiler).to receive(:extract_facts_from_request).with(@request)
      allow(Puppet::Parser::Compiler).to receive(:compile)
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
      allow(Puppet::Node.indirection).to receive(:find).and_return(node)
      catalog = Puppet::Resource::Catalog.new(node.name)
      allow(Puppet::Parser::Compiler).to receive(:compile).and_return(catalog)

      expect(compiler.find(@request)).to equal(catalog)
    end

    it "passes the code_id from the request to the compiler" do
      allow(Puppet::Node.indirection).to receive(:find).and_return(node)
      code_id = 'b59e5df0578ef411f773ee6c33d8073c50e7b8fe'
      @request.options[:code_id] = code_id

      expect(Puppet::Parser::Compiler).to receive(:compile).with(anything, code_id)

      compiler.find(@request)
    end

    it "returns a catalog with the code_id from the request" do
      allow(Puppet::Node.indirection).to receive(:find).and_return(node)
      code_id = 'b59e5df0578ef411f773ee6c33d8073c50e7b8fe'
      @request.options[:code_id] = code_id

      catalog = Puppet::Resource::Catalog.new(node.name, node.environment, code_id)
      allow(Puppet::Parser::Compiler).to receive(:compile).and_return(catalog)

      expect(compiler.find(@request).code_id).to eq(code_id)
    end

    it "does not inline metadata when the static_catalog option is false" do
      allow(Puppet::Node.indirection).to receive(:find).and_return(node)
      @request.options[:static_catalog] = false
      @request.options[:code_id] = 'some_code_id'
      allow(node.environment).to receive(:static_catalogs?).and_return(true)

      catalog = Puppet::Resource::Catalog.new(node.name, node.environment)
      allow(Puppet::Parser::Compiler).to receive(:compile).and_return(catalog)

      expect(compiler).not_to receive(:inline_metadata)
      compiler.find(@request)
    end

    it "does not inline metadata when static_catalogs are disabled" do
      allow(Puppet::Node.indirection).to receive(:find).and_return(node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'md5'
      @request.options[:code_id] = 'some_code_id'
      allow(node.environment).to receive(:static_catalogs?).and_return(false)

      catalog = Puppet::Resource::Catalog.new(node.name, node.environment)
      allow(Puppet::Parser::Compiler).to receive(:compile).and_return(catalog)

      expect(compiler).not_to receive(:inline_metadata)
      compiler.find(@request)
    end

    it "does not inline metadata when code_id is not specified" do
      allow(Puppet::Node.indirection).to receive(:find).and_return(node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'md5'
      allow(node.environment).to receive(:static_catalogs?).and_return(true)

      catalog = Puppet::Resource::Catalog.new(node.name, node.environment)
      allow(Puppet::Parser::Compiler).to receive(:compile).and_return(catalog)

      expect(compiler).not_to receive(:inline_metadata)
      expect(compiler.find(@request)).to eq(catalog)
    end

    it "inlines metadata when the static_catalog option is true, static_catalogs are enabled, and a code_id is provided" do
      allow(Puppet::Node.indirection).to receive(:find).and_return(node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'sha256'
      @request.options[:code_id] = 'some_code_id'
      allow(node.environment).to receive(:static_catalogs?).and_return(true)

      catalog = Puppet::Resource::Catalog.new(node.name, node.environment)
      allow(Puppet::Parser::Compiler).to receive(:compile).and_return(catalog)

      expect(compiler).to receive(:inline_metadata).with(catalog, :sha256).and_return(catalog)
      compiler.find(@request)
    end

    it "inlines metadata with the first common checksum type" do
      allow(Puppet::Node.indirection).to receive(:find).and_return(node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'atime.md5.sha256.mtime'
      @request.options[:code_id] = 'some_code_id'
      allow(node.environment).to receive(:static_catalogs?).and_return(true)

      catalog = Puppet::Resource::Catalog.new(node.name, node.environment)
      allow(Puppet::Parser::Compiler).to receive(:compile).and_return(catalog)

      expect(compiler).to receive(:inline_metadata).with(catalog, :md5).and_return(catalog)
      compiler.find(@request)
    end

    it "errors if checksum_type contains no shared checksum types" do
      allow(Puppet::Node.indirection).to receive(:find).and_return(node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = 'atime.md2'
      @request.options[:code_id] = 'some_code_id'
      allow(node.environment).to receive(:static_catalogs?).and_return(true)

      expect { compiler.find(@request) }.to raise_error Puppet::Error,
        "Unable to find a common checksum type between agent 'atime.md2' and master '[:sha256, :sha256lite, :md5, :md5lite, :sha1, :sha1lite, :sha512, :sha384, :sha224, :mtime, :ctime, :none]'."
    end

    it "errors if checksum_type contains no shared checksum types" do
      allow(Puppet::Node.indirection).to receive(:find).and_return(node)
      @request.options[:static_catalog] = true
      @request.options[:checksum_type] = nil
      @request.options[:code_id] = 'some_code_id'
      allow(node.environment).to receive(:static_catalogs?).and_return(true)

      expect { compiler.find(@request) }.to raise_error Puppet::Error,
        "Unable to find a common checksum type between agent '' and master '[:sha256, :sha256lite, :md5, :md5lite, :sha1, :sha1lite, :sha512, :sha384, :sha224, :mtime, :ctime, :none]'."
    end
  end

  describe "when handling a request with facts" do
    before do
      allow(Facter).to receive(:value).and_return("something")

      facts = Puppet::Node::Facts.new('hostname', "fact" => "value", "architecture" => "i386")
      Puppet::Node::Facts.indirection.save(facts)
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
      let(:facts) { Puppet::Node::Facts.new("hostname") }

      it "should do nothing if no facts are provided" do
        request = Puppet::Indirector::Request.new(:catalog, :find, "hostname", nil)
        request.options[:facts] = nil

        expect(compiler.extract_facts_from_request(request)).to be_nil
      end

      it "should deserialize the facts without changing the timestamp" do
        time = Time.now
        facts.timestamp = time
        request = a_request_that_contains(facts)
        facts = compiler.extract_facts_from_request(request)
        expect(facts.timestamp).to eq(time)
      end

      it "accepts PSON facts from older agents" do
        request = a_legacy_request_that_contains(facts)

        facts = compiler.extract_facts_from_request(request)
        expect(facts).to eq(facts)
      end

      it "rejects YAML facts" do
        request = a_legacy_request_that_contains(facts, :yaml)

        expect {
          compiler.extract_facts_from_request(request)
        }.to raise_error(ArgumentError, /Unsupported facts format/)
      end

      it "rejects unknown fact formats" do
        request = a_request_that_contains(facts)
        request.options[:facts_format] = 'unknown-format'

        expect {
          compiler.extract_facts_from_request(request)
        }.to raise_error(ArgumentError, /Unsupported facts format/)
      end
    end

    context "when saving facts from the request" do
      let(:facts) { Puppet::Node::Facts.new("hostname") }

      it "should save facts if they were issued by the request" do
        request = a_request_that_contains(facts)

        options = {
          :environment => request.environment,
          :transaction_uuid => request.options[:transaction_uuid],
        }

        expect(Puppet::Node::Facts.indirection).to receive(:save).with(facts, nil, options)
        compiler.find(request)
      end

      it "should skip saving facts if none were supplied" do
        request = Puppet::Indirector::Request.new(:catalog, :find, "hostname", nil)

        options = {
          :environment => request.environment,
          :transaction_uuid => request.options[:transaction_uuid],
        }

        expect(Puppet::Node::Facts.indirection).not_to receive(:save).with(facts, nil, options)
        compiler.find(request)
      end
    end
  end

  describe "when finding nodes" do
    it "should look node information up via the Node class with the provided key" do
      request = Puppet::Indirector::Request.new(:catalog, :find, node_name, nil)
      allow(compiler).to receive(:compile)

      expect(Puppet::Node.indirection).to receive(:find).with(node_name, anything).and_return(node)

      compiler.find(request)
    end

    it "should pass the transaction_uuid to the node indirection" do
      uuid = '793ff10d-89f8-4527-a645-3302cbc749f3'
      allow(compiler).to receive(:compile)
      request = Puppet::Indirector::Request.new(:catalog, :find, node_name,
                                                nil, :transaction_uuid => uuid)

      expect(Puppet::Node.indirection).to receive(:find).with(
        node_name,
        hash_including(:transaction_uuid => uuid)
      ).and_return(node)

      compiler.find(request)
    end

    it "should pass the configured_environment to the node indirection" do
      environment = 'foo'
      allow(compiler).to receive(:compile)
      request = Puppet::Indirector::Request.new(:catalog, :find, node_name,
                                                nil, :configured_environment => environment)

      expect(Puppet::Node.indirection).to receive(:find).with(
        node_name,
        hash_including(:configured_environment => environment)
      ).and_return(node)

      compiler.find(request)
    end

    it "should pass a facts object from the original request facts to the node indirection" do
      facts = Puppet::Node::Facts.new("hostname", :afact => "avalue")
      expect(compiler).to receive(:extract_facts_from_request).and_return(facts)
      expect(compiler).to receive(:save_facts_from_request)

      request = Puppet::Indirector::Request.new(:catalog, :find, "hostname",
                                                nil, :facts_format => "application/json",
                                                :facts => facts.render('json'))

      expect(Puppet::Node.indirection).to receive(:find).with("hostname", hash_including(:facts => facts)).and_return(node)

      compiler.find(request)
    end
  end

  describe "after finding nodes" do
    before do
      allow(Puppet).to receive(:version).and_return(1)
      set_facts({
        'fqdn'       => "my.server.com",
        'ipaddress'  => "my.ip.address",
        'ipaddress6' => nil
        })
      @request = Puppet::Indirector::Request.new(:catalog, :find, node_name, nil)
      allow(compiler).to receive(:compile)
      allow(Puppet::Node.indirection).to receive(:find).with(node_name, anything).and_return(node)
    end

    it "should add the server's Puppet version to the node's parameters as 'serverversion'" do
      expect(node).to receive(:merge).with(hash_including("serverversion" => "1"))
      compiler.find(@request)
    end

    it "should add the server's fqdn to the node's parameters as 'servername'" do
      expect(node).to receive(:merge).with(hash_including("servername" => "my.server.com"))
      compiler.find(@request)
    end

    it "should add the server's IP address to the node's parameters as 'serverip'" do
      expect(node).to receive(:merge).with(hash_including("serverip" => "my.ip.address"))
      compiler.find(@request)
    end

    it "shouldn't warn if there is at least one ip fact" do
      expect(node).to receive(:merge).with(hash_including("serverip" => "my.ip.address"))
      compiler.find(@request)
      expect(@logs).not_to be_any {|log| log.level == :warning and log.message =~ /Could not retrieve either serverip or serverip6 fact/}
    end
  end

  describe "in an IPv6 only environment" do
    before do |example|
      allow(Puppet).to receive(:version).and_return(1)
      set_facts({
        'fqdn'       => "my.server.com",
        'ipaddress'  => nil,
      })
      if example.metadata[:nil_ipv6]
        set_facts({
          'ipaddress6' => nil
        })
      else
        set_facts({
          'ipaddress6' => "my.ipv6.address"
        })
      end
      @request = Puppet::Indirector::Request.new(:catalog, :find, node_name, nil)
      allow(compiler).to receive(:compile)
      allow(Puppet::Node.indirection).to receive(:find).with(node_name, anything).and_return(node)
    end

    it "should populate the :serverip6 fact" do
      expect(node).to receive(:merge).with(hash_including("serverip6" => "my.ipv6.address"))
      compiler.find(@request)
    end

    it "shouldn't warn if there is at least one ip fact" do
      expect(node).to receive(:merge).with(hash_including("serverip6" => "my.ipv6.address"))
      compiler.find(@request)
      expect(@logs).not_to be_any {|log| log.level == :warning and log.message =~ /Could not retrieve either serverip or serverip6 fact/}
    end

    it "should warn if there are no ip facts", :nil_ipv6 do
      expect(node).to receive(:merge)
      compiler.find(@request)
      expect(@logs).to be_any {|log| log.level == :warning and log.message =~ /Could not retrieve either serverip or serverip6 fact/}
    end
  end

  describe "when filtering resources" do
    before :each do
      @catalog = double('catalog')
      allow(@catalog).to receive(:respond_to?).with(:filter).and_return(true)
    end

    it "should delegate to the catalog instance filtering" do
      expect(@catalog).to receive(:filter)
      compiler.filter(@catalog)
    end

    it "should filter out virtual resources" do
      resource = double('resource', :virtual? => true)
      allow(@catalog).to receive(:filter).and_yield(resource)

      compiler.filter(@catalog)
    end

    it "should return the same catalog if it doesn't support filtering" do
      allow(@catalog).to receive(:respond_to?).with(:filter).and_return(false)

      expect(compiler.filter(@catalog)).to eq(@catalog)
    end

    it "should return the filtered catalog" do
      catalog = double('filtered catalog')
      allow(@catalog).to receive(:filter).and_return(catalog)

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

      metadata = double('metadata')
      allow(metadata).to receive(:ftype).and_return(ftype)
      allow(metadata).to receive(:full_path).and_return(full_path)
      allow(metadata).to receive(:relative_path).and_return(relative_path)
      allow(metadata).to receive(:source).and_return("puppet:///#{relative_path}")
      allow(metadata).to receive(:source=)
      allow(metadata).to receive(:content_uri=)

      metadata
    end

    def stubs_file_metadata(checksum_type, sha, relative_path, full_path = nil)
      metadata = stubs_resource_metadata('file', relative_path, full_path)
      allow(metadata).to receive(:checksum).and_return("{#{checksum_type}}#{sha}")
      allow(metadata).to receive(:checksum_type).and_return(checksum_type)
      metadata
    end

    def stubs_link_metadata(relative_path, destination)
      metadata = stubs_resource_metadata('link', relative_path)
      allow(metadata).to receive(:destination).and_return(destination)
      metadata
    end

    def stubs_directory_metadata(relative_path)
      metadata = stubs_resource_metadata('directory', relative_path)
      allow(metadata).to receive(:relative_path).and_return('.')
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
      expect(metadata).to receive(:source=).with(source)
      expect(metadata).to receive(:content_uri=).with('puppet:///modules/mymodule/files/config_file.txt')

      options = {
        :environment => catalog.environment_instance,
        :links => :manage,
        :checksum_type => checksum_type.to_sym,
        :source_permissions => :ignore
      }
      expect(Puppet::FileServing::Metadata.indirection).to receive(:find).with(source, options).and_return(metadata)

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
      expect(metadata).to receive(:source=).with(source)
      expect(metadata).to receive(:content_uri=).with('puppet:///modules/mymodule/files/config_file.txt')

      options = {
        :environment        => catalog.environment_instance,
        :links              => :follow,
        :checksum_type      => checksum_type.to_sym,
        :source_permissions => :use
      }
      expect(Puppet::FileServing::Metadata.indirection).to receive(:find).with(source, options).and_return(metadata)

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

      expect(Puppet::FileServing::Metadata.indirection).to receive(:find).with(source, options).and_return(metadata)

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
      expect(metadata).to receive(:source=).with(source)
      expect(metadata).to receive(:content_uri=).with('puppet:///modules/mymodule/files/config_file.txt')
      expect(Puppet::FileServing::Metadata.indirection).to receive(:find).with(source, anything).and_return(metadata)
      expect(Puppet::FileServing::Metadata.indirection).to receive(:find).with(alt_source, anything).and_return(nil)

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
          expect(Puppet::FileServing::Metadata.indirection).to receive(:find).with(source, options).and_return(metadata)

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
      allow(metadata).to receive(:source).and_return(source)

      expect(metadata).to receive(:content_uri=).with('puppet://myhost:8888/modules/mymodule/files/config_file.txt')

      expect(Puppet::FileServing::Metadata.indirection).to receive(:find).with(source, anything).and_return(metadata)

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
      expect(Puppet::FileServing::Metadata.indirection).to receive(:find).with(source, anything).and_return(metadata)

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
      expect(Puppet::FileServing::Metadata.indirection).to receive(:find).with(source, anything).and_return(metadata)

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
      expect(Puppet::FileServing::Metadata.indirection).to receive(:find).with(source, anything).and_return(metadata)

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
      expect(Puppet::FileServing::Metadata.indirection).to receive(:find).with(source, anything).and_return(metadata)

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
      allow(metadata).to receive(:source).and_return(source)

      expect(Puppet::FileServing::Metadata.indirection).to receive(:find).with(source, anything).and_return(metadata)

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
      allow(metadata).to receive(:source).and_return(source)

      expect(Puppet::FileServing::Metadata.indirection).to receive(:find).with(source, anything).and_return(metadata)

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

          expect(metadata).to receive(:content_uri=).with('puppet:///modules/mymodule/files/directory')
          expect(Puppet::FileServing::Metadata.indirection).to receive(:find).with(source_dir, anything).and_return(metadata)

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

          expect(metadata).to receive(:content_uri=).with('puppet:///modules/mymodule/files/directory')
          expect(child_metadata).to receive(:content_uri=).with('puppet:///modules/mymodule/files/directory/myfile.txt')

          options = {
            :environment        => catalog.environment_instance,
            :links              => :manage,
            :checksum_type      => checksum_type.to_sym,
            :source_permissions => :ignore,
            :recurse            => true,
            :recurselimit       => nil,
            :ignore             => nil,
          }
          expect(Puppet::FileServing::Metadata.indirection).to receive(:search).with(source_dir, options).and_return([metadata, child_metadata])

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
          expect(Puppet::FileServing::Metadata.indirection).to receive(:search).with(source_dir, options).and_return([metadata, child_metadata])

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

          expect(Puppet::FileServing::Metadata.indirection).to receive(:search).with(source_dir, anything).and_return([metadata, child_metadata])
          expect(Puppet::FileServing::Metadata.indirection).to receive(:search).with(alt_source_dir, anything).and_return([metadata, child_metadata])

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

          expect(Puppet::FileServing::Metadata.indirection).to receive(:search).with(source_dir, anything).and_return(nil)
          expect(Puppet::FileServing::Metadata.indirection).to receive(:search).with(alt_source_dir, anything).and_return([metadata, child_metadata])

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
          allow(metadata).to receive(:source).and_return(source)

          expect(Puppet::FileServing::Metadata.indirection).to receive(:search).with(source, anything).and_return([metadata])

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
          expect(Puppet::FileServing::Metadata.indirection).to receive(:search).with(source, anything).and_return([metadata])

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
          allow(dir_metadata).to receive(:source).and_return(source)

          child_metadata = stubs_file_metadata(checksum_type, checksum_value, './update-classes.sh')
          allow(child_metadata).to receive(:source).and_return("#{source}/update-classes.sh")

          expect(Puppet::FileServing::Metadata.indirection).to receive(:search).with(source, anything).and_return([dir_metadata, child_metadata])

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
          allow(dir_metadata).to receive(:source).and_return(source)

          child_metadata = stubs_file_metadata(checksum_type, checksum_value, './file')
          allow(child_metadata).to receive(:source).and_return("#{source}/file")

          expect(Puppet::FileServing::Metadata.indirection).to receive(:search).with(source, anything).and_return([dir_metadata, child_metadata])

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
      expect(Puppet::FileServing::Metadata.indirection).to receive(:find).with(source, anything).and_return(metadata)

      compiler.send(:inline_metadata, catalog, checksum_type)
      expect(catalog.metadata['c:/foo']).to eq(metadata)
      expect(catalog.recursive_metadata).to be_empty
    end
  end
end
