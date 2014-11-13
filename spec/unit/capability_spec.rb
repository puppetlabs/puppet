#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'
require_relative 'pops/parser/parser_rspec_helper'

describe "Capability types" do
  include PuppetSpec::Compiler
  # We pull this in because we need access to with_app_management; and
  # since that has to root around in the guts of the Pops parser, there's
  # no really elegant way to do this
  include ParserRspecHelper

  before :each do
    with_app_management(true)
  end

  after :each do
    with_app_management(false)
  end

  describe "annotations" do
    it "adds a blueprint for a produced resource" do
      catalog = compile_to_catalog(<<-MANIFEST)
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
      catalog = compile_to_catalog(<<-MANIFEST)
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

    ["produces", "consumes"].each do |kw|
      it "creates an error when #{kw} references nonexistent type" do
        manifest = <<-MANIFEST
        Test #{kw} Cap {
          host => $hostname
        }
      MANIFEST

        expect {
          compile_to_catalog(manifest)
        }.to raise_error(Puppet::Error,
                         /#{kw} clause references nonexistent type Test/)
      end
    end
  end

  describe "exporting a capability" do
    before(:each) do
      Puppet::Type.newtype(:cap) do
        newparam :name
        newparam :host
      end
    end

    after :each do
      Puppet::Type.rmtype(:cap)
    end

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
      catalog = compile_to_catalog(manifest)
      expect(catalog.resource("Test[one]")).to be_instance_of(Puppet::Resource)
      expect(catalog.resource_keys.find { |type, title| type == "Cap" }).to be_nil
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
      catalog = compile_to_catalog(manifest)
      expect(catalog.resource("Test[one]")).to be_instance_of(Puppet::Resource)

      caps = catalog.resource_keys.select { |type, title| type == "Cap" }
      expect(caps.size).to eq(1)

      cap = catalog.resource("Cap[two]")
      expect(cap).to be_instance_of(Puppet::Resource)
      expect(cap["require"]).to eq("Test[one]")
      expect(cap["host"]).to eq("ahost")
      expect(cap.resource_type).to eq(Puppet::Type::Cap)
      expect(cap.tags.any? { |t| t == "producer:production" }).to eq(true)
    end
  end
end
