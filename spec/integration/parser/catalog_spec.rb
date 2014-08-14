require 'spec_helper'
require 'matchers/include_in_order'
require 'puppet_spec/compiler'
require 'puppet/indirector/catalog/compiler'

describe "A catalog" do
  include PuppetSpec::Compiler

  shared_examples_for "when compiled" do
    context "when transmitted to the agent" do

      it "preserves the order in which the resources are added to the catalog" do
        resources_in_declaration_order = ["Class[First]",
                                          "Second[position]",
                                          "Class[Third]",
                                          "Fourth[position]"]

        master_catalog, agent_catalog = master_and_agent_catalogs_for(<<-EOM)
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

        expect(resources_in(master_catalog)).
          to include_in_order(*resources_in_declaration_order)
        expect(resources_in(agent_catalog)).
          to include_in_order(*resources_in_declaration_order)
      end

      it "does not contain unrealized, virtual resources" do
        virtual_resources = ["Unrealized[unreal]", "Class[Unreal]"]

        master_catalog, agent_catalog = master_and_agent_catalogs_for(<<-EOM)
          class unreal { }
          define unrealized() { }

          class real {
            @unrealized { "unreal": }
            @class { "unreal": }
          }

          include real
        EOM

        expect(resources_in(master_catalog)).to_not include(*virtual_resources)
        expect(resources_in(agent_catalog)).to_not include(*virtual_resources)
      end

      it "does not contain unrealized, exported resources" do
        exported_resources = ["Unrealized[unreal]", "Class[Unreal]"]

        master_catalog, agent_catalog = master_and_agent_catalogs_for(<<-EOM)
          class unreal { }
          define unrealized() { }

          class real {
            @@unrealized { "unreal": }
            @@class { "unreal": }
          }

          include real
        EOM

        expect(resources_in(master_catalog)).to_not include(*exported_resources)
        expect(resources_in(agent_catalog)).to_not include(*exported_resources)
      end
    end
  end

  describe 'using classic parser' do
    before :each do
      Puppet[:parser] = 'current'
    end
    it_behaves_like 'when compiled' do
    end

    it "compiles resource creation from appended array as two separate resources" do
      # moved here from acceptance test "jeff_append_to_array.rb"
      master_catalog = master_catalog_for(<<-EOM)
        class parent {
          $arr1 = [ "parent array element" ]
        }
        class parent::child inherits parent {
          $arr1 += ["child array element"]
          notify { $arr1: }
        }
        include parent::child
      EOM
      expect(resources_in(master_catalog)).to include('Notify[parent array element]', 'Notify[child array element]')
    end
  end

  describe 'using future parser' do
    before :each do
      Puppet[:parser] = 'future'
    end
    it_behaves_like 'when compiled' do
    end
  end

  def master_catalog_for(manifest)
    master_catalog = Puppet::Resource::Catalog::Compiler.new.filter(compile_to_catalog(manifest))
  end

  def master_and_agent_catalogs_for(manifest)
    compiler = Puppet::Resource::Catalog::Compiler.new
    master_catalog = compiler.filter(compile_to_catalog(manifest))
    agent_catalog = Puppet::Resource::Catalog.convert_from(:pson, master_catalog.render(:pson))
    [master_catalog, agent_catalog]
  end

  def resources_in(catalog)
    catalog.resources.map(&:ref)
  end
end
