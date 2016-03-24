require 'spec_helper'
require 'puppet/transaction'
require 'puppet_spec/compiler'
require 'matchers/relationship_graph_matchers'
require 'matchers/include_in_order'
require 'matchers/resource'

describe Puppet::Transaction::AdditionalResourceGenerator do
  include PuppetSpec::Compiler
  include PuppetSpec::Files
  include RelationshipGraphMatchers
  include Matchers::Resource

  let(:prioritizer) { Puppet::Graph::SequentialPrioritizer.new }
  let(:env) { Puppet::Node::Environment.create(:testing, []) }
  let(:node) { Puppet::Node.new('test', :environment => env) }
  let(:loaders) { Puppet::Pops::Loaders.new(env) }

  around :each do |example|
    Puppet::Parser::Compiler.any_instance.stubs(:loaders).returns(loaders)
    Puppet.override(:loaders => loaders, :current_environment => env) do
      Puppet::Type.newtype(:generator) do
        include PuppetSpec::Compiler

        newparam(:name) do
          isnamevar
        end

        newparam(:kind) do
          defaultto :eval_generate
          newvalues(:eval_generate, :generate)
        end

        newparam(:code)

        def respond_to?(method_name)
          method_name == self[:kind] || super
        end

        def eval_generate
          eval_code
        end

        def generate
          eval_code
        end

        def eval_code
          if self[:code]
            compile_to_ral(self[:code]).resources.select { |r| r.ref =~ /Notify/ }
          else
            []
          end
        end
      end

      Puppet::Type.newtype(:autorequire) do
        newparam(:name) do
          isnamevar
        end

        autorequire(:notify) do
          self[:name]
        end
      end

      Puppet::Type.newtype(:gen_auto) do
        newparam(:name) do
          isnamevar
        end

        newparam(:eval_after) do
        end

        def generate()
          [ Puppet::Type.type(:autorequire).new(:name => self[:eval_after]) ]
        end
      end

      Puppet::Type.newtype(:empty) do
        newparam(:name) do
          isnamevar
        end
      end

      Puppet::Type.newtype(:gen_empty) do
        newparam(:name) do
          isnamevar
        end

        newparam(:eval_after) do
        end

        def generate()
          [ Puppet::Type.type(:empty).new(:name => self[:eval_after], :require => "Notify[#{self[:eval_after]}]") ]
        end
      end

      example.run

      Puppet::Type.rmtype(:gen_empty)
      Puppet::Type.rmtype(:eval_after)
      Puppet::Type.rmtype(:autorequire)
      Puppet::Type.rmtype(:generator)
    end
  end

  def find_vertex(graph, type, title)
    graph.vertices.find {|v| v.type == type and v.title == title}
  end

  context "when applying eval_generate" do
    it "should add the generated resources to the catalog" do
      catalog = compile_to_ral(<<-MANIFEST)
        generator { thing:
          code => 'notify { hello: }'
        }
      MANIFEST

      eval_generate_resources_in(catalog, relationship_graph_for(catalog), 'Generator[thing]')

      expect(catalog).to have_resource('Notify[hello]')
    end

    it "should add a sentinel whit for the resource" do
      graph = relationships_after_eval_generating(<<-MANIFEST, 'Generator[thing]')
        generator { thing:
          code => 'notify { hello: }'
        }
      MANIFEST

      expect(find_vertex(graph, :whit, "completed_thing")).to be_a(Puppet::Type.type(:whit))
    end

    it "should replace dependencies on the resource with dependencies on the sentinel" do
      graph = relationships_after_eval_generating(<<-MANIFEST, 'Generator[thing]')
        generator { thing:
          code => 'notify { hello: }'
        }

        notify { last: require => Generator['thing'] }
      MANIFEST

      expect(graph).to enforce_order_with_edge(
        'Whit[completed_thing]', 'Notify[last]')
    end

    it "should add an edge from the nearest ancestor to the generated resource" do
      graph = relationships_after_eval_generating(<<-MANIFEST, 'Generator[thing]')
        generator { thing:
          code => 'notify { hello: } notify { goodbye: }'
        }
      MANIFEST

      expect(graph).to enforce_order_with_edge(
        'Generator[thing]', 'Notify[hello]')
      expect(graph).to enforce_order_with_edge(
        'Generator[thing]', 'Notify[goodbye]')
    end

    it "should add an edge from each generated resource to the sentinel" do
      graph = relationships_after_eval_generating(<<-MANIFEST, 'Generator[thing]')
        generator { thing:
          code => 'notify { hello: } notify { goodbye: }'
        }
      MANIFEST

      expect(graph).to enforce_order_with_edge(
        'Notify[hello]', 'Whit[completed_thing]')
      expect(graph).to enforce_order_with_edge(
        'Notify[goodbye]', 'Whit[completed_thing]')
    end

    it "should add an edge from the resource to the sentinel" do
      graph = relationships_after_eval_generating(<<-MANIFEST, 'Generator[thing]')
        generator { thing:
          code => 'notify { hello: }'
        }
      MANIFEST

      expect(graph).to enforce_order_with_edge(
        'Generator[thing]', 'Whit[completed_thing]')
    end

    it "should contain the generated resources in the same container as the generator" do
      catalog = compile_to_ral(<<-MANIFEST)
        class container {
          generator { thing:
            code => 'notify { hello: }'
          }
        }

        include container
      MANIFEST

      eval_generate_resources_in(catalog, relationship_graph_for(catalog), 'Generator[thing]')

      expect(catalog).to contain_resources_equally('Generator[thing]', 'Notify[hello]')
    end

    it "should return false if an error occurred when generating resources" do
      catalog = compile_to_ral(<<-MANIFEST)
        generator { thing:
          code => 'fail("not a good generation")'
        }
      MANIFEST

      generator = Puppet::Transaction::AdditionalResourceGenerator.new(catalog, relationship_graph_for(catalog), prioritizer)

      expect(generator.eval_generate(catalog.resource('Generator[thing]'))).
        to eq(false)
    end

    it "should return true if resources were generated" do
      catalog = compile_to_ral(<<-MANIFEST)
        generator { thing:
          code => 'notify { hello: }'
        }
      MANIFEST

      generator = Puppet::Transaction::AdditionalResourceGenerator.new(catalog, relationship_graph_for(catalog), prioritizer)

      expect(generator.eval_generate(catalog.resource('Generator[thing]'))).
        to eq(true)
    end

    it "should not add a sentinel if no resources are generated" do
      catalog = compile_to_ral(<<-MANIFEST)
        generator { thing: }
      MANIFEST
      relationship_graph = relationship_graph_for(catalog)

      generator = Puppet::Transaction::AdditionalResourceGenerator.new(catalog, relationship_graph, prioritizer)

      expect(generator.eval_generate(catalog.resource('Generator[thing]'))).
        to eq(false)
      expect(find_vertex(relationship_graph, :whit, "completed_thing")).to be_nil
    end

    it "orders generated resources with the generator" do
      graph = relationships_after_eval_generating(<<-MANIFEST, 'Generator[thing]')
        notify { before: }
        generator { thing:
          code => 'notify { hello: }'
        }
        notify { after: }
      MANIFEST

      expect(order_resources_traversed_in(graph)).to(
        include_in_order("Notify[before]", "Generator[thing]", "Notify[hello]", "Notify[after]"))
    end

    it "orders the generator in manifest order with dependencies" do
      graph = relationships_after_eval_generating(<<-MANIFEST, 'Generator[thing]')
        notify { before: }
        generator { thing:
          code => 'notify { hello: } notify { goodbye: }'
        }
        notify { third: require => Generator['thing'] }
        notify { after: }
      MANIFEST

      expect(order_resources_traversed_in(graph)).to(
        include_in_order("Notify[before]",
                         "Generator[thing]",
                         "Notify[hello]",
                         "Notify[goodbye]",
                         "Notify[third]",
                         "Notify[after]"))
    end

    it "duplicate generated resources are made dependent on the generator" do
      graph = relationships_after_eval_generating(<<-MANIFEST, 'Generator[thing]')
        notify { before: }
        notify { hello: }
        generator { thing:
          code => 'notify { before: }'
        }
        notify { third: require => Generator['thing'] }
        notify { after: }
      MANIFEST

      expect(order_resources_traversed_in(graph)).to(
        include_in_order("Notify[hello]", "Generator[thing]", "Notify[before]", "Notify[third]", "Notify[after]"))
    end

    it "preserves dependencies on duplicate generated resources" do
      graph = relationships_after_eval_generating(<<-MANIFEST, 'Generator[thing]')
        notify { before: }
        generator { thing:
          code => 'notify { hello: } notify { before: }',
          require => 'Notify[before]'
        }
        notify { third: require => Generator['thing'] }
        notify { after: }
      MANIFEST

      expect(order_resources_traversed_in(graph)).to(
        include_in_order("Notify[before]", "Generator[thing]", "Notify[hello]", "Notify[third]", "Notify[after]"))
    end

    def relationships_after_eval_generating(manifest, resource_to_generate)
      catalog = compile_to_ral(manifest)
      relationship_graph = relationship_graph_for(catalog)

      eval_generate_resources_in(catalog, relationship_graph, resource_to_generate)

      relationship_graph
    end

    def eval_generate_resources_in(catalog, relationship_graph, resource_to_generate)
      generator = Puppet::Transaction::AdditionalResourceGenerator.new(catalog, relationship_graph, prioritizer)
      generator.eval_generate(catalog.resource(resource_to_generate))
    end
  end

  context "when applying generate" do
    it "should add the generated resources to the catalog" do
      catalog = compile_to_ral(<<-MANIFEST)
        generator { thing:
          kind => generate,
          code => 'notify { hello: }'
        }
      MANIFEST

      generate_resources_in(catalog, relationship_graph_for(catalog), 'Generator[thing]')

      expect(catalog).to have_resource('Notify[hello]')
    end

    it "should contain the generated resources in the same container as the generator" do
      catalog = compile_to_ral(<<-MANIFEST)
        class container {
          generator { thing:
            kind => generate,
            code => 'notify { hello: }'
          }
        }

        include container
      MANIFEST

      generate_resources_in(catalog, relationship_graph_for(catalog), 'Generator[thing]')

      expect(catalog).to contain_resources_equally('Generator[thing]', 'Notify[hello]')
    end

    it "should add an edge from the nearest ancestor to the generated resource" do
      graph = relationships_after_generating(<<-MANIFEST, 'Generator[thing]')
        generator { thing:
          kind => generate,
          code => 'notify { hello: } notify { goodbye: }'
        }
      MANIFEST

      expect(graph).to enforce_order_with_edge(
        'Generator[thing]', 'Notify[hello]')
      expect(graph).to enforce_order_with_edge(
        'Generator[thing]', 'Notify[goodbye]')
    end

    it "orders generated resources with the generator" do
      graph = relationships_after_generating(<<-MANIFEST, 'Generator[thing]')
        notify { before: }
        generator { thing:
          kind => generate,
          code => 'notify { hello: }'
        }
        notify { after: }
      MANIFEST

      expect(order_resources_traversed_in(graph)).to(
        include_in_order("Notify[before]", "Generator[thing]", "Notify[hello]", "Notify[after]"))
    end

    it "duplicate generated resources are made dependent on the generator" do
      graph = relationships_after_generating(<<-MANIFEST, 'Generator[thing]')
        notify { before: }
        notify { hello: }
        generator { thing:
          kind => generate,
          code => 'notify { before: }'
        }
        notify { third: require => Generator['thing'] }
        notify { after: }
      MANIFEST

      expect(order_resources_traversed_in(graph)).to(
        include_in_order("Notify[hello]", "Generator[thing]", "Notify[before]", "Notify[third]", "Notify[after]"))
    end

    it "preserves dependencies on duplicate generated resources" do
      graph = relationships_after_generating(<<-MANIFEST, 'Generator[thing]')
        notify { before: }
        generator { thing:
          kind => generate,
          code => 'notify { hello: } notify { before: }',
          require => 'Notify[before]'
        }
        notify { third: require => Generator['thing'] }
        notify { after: }
      MANIFEST

      expect(order_resources_traversed_in(graph)).to(
        include_in_order("Notify[before]", "Generator[thing]", "Notify[hello]", "Notify[third]", "Notify[after]"))
    end

    it "orders the generator in manifest order with dependencies" do
      graph = relationships_after_generating(<<-MANIFEST, 'Generator[thing]')
        notify { before: }
        generator { thing:
          kind => generate,
          code => 'notify { hello: } notify { goodbye: }'
        }
        notify { third: require => Generator['thing'] }
        notify { after: }
      MANIFEST

      expect(order_resources_traversed_in(graph)).to(
        include_in_order("Notify[before]",
                         "Generator[thing]",
                         "Notify[hello]",
                         "Notify[goodbye]",
                         "Notify[third]",
                         "Notify[after]"))
    end

    it "runs autorequire on the generated resource" do
      graph = relationships_after_generating(<<-MANIFEST, 'Gen_auto[thing]')
        gen_auto { thing:
          eval_after => hello,
        }

        notify { hello: }
        notify { goodbye: }
      MANIFEST

      expect(order_resources_traversed_in(graph)).to(
        include_in_order("Gen_auto[thing]",
                         "Notify[hello]",
                         "Autorequire[hello]",
                         "Notify[goodbye]"))
    end

    it "evaluates metaparameters on the generated resource" do
      graph = relationships_after_generating(<<-MANIFEST, 'Gen_empty[thing]')
        gen_empty { thing:
          eval_after => hello,
        }

        notify { hello: }
        notify { goodbye: }
      MANIFEST

      expect(order_resources_traversed_in(graph)).to(
        include_in_order("Gen_empty[thing]",
                         "Notify[hello]",
                         "Empty[hello]",
                         "Notify[goodbye]"))
    end

    def relationships_after_generating(manifest, resource_to_generate)
      catalog = compile_to_ral(manifest)
      generate_resources_in(catalog, nil, resource_to_generate)
      relationship_graph_for(catalog)
    end

    def generate_resources_in(catalog, relationship_graph, resource_to_generate)
      generator = Puppet::Transaction::AdditionalResourceGenerator.new(catalog, relationship_graph, prioritizer)
      generator.generate_additional_resources(catalog.resource(resource_to_generate))
    end
  end

  def relationship_graph_for(catalog)
    relationship_graph = Puppet::Graph::RelationshipGraph.new(prioritizer)
    relationship_graph.populate_from(catalog)
    relationship_graph
  end

  def order_resources_traversed_in(relationships)
    order_seen = []
    relationships.traverse { |resource| order_seen << resource.ref }
    order_seen
  end

  RSpec::Matchers.define :contain_resources_equally do |*resource_refs|
    match do |catalog|
      @containers = resource_refs.collect do |resource_ref|
        catalog.container_of(catalog.resource(resource_ref)).ref
      end

      @containers.all? { |resource_ref| resource_ref == @containers[0] }
    end

    def failure_message
      "expected #{@expected.join(', ')} to all be contained in the same resource but the containment was #{@expected.zip(@containers).collect { |(res, container)| res + ' => ' + container }.join(', ')}"
    end
  end
end
