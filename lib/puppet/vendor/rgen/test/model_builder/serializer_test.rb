$:.unshift File.dirname(__FILE__) + "/../lib"

require 'test/unit'
require 'rgen/ecore/ecore'

# The following would also influence other tests...
#
#module RGen::ECore
#  class EGenericType < EObject
#    contains_many_uni 'eTypeArguments', EGenericType
#  end
#  class ETypeParameter < ENamedElement
#  end
#  class EClassifier
#    contains_many_uni 'eTypeParameters', ETypeParameter
#  end
#  class ETypedElement
#    has_one 'eGenericType', EGenericType
#  end
#end
#
#RGen::ECore::ECoreInterface.clear_ecore_cache
#RGen::ECore::EString.ePackage = RGen::ECore.ecore

require 'rgen/environment'
require 'rgen/model_builder/model_serializer'
require 'rgen/instantiator/ecore_xml_instantiator'
require 'rgen/model_builder'
require 'model_builder/statemachine_metamodel'

class ModelSerializerTest < Test::Unit::TestCase
  def test_ecore_internal
    File.open(File.dirname(__FILE__)+"/ecore_internal.rb","w") do |f|
      serializer = RGen::ModelBuilder::ModelSerializer.new(f, RGen::ECore.ecore)
      serializer.serialize(RGen::ECore.ecore)
    end
  end
  
  def test_roundtrip
    model = %{\
statemachine "Airconditioner" do
  state "Off", :kind => :START
  compositeState "On" do
    state "Heating"
    state "Cooling"
    state "Dumm"
  end
  transition "_Transition1", :sourceState => "On.Cooling", :targetState => "On.Heating"
  transition "_Transition2", :sourceState => "On.Heating", :targetState => "On.Cooling"
end
}
    check_roundtrip(StatemachineMetamodel, model)
  end
  
  module AmbiguousRoleMM
    extend RGen::MetamodelBuilder::ModuleExtension
    class A < RGen::MetamodelBuilder::MMBase
    end
    class B < RGen::MetamodelBuilder::MMBase
    end
    class C < B
    end
    A.contains_many 'role1', B, 'back1'
    A.contains_many 'role2', B, 'back2'
  end

  def test_roundtrip_ambiguous_role
    model = %{\
a "_A1" do
  b "_B1", :as => :role1
  b "_B2", :as => :role2
  c "_C1", :as => :role2
end
}
    check_roundtrip(AmbiguousRoleMM, model)
  end

  private

  def build_model(mm, model)
    RGen::ModelBuilder.build(mm) do
      eval(model)
    end
  end

  def check_roundtrip(mm, model)
    sm = build_model(mm, model)
    f = StringIO.new
    serializer = RGen::ModelBuilder::ModelSerializer.new(f, mm.ecore)
    serializer.serialize(sm)
    assert_equal model, f.string
  end

end
