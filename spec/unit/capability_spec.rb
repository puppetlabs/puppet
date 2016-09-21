#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'

describe 'Capability types' do
  include PuppetSpec::Compiler
  let(:env) { Puppet::Node::Environment.create(:testing, []) }
  let(:node) { Puppet::Node.new('test', :environment => env) }
  let(:loaders) { Puppet::Pops::Loaders.new(env) }

  around :each do |example|
    Puppet[:app_management] = true
    Puppet::Parser::Compiler.any_instance.stubs(:loaders).returns(loaders)
    Puppet.override(:loaders => loaders, :current_environment => env) do
      Puppet::Type.newtype :cap, :is_capability => true do
        newparam :name
        newparam :host
      end
      example.run
      Puppet::Type.rmtype(:cap)
    end
    Puppet[:app_management] = false
  end

  context 'annotations' do
    it "adds a blueprint for a produced resource" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
      define test($hostname) {
        notify { "hostname ${hostname}":}
      }

      Test produces Cap {
        host => $hostname
      }
    MANIFEST

      krt = catalog.environment_instance.known_resource_types
      type = krt.definition(:test)
      expect(type.produces).to be_instance_of(Array)
      prd = type.produces.first

      expect(prd).to be_instance_of(Hash)
      expect(prd[:capability]).to eq("Cap")
      expect(prd[:mappings]).to be_instance_of(Hash)
      expect(prd[:mappings]["host"]).to be_instance_of(Puppet::Parser::AST::PopsBridge::Expression)
    end

    it "adds a blueprint for a consumed resource" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
      define test($hostname) {
        notify { "hostname ${hostname}":}
      }

      Test consumes Cap {
        host => $hostname
      }
    MANIFEST

      krt = catalog.environment_instance.known_resource_types
      type = krt.definition(:test)
      expect(type.produces).to be_instance_of(Array)
      cns = type.consumes.first

      expect(cns).to be_instance_of(Hash)
      expect(cns[:capability]).to eq("Cap")
      expect(cns[:mappings]).to be_instance_of(Hash)
      expect(cns[:mappings]["host"]).to be_instance_of(Puppet::Parser::AST::PopsBridge::Expression)
    end

    it 'can place define and consumes/produces in separate manifests' do
      parse_results = []
      parser = Puppet::Parser::ParserFactory.parser

      parser.string = <<-MANIFEST
        define test($hostname) {
          notify { "hostname ${hostname}":}
        }
      MANIFEST
      parse_results << parser.parse

      parser.string = <<-MANIFEST
        Test consumes Cap {
          host => $hostname
        }
      MANIFEST
      parse_results << parser.parse

      main = Puppet::Parser::AST::Hostclass.new('', :code => Puppet::Parser::ParserFactory.code_merger.concatenate(parse_results))
      Puppet::Node::Environment.any_instance.stubs(:perform_initial_import).returns main

      type = compile_to_catalog(nil).environment_instance.known_resource_types.definition(:test)
      expect(type.produces).to be_instance_of(Array)
      cns = type.consumes.first

      expect(cns).to be_instance_of(Hash)
      expect(cns[:capability]).to eq('Cap')
      expect(cns[:mappings]).to be_instance_of(Hash)
      expect(cns[:mappings]['host']).to be_instance_of(Puppet::Parser::AST::PopsBridge::Expression)
    end

    it 'can place use a qualified name for defines that produces capabilities' do
      parse_results = []
      parser = Puppet::Parser::ParserFactory.parser

      parser.string = <<-MANIFEST
        class mod {
          define test($hostname) {
            notify { "hostname ${hostname}":}
          }
        }
        include mod
      MANIFEST
      parse_results << parser.parse

      parser.string = <<-MANIFEST
        Mod::Test consumes Cap {
          host => $hostname
        }
      MANIFEST
      parse_results << parser.parse

      main = Puppet::Parser::AST::Hostclass.new('', :code => Puppet::Parser::ParserFactory.code_merger.concatenate(parse_results))
      Puppet::Node::Environment.any_instance.stubs(:perform_initial_import).returns main

      type = compile_to_catalog(nil).environment_instance.known_resource_types.definition('Mod::Test')
      expect(type.produces).to be_instance_of(Array)
      cns = type.consumes.first

      expect(cns).to be_instance_of(Hash)
      expect(cns[:capability]).to eq('Cap')
      expect(cns[:mappings]).to be_instance_of(Hash)
      expect(cns[:mappings]['host']).to be_instance_of(Puppet::Parser::AST::PopsBridge::Expression)
    end
    it "does not allow operator '+>' in a mapping" do
      expect do
      compile_to_catalog(<<-MANIFEST, node)
        define test($hostname) {
          notify { "hostname ${hostname}":}
        }

        Test consumes Cap {
          host +> $hostname
        }
      MANIFEST
      end.to raise_error(Puppet::ParseErrorWithIssue, /Illegal \+> operation.*This operator can not be used in a Capability Mapping/)
    end

    it "does not allow operator '*=>' in a mapping" do
      expect do
        compile_to_catalog(<<-MANIFEST, node)
        define test($hostname) {
          notify { "hostname ${hostname}":}
        }

        Test consumes Cap {
          *=> { host => $hostname }
        }
        MANIFEST
      end.to raise_error(Puppet::ParseError, /The operator '\* =>' in a Capability Mapping is not supported/)
    end

    it "does not allow 'before' relationship to capability mapping" do
      expect do
        compile_to_catalog(<<-MANIFEST, node)
        define test() {
          notify { "hello":}
        }

        Test consumes Cap {}

        test { one: before => Cap[cap] }
        MANIFEST
      end.to raise_error(Puppet::Error, /'before' is not a valid relationship to a capability/)
    end

    ["produces", "consumes"].each do |kw|
      it "creates an error when #{kw} references nonexistent type" do
        manifest = <<-MANIFEST
        Test #{kw} Cap {
          host => $hostname
        }
      MANIFEST

        expect {
          compile_to_catalog(manifest, node)
        }.to raise_error(Puppet::Error,
                         /#{kw} clause references nonexistent type Test/)
      end
    end
  end

  context 'exporting a capability' do
    it "does not add produced resources that are not exported" do
      manifest = <<-MANIFEST
define test($hostname) {
  notify { "hostname ${hostname}":}
}

Test produces Cap {
  host => $hostname
}

test { one: hostname => "ahost" }
    MANIFEST
      catalog = compile_to_catalog(manifest, node)
      expect(catalog.resource("Test[one]")).to be_instance_of(Puppet::Resource)
      expect(catalog.resource_keys.find { |type, _| type == "Cap" }).to be_nil
    end

    it "adds produced resources that are exported" do
      manifest = <<-MANIFEST
define test($hostname) {
  notify { "hostname ${hostname}":}
}

# The $hostname in the produces clause does not refer to this variable,
# instead, it referes to the hostname property of the Test resource
# that is producing the Cap
$hostname = "other_host"

Test produces Cap {
  host => $hostname
}

test { one: hostname => "ahost", export => Cap[two] }
    MANIFEST
      catalog = compile_to_catalog(manifest, node)
      expect(catalog.resource("Test[one]")).to be_instance_of(Puppet::Resource)

      caps = catalog.resource_keys.select { |type, _| type == "Cap" }
      expect(caps.size).to eq(1)

      cap = catalog.resource("Cap[two]")
      expect(cap).to be_instance_of(Puppet::Resource)
      expect(cap["require"]).to eq("Test[one]")
      expect(cap["host"]).to eq("ahost")
      expect(cap.resource_type).to eq(Puppet::Type::Cap)
      expect(cap.tags.any? { |t| t == 'producer:testing' }).to eq(true)
    end
  end

  context 'consuming a capability' do
    def make_catalog(instance)
      manifest = <<-MANIFEST
      define test($hostname = nohost) {
        notify { "hostname ${hostname}":}
      }

      Test consumes Cap {
        hostname => $host
      }
    MANIFEST
      compile_to_catalog(manifest + instance, node)
    end

    def mock_cap_finding
      cap = Puppet::Resource.new("Cap", "two")
      cap["host"] = "ahost"
      Puppet::Resource::CapabilityFinder.expects(:find).returns(cap)
      cap
    end

    it "does not fetch a consumed resource when consume metaparam not set" do
      Puppet::Resource::CapabilityFinder.expects(:find).never
      catalog = make_catalog("test { one: }")
      expect(catalog.resource_keys.find { |type, _| type == "Cap" }).to be_nil
      expect(catalog.resource("Test", "one")["hostname"]).to eq("nohost")
    end

    it "sets hostname from consumed capability" do
      cap = mock_cap_finding
      catalog = make_catalog("test { one: consume => Cap[two] }")
      expect(catalog.resource("Cap[two]")).to eq(cap)
      expect(catalog.resource("Cap[two]")["host"]).to eq("ahost")
      expect(catalog.resource("Test", "one")["hostname"]).to eq("ahost")
    end

    it "does not override explicit hostname property when consuming" do
      cap = mock_cap_finding
      catalog = make_catalog("test { one: hostname => other_host, consume => Cap[two] }")
      expect(catalog.resource("Cap[two]")).to eq(cap)
      expect(catalog.resource("Cap[two]")["host"]).to eq("ahost")
      expect(catalog.resource("Test", "one")["hostname"]).to eq("other_host")
    end

    it "fetches required capability" do
      cap = mock_cap_finding
      catalog = make_catalog("test { one: require => Cap[two] }")
      expect(catalog.resource("Cap[two]")).to eq(cap)
      expect(catalog.resource("Cap[two]")["host"]).to eq("ahost")
      expect(catalog.resource("Test", "one")["hostname"]).to eq("nohost")
    end

    ['export', 'consume'].each do |metaparam|

      it "validates that #{metaparam} metaparameter rejects values that are not resources" do
        expect { make_catalog("test { one: #{metaparam} => 'hello' }") }.to raise_error(Puppet::Error, /not a resource/)
      end

      it "validates that #{metaparam} metaparameter rejects resources that are not capability resources" do
        expect { make_catalog("notify{hello:} test { one: #{metaparam} => Notify[hello] }") }.to raise_error(Puppet::Error, /not a capability resource/)
      end
    end

    context 'producing/consuming resources' do

      let(:ral) do
        compile_to_ral(<<-MANIFEST, node)
  define producer() {
    notify { "producer":}
  }

  define consumer() {
    notify { $title:}
  }

  Producer produces Cap {}

  Consumer consumes Cap {}

  producer {x: export => Cap[cap]}
  consumer {x: consume => Cap[cap]}
  consumer {y: require => Cap[cap]}
        MANIFEST
      end

      let(:graph) do
        graph = Puppet::Graph::RelationshipGraph.new(Puppet::Graph::SequentialPrioritizer.new)
        graph.populate_from(ral)
        graph
      end

      let(:capability) { ral.resource('Cap[cap]') }

      it 'the produced resource depends on the producer' do
        expect(graph.dependencies(capability).map {|d| d.to_s }).to include('Producer[x]')
      end

      it 'the consumer depends on the consumed resource' do
        expect(graph.dependents(capability).map {|d| d.to_s }).to include('Consumer[x]')
      end

      it 'the consumer depends on the required resource' do
        expect(graph.dependents(capability).map {|d| d.to_s }).to include('Consumer[y]')
      end
    end

    context 'producing/consuming resources to/from classes' do

      let(:ral) do
        compile_to_ral(<<-MANIFEST, node)
  define test($hostname) {
    notify { $hostname:}
  }

  class producer($host) {
    notify { p: }
  }

  class consumer($host) {
    test { c: hostname => $host }
  }

  Class[producer] produces Cap {}

  Class[consumer] consumes Cap {}

  class { producer: host => 'produced.host', export => Cap[one]}
  class { consumer: consume => Cap[one]}
        MANIFEST
      end

      let(:graph) do
        graph = Puppet::Graph::RelationshipGraph.new(Puppet::Graph::SequentialPrioritizer.new)
        graph.populate_from(ral)
        graph
      end

      let(:capability) { ral.resource('Cap[one]') }

      it 'the produced resource depends on the producer' do
        expect(graph.dependencies(capability).map {|d| d.to_s }).to include('Class[Producer]')
      end

      it 'the consumer depends on the consumed resource' do
        expect(graph.dependents(capability).map {|d| d.to_s }).to include('Class[Consumer]')
      end

      it 'resource in the consumer class gets values from producer via the capability resource' do
        expect(graph.dependents(capability).map {|d| d.to_s }).to include('Notify[produced.host]')
      end
    end
  end
end
