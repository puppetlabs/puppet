require 'spec_helper'
require 'matchers/include_in_order'
require 'puppet_spec/compiler'

describe "a resource in the catalog" do
  include PuppetSpec::Compiler

  it "is in the order that the resource is added to the catalog" do
    catalog = compile_to_catalog(<<-EOM)
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

    expect(catalog.resources.map(&:ref)).to include_in_order(
      "Class[First]",
      "Second[position]",
      "Class[Third]",
      "Fourth[position]"
    )
  end
end
