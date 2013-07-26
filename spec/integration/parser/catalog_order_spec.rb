require 'spec_helper'
require 'matchers/include_in_order'
require 'puppet_spec/compiler'

describe "Transmission of the catalog to the agent" do
  include PuppetSpec::Compiler

  it "preserves the order in which the resources are added to the catalog" do
    master_catalog = compile_to_catalog(<<-EOM)
      define fourth() { }
      class third { }

      define second() {
        fourth { "position": }
      }

      class first {
        second { "position": }
        class { "third": }
      }

      include first
    EOM

    expect(master_catalog.resources.map(&:ref)).to include_in_order(
      "Class[First]",
      "Second[position]",
      "Class[Third]",
      "Fourth[position]"
    )

    agent_catalog = Puppet::Resource::Catalog.convert_from(:pson, master_catalog.render(:pson))

    expect(agent_catalog.resources.map(&:ref)).to include_in_order(
      "Class[First]",
      "Second[position]",
      "Class[Third]",
      "Fourth[position]"
    )
  end
end
