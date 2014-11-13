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
    Puppet::Type.rmtype(:cap)
    with_app_management(false)
  end

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
