#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'
require_relative 'pops/parser/parser_rspec_helper'
require 'puppet/parser/environment_compiler'

describe "Application instantiation" do
  include PuppetSpec::Compiler
  # We pull this in because we need access to with_app_management; and
  # since that has to root around in the guts of the Pops parser, there's
  # no really elegant way to do this
  include ParserRspecHelper

  def compile_to_env_catalog(string)
    Puppet[:code] = string
    env = Puppet::Node::Environment.create("test", ["/dev/null"])
    Puppet::Parser::EnvironmentCompiler.compile(env).filter { |r| r.virtual? }
  end


  before :each do
    with_app_management(true)
    Puppet::Type.newtype :cap, :is_capability => true do
      newparam :name
      newparam :host
    end
  end

  after :each do
    Puppet::Type.rmtype(:cap)
    with_app_management(false)
  end

  MANIFEST = <<-EOS
      define prod($host) {
        notify { "host ${host}":}
      }

      Prod produces Cap { }

      define cons($host) {
        notify { "host ${host}": }
      }

      Cons consumes Cap { }

      application app {
        prod { one: host => ahost, export => Cap[cap] }
        cons { two: consume => Cap[cap] }
      }

      app { anapp:
        nodes => {
          Node[first] => Prod[one],
          Node[second] => Cons[two]
        }
      }
EOS

  describe "in node catalogs" do
    it "does not affect a nonparticpating node" do
      catalog = compile_to_catalog(MANIFEST, Puppet::Node.new('other'))
      types = catalog.resource_keys.map { |type, _| type }.uniq.sort
      expect(types).to eq(["Class", "Stage"])
    end

    it "adds the application instance, capability resource, and component on the producing node" do
      catalog = compile_to_catalog(MANIFEST, Puppet::Node.new('first'))
      ["App[anapp]", "Cap[cap]", "Prod[one]", "Notify[host ahost]"].each do |res|
        expect(catalog.resource(res)).not_to be_nil
      end
      expect(catalog.resource("Cons[two]")).to be_nil
    end

    it "adds the application instance, capability resource, and component on the consuming node " do
      cap = Puppet::Resource.new("Cap", "cap")
      cap["host"] = "ahost"
      Puppet::Resource::CapabilityFinder.expects(:find).returns(cap)

      catalog = compile_to_catalog(MANIFEST, Puppet::Node.new('second'))
      ["App[anapp]", "Cap[cap]", "Cons[two]", "Notify[host ahost]"].each do |res|
        expect(catalog.resource(res)).not_to be_nil
      end
      expect(catalog.resource("Prod[one]")).to be_nil
    end
  end

  describe "in the environment catalog" do
    it "includes components and capability resources" do
      catalog = compile_to_env_catalog(MANIFEST).to_resource
      apps = catalog.resources.select do |res|
        res.resource_type && res.resource_type.application?
      end
      expect(apps.size).to eq(1)
      app = apps.first
      expect(app["nodes"]).not_to be_nil
      comps = catalog.direct_dependents_of(app).map(&:ref).sort
      expect(comps).to eq(["Cons[two]", "Prod[one]"])

      prod = catalog.resource("Prod[one]")
      expect(prod).not_to be_nil
      expect(prod.export.map(&:ref)).to eq(["Cap[cap]"])

      cons = catalog.resource("Cons[two]")
      expect(cons).not_to be_nil
      expect(cons[:consume].ref).to eq("Cap[cap]")
    end
  end
end
