require 'puppet'                 # must be required before requiring vendored code
require 'rgen/metamodel_builder' # requiring from rgen (done on demand)

# This is a RGen ecore metamodel specific to this test case. Expressed as an internal RGen ecore DSL
module RgenVendorSpec
  
  class Person < RGen::MetamodelBuilder::MMBase
    has_attr 'name', String
    has_attr 'age', Integer
  end
  
  class Organization < RGen::MetamodelBuilder::MMBase
    contains_many_uni 'members', Person
  end
end

describe 'loading rgen and conducting a smoke test should work' do
  include RgenVendorSpec
  it 'should create an Person and an Organization and answer a meta model query' do
    p = RgenVendorSpec::Person.new
    p.name = 'Mary Model'
    p.age = 36
    p.class.should == RgenVendorSpec::Person
    p.name.should == "Mary Model"
    p.age.should == 36
    o = RgenVendorSpec::Organization.new
    o.addMembers(p)
    p.eContainer.should == o
    p.eContainingFeature.should == :members
  end
end