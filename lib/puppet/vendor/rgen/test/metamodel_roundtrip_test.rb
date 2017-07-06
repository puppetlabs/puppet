$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/array_extensions'
require 'rgen/util/model_comparator'
require 'mmgen/metamodel_generator'
require 'rgen/instantiator/ecore_xml_instantiator'
require 'rgen/serializer/xmi20_serializer'

class MetamodelRoundtripTest < Test::Unit::TestCase
  
  TEST_DIR = File.dirname(__FILE__)+"/metamodel_roundtrip_test"
  
  include MMGen::MetamodelGenerator
  include RGen::Util::ModelComparator
  
  module Regenerated
    Inside = binding
  end
  
  def test_generator
    require TEST_DIR+"/TestModel.rb"
    outfile = TEST_DIR+"/TestModel_Regenerated.rb"		
    generateMetamodel(HouseMetamodel.ecore, outfile)
    
    File.open(outfile) do |f|
      eval(f.read, Regenerated::Inside)
    end
    
    assert modelEqual?(HouseMetamodel.ecore, Regenerated::HouseMetamodel.ecore, ["instanceClassName"])
  end
  
  module UMLRegenerated
    Inside = binding
  end
  
  def test_generate_from_ecore
    outfile = TEST_DIR+"/houseMetamodel_from_ecore.rb"

    env = RGen::Environment.new
    File.open(TEST_DIR+"/houseMetamodel.ecore") { |f|
      ECoreXMLInstantiator.new(env).instantiate(f.read)
    }
    rootpackage = env.find(:class => RGen::ECore::EPackage).first
    rootpackage.name = "HouseMetamodel"
    generateMetamodel(rootpackage, outfile)
    
    File.open(outfile) do |f|
      eval(f.read, UMLRegenerated::Inside, "test_eval", 0)
    end
  end
  
  def test_ecore_serializer
    require TEST_DIR+"/TestModel.rb"
    File.open(TEST_DIR+"/houseMetamodel_Regenerated.ecore","w") do |f|
	  	ser = RGen::Serializer::XMI20Serializer.new(f)
	  	ser.serialize(HouseMetamodel.ecore)
	 	end
  end
 
  BuiltinTypesTestEcore = TEST_DIR+"/using_builtin_types.ecore"

  def test_ecore_serializer_builtin_types
    mm = RGen::ECore::EPackage.new(:name => "P1", :eClassifiers => [
      RGen::ECore::EClass.new(:name => "C1", :eStructuralFeatures => [
        RGen::ECore::EAttribute.new(:name => "a1", :eType => RGen::ECore::EString), 
        RGen::ECore::EAttribute.new(:name => "a2", :eType => RGen::ECore::EInt), 
        RGen::ECore::EAttribute.new(:name => "a3", :eType => RGen::ECore::ELong), 
        RGen::ECore::EAttribute.new(:name => "a4", :eType => RGen::ECore::EFloat), 
        RGen::ECore::EAttribute.new(:name => "a5", :eType => RGen::ECore::EBoolean) 
      ])
    ])
    outfile = TEST_DIR+"/using_builtin_types_serialized.ecore"
    File.open(outfile, "w") do |f|
      ser = RGen::Serializer::XMI20Serializer.new(f)
      ser.serialize(mm)
    end
    assert_equal(File.read(BuiltinTypesTestEcore), File.read(outfile))
  end

  def test_ecore_instantiator_builtin_types
    env = RGen::Environment.new
    File.open(BuiltinTypesTestEcore) { |f|
      ECoreXMLInstantiator.new(env).instantiate(f.read)
    }
    a1 = env.find(:class => RGen::ECore::EAttribute, :name => "a1").first
    assert_equal(RGen::ECore::EString, a1.eType)
    a2 = env.find(:class => RGen::ECore::EAttribute, :name => "a2").first
    assert_equal(RGen::ECore::EInt, a2.eType)
    a3 = env.find(:class => RGen::ECore::EAttribute, :name => "a3").first
    assert_equal(RGen::ECore::ELong, a3.eType)
    a4 = env.find(:class => RGen::ECore::EAttribute, :name => "a4").first
    assert_equal(RGen::ECore::EFloat, a4.eType)
    a5 = env.find(:class => RGen::ECore::EAttribute, :name => "a5").first
    assert_equal(RGen::ECore::EBoolean, a5.eType)
  end

end
