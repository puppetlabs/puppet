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
        cons { two: host => ahost, consume => Cap[cap] }
      }

      site {
        app { anapp:
          nodes => {
            Node[first] => Prod[one],
            Node[second] => Cons[two]
          }
        }
      }
EOS

FAULTY_MANIFEST = <<-EOS
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
      cons { two: host => ahost, consume => Cap[cap] }
    }

    # app is not in site => error
    app { anapp:
      nodes => {
        Node[first] => Prod[one],
        Node[second] => Cons[two]
      }
    }
EOS

MANIFEST_WITH_SITE = <<-EOS
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
      cons { two: host => ahost, consume => Cap[cap] }
    }

    $one = not_the_value_one
    $two = two

    node default {
      notify { "on a node": }
    }

    notify { 'ignore me': }

    site {
      $one = one
      app { anapp:
        nodes => {
          Node[first] => Prod[$one],
          Node[second] => Cons[$two]
        }
      }
    }
EOS

MANIFEST_WITH_ILLEGAL_RESOURCE = <<-EOS
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

    site {
      # The rouge expression is here
      notify { 'fail me': }
      $one = one
      app { anapp:
        nodes => {
          Node[first] => Prod[one],
          Node[second] => Cons[two]
        }
      }
    }
EOS

  describe "a node catalog" do
    it "is unaffected for a non-participating node" do
      catalog = compile_to_catalog(MANIFEST, Puppet::Node.new('other'))
      types = catalog.resource_keys.map { |type, _| type }.uniq.sort
      expect(types).to eq(["Class", "Stage"])
    end

    it "an application instance must be contained in a site" do
      expect { compile_to_catalog(FAULTY_MANIFEST, Puppet::Node.new('first'))
      }.to raise_error(/Application instances .* can only be contained within a Site/)
    end

    context "for producing node" do
      let(:compiled_node) { Puppet::Node.new('first') }
      let(:compiled_catalog) { compile_to_catalog(MANIFEST, compiled_node)}

      { "App[anapp]"         => 'application instance',
        "Cap[cap]"           => 'capability resource',
        "Prod[one]"          => 'component',
        "Notify[host ahost]" => 'node resource'
      }.each do |k,v|
        it "contains the #{v} (#{k})" do
            expect(compiled_catalog.resource(k)).not_to be_nil
        end
      end

      it "does not contain the consumed resource (Cons[two])" do
        expect(compiled_catalog.resource("Cons[two]")).to be_nil
      end
    end

    context "for consuming node" do
      let(:compiled_node) { Puppet::Node.new('second') }
      let(:compiled_catalog) { compile_to_catalog(MANIFEST, compiled_node)}
      let(:cap) {
        the_cap = Puppet::Resource.new("Cap", "cap")
        the_cap["host"] = "ahost"
        the_cap
      }

      { "App[anapp]"         => 'application instance',
        "Cap[cap]"           => 'capability resource',
        "Cons[two]"          => 'component',
        "Notify[host ahost]" => 'node resource'
      }.each do |k,v|
        it "contains the #{v} (#{k})" do
            # Mock the connection to Puppet DB
            Puppet::Resource::CapabilityFinder.expects(:find).returns(cap)
            expect(compiled_catalog.resource(k)).not_to be_nil
        end
      end

      it "does not contain the produced resource (Prod[one])" do
        # Mock the connection to Puppet DB
        Puppet::Resource::CapabilityFinder.expects(:find).returns(cap)
        expect(compiled_catalog.resource("Prod[one]")).to be_nil
      end
    end

    context "when using a site expression" do
      # The site expression must be evaluated in a node catalog compilation because
      # the application instantiations inside it may contain other logic (local variables)
      # that are used to instantiate an application. The application instances are needed.
      #
      it "the node expressions is evaluated" do
        catalog = compile_to_catalog(MANIFEST_WITH_SITE, Puppet::Node.new('other'))
        types = catalog.resource_keys.map { |type, _| type }.uniq.sort
        expect(types).to eq(["Class", "Node", "Notify", "Stage"])
        expect(catalog.resource("Notify[on a node]")).to_not be_nil
        expect(catalog.resource("Notify[on the site]")).to be_nil
      end

    end

    context "when using a site expression" do
      it "the site expression is not evaluated in a node compilation" do
        catalog = compile_to_catalog(MANIFEST_WITH_SITE, Puppet::Node.new('other'))
        types = catalog.resource_keys.map { |type, _| type }.uniq.sort
        expect(types).to eq(["Class", "Node", "Notify", "Stage"])
        expect(catalog.resource("Notify[on a node]")).to_not be_nil
        expect(catalog.resource("Notify[on the site]")).to be_nil
      end

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

    it "an application instance must be contained in a site" do
      expect { compile_to_env_catalog(FAULTY_MANIFEST)
      }.to raise_error(/Application instances .* can only be contained within a Site/)
    end

    context "when using a site expression" do
      it "includes components and capability resources" do
        catalog = compile_to_env_catalog(MANIFEST_WITH_SITE).to_resource
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

      it "the site expression is evaluated in an environment compilation" do
        catalog = compile_to_env_catalog(MANIFEST_WITH_SITE).to_resource
        types = catalog.resource_keys.map { |type, _| type }.uniq.sort
        expect(types).to eq(["App", "Class", "Cons", "Prod", "Site", "Stage"])
        expect(catalog.resource("Notify[on a node]")).to be_nil
        apps = catalog.resources.select do |res|
          res.resource_type && res.resource_type.application?
        end
        expect(apps.size).to eq(1)
        app = apps.first
        comps = catalog.direct_dependents_of(app).map(&:ref).sort
        expect(comps).to eq(["Cons[two]", "Prod[one]"])
      end

      it "fails if there are non component resources in the site" do
        expect {
        catalog = compile_to_env_catalog(MANIFEST_WITH_ILLEGAL_RESOURCE).to_resource
        }.to raise_error(/Only application components can appear inside a site - Notify\[fail me\] is not allowed at line 20/)
      end
    end
  end


  describe "when validation of nodes" do
    it 'validates that the key of a node mapping is a Node' do
      expect { compile_to_catalog(<<-EOS, Puppet::Node.new('other'))
        application app {
        }

        site {
          app { anapp:
            nodes => {
              'hello' => Node[other],
            }
          }
        }
        EOS
      }.to raise_error(Puppet::Error, /hello is not a Node/)
    end

    it 'validates that the value of a node mapping is a resource' do
      expect { compile_to_catalog(<<-EOS, Puppet::Node.new('other'))
        application app {
        }

        site {
          app { anapp:
            nodes => {
              Node[other] => 'hello'
            }
          }
        }
      EOS
      }.to raise_error(Puppet::Error, /hello is not a resource/)
    end

    it 'validates that the value can be an array or resources' do
      expect { compile_to_catalog(<<-EOS, Puppet::Node.new('other'))
        define p {
          notify {$title:}
        }

        application app {
          p{one:}
          p{two:}
        }

        site {
          app { anapp:
            nodes => {
              Node[other] => [P[one],P[two]]
            }
          }
        }
      EOS
      }.not_to raise_error
    end

    it 'validates that the is bound to exactly one node' do
      expect { compile_to_catalog(<<-EOS, Puppet::Node.new('first'))
        define p {
          notify {$title:}
        }

        application app {
          p{one:}
        }

        site {
          app { anapp:
            nodes => {
              Node[first] => P[one],
              Node[second] => P[one],
            }
          }
        }
      EOS
      }.to raise_error(Puppet::Error, /maps component P\[one\] to multiple nodes/)
    end
  end
end
