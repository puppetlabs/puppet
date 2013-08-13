require 'spec_helper'
require 'puppet/transaction'
require 'puppet_spec/compiler'
require 'matchers/relationship_graph_matchers'
require 'matchers/include_in_order'

describe Puppet::Transaction::AdditionalResourceGenerator do
  include PuppetSpec::Compiler
  include PuppetSpec::Files
  include RelationshipGraphMatchers

  def find_vertex(graph, type, title)
    graph.vertices.find {|v| v.type == type and v.title == title}
  end

  Puppet::Type.newtype(:generator) do
    include PuppetSpec::Compiler

    newparam(:name) do
      isnamevar
    end

    newparam(:code)

    def eval_generate
      if self[:code]
        compile_to_ral(self[:code]).resources
      else
        []
      end
    end
  end

  it "should add the generated resources to the catalog" do
    catalog = catalog_after_generating(<<-MANIFEST, 'Generator[thing]')
      generator { thing:
        code => 'notify { hello: }'
      }
    MANIFEST

    expect(catalog).to have_resource('Notify[hello]')
  end

  it "should add a sentinel whit for the resource" do
    catalog = catalog_after_generating(<<-MANIFEST, 'Generator[thing]')
      generator { thing:
        code => 'notify { hello: }'
      }
    MANIFEST

    find_vertex(catalog.relationship_graph, :whit, "completed_thing").must be_a(Puppet::Type.type(:whit))
  end

  it "should replace dependencies on the resource with dependencies on the sentinel" do
    catalog = catalog_after_generating(<<-MANIFEST, 'Generator[thing]')
      generator { thing:
        code => 'notify { hello: }'
      }

      notify { last: require => Generator['thing'] }
    MANIFEST

    expect(catalog.relationship_graph).to enforce_order_with_edge(
      'Whit[completed_thing]', 'Notify[last]')
  end

  it "should add an edge from the nearest ancestor to the generated resource" do
    catalog = catalog_after_generating(<<-MANIFEST, 'Generator[thing]')
      generator { thing:
        code => 'notify { hello: } notify { goodbye: }'
      }
    MANIFEST

    expect(catalog.relationship_graph).to enforce_order_with_edge(
      'Generator[thing]', 'Notify[hello]')
    expect(catalog.relationship_graph).to enforce_order_with_edge(
      'Generator[thing]', 'Notify[goodbye]')
  end

  it "should add an edge from each generated resource to the sentinel" do
    catalog = catalog_after_generating(<<-MANIFEST, 'Generator[thing]')
      generator { thing:
        code => 'notify { hello: } notify { goodbye: }'
      }
    MANIFEST

    expect(catalog.relationship_graph).to enforce_order_with_edge(
      'Notify[hello]', 'Whit[completed_thing]')
    expect(catalog.relationship_graph).to enforce_order_with_edge(
      'Notify[goodbye]', 'Whit[completed_thing]')
  end

  it "should add an edge from the resource to the sentinel" do
    catalog = catalog_after_generating(<<-MANIFEST, 'Generator[thing]')
      generator { thing:
        code => 'notify { hello: }'
      }
    MANIFEST

    expect(catalog.relationship_graph).to enforce_order_with_edge(
      'Generator[thing]', 'Whit[completed_thing]')
  end

  it "should return false if an error occured when generating resources" do
    catalog = compile_to_ral(<<-MANIFEST)
      generator { thing:
        code => 'fail("not a good generation")'
      }
    MANIFEST

    generator = Puppet::Transaction::AdditionalResourceGenerator.new(catalog, catalog.relationship_graph)

    expect(generator.eval_generate(catalog.resource('Generator[thing]'))).
      to eq(false)
  end

  it "should return true if resources were generated" do
    catalog = compile_to_ral(<<-MANIFEST)
      generator { thing:
        code => 'notify { hello: }'
      }
    MANIFEST

    generator = Puppet::Transaction::AdditionalResourceGenerator.new(catalog, catalog.relationship_graph)

    expect(generator.eval_generate(catalog.resource('Generator[thing]'))).
      to eq(true)
  end

  it "should not add a sentinel if no resources are generated" do
    catalog = compile_to_ral(<<-MANIFEST)
      generator { thing: }
    MANIFEST

    generator = Puppet::Transaction::AdditionalResourceGenerator.new(catalog, catalog.relationship_graph)

    expect(generator.eval_generate(catalog.resource('Generator[thing]'))).
      to eq(false)
    expect(find_vertex(catalog.relationship_graph, :whit, "completed_thing")).to be_nil
  end

  def catalog_after_generating(manifest, resource_to_generate)
    catalog = compile_to_ral(manifest)

    generator = Puppet::Transaction::AdditionalResourceGenerator.new(catalog, catalog.relationship_graph)
    generator.eval_generate(catalog.resource(resource_to_generate))

    catalog
  end

  it "orders generated resources with the generator" do
    catalog = catalog_after_generating(<<-MANIFEST, 'Generator[thing]')
      notify { before: }
      generator { thing:
        code => 'notify { hello: }'
      }
      notify { after: }
    MANIFEST

    expect(order_resources_traversed_in(catalog.relationship_graph)).to(
      include_in_order("Notify[before]", "Generator[thing]", "Notify[hello]", "Notify[after]"))
  end

  def order_resources_traversed_in(relationships)
    order_seen = []
    relationships.traverse { |resource| order_seen << resource.ref }
    order_seen
  end
end

RSpec::Matchers.define :have_resource do |expected_resource|
  match do |actual_catalog|
    actual_catalog.resource(expected_resource)
  end

  def failure_message_for_should
    "expected #{@actual.to_dot} to include #{@expected[0]}"
  end
end
