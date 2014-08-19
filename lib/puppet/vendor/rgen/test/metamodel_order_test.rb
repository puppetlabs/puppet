$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/ecore/ecore'
require 'rgen/array_extensions'

class MetamodelOrderTest < Test::Unit::TestCase
	include RGen::ECore
	
  module TestMM1
    extend RGen::MetamodelBuilder::ModuleExtension

    class Class11 < RGen::MetamodelBuilder::MMBase
    end

    module Module11
      extend RGen::MetamodelBuilder::ModuleExtension

      DataType111 = RGen::MetamodelBuilder::DataTypes::Enum.new(:name => "DataType111" ,:literals => {:b => 1})
      DataType112 = RGen::MetamodelBuilder::DataTypes::Enum.new(:name => "DataType112", :literals => {:b => 1})

      class Class111 < RGen::MetamodelBuilder::MMBase
      end
      
      # anonymous classes won't be handled by the order helper, but will be in eClassifiers
      Class112 = Class.new(RGen::MetamodelBuilder::MMBase)

      # classes that are not MMBase won't be handled
      class Class113 
      end

      # modules that are not extended by the ModuleExtension are not handled
      module Module111
      end

      # however it can be extendend later on
      module Module112
        # this one is not handled by the order helper since Module112 doesn't have the ModuleExtension yet
        # however, it will be in eClassifiers
        class Class1121 < RGen::MetamodelBuilder::MMBase
        end
      end
      # this datatype must be in Module11 not Module112
      DataType113 = RGen::MetamodelBuilder::DataTypes::Enum.new(:name => "DataType113", :literals => {:b => 1})

      Module112.extend(RGen::MetamodelBuilder::ModuleExtension)
      # this datatype must be in Module11 not Module112
      DataType114 = RGen::MetamodelBuilder::DataTypes::Enum.new(:name => "DataType114", :literals => {:b => 1})
      module Module112
        # this one is handled because now Module112 is extended
        class Class1122 < RGen::MetamodelBuilder::MMBase
        end
      end

      DataType115 = RGen::MetamodelBuilder::DataTypes::Enum.new(:name => "DataType115", :literals => {:b => 1})
      DataType116 = RGen::MetamodelBuilder::DataTypes::Enum.new(:name => "DataType116", :literals => {:b => 1})
    end

    DataType11 = RGen::MetamodelBuilder::DataTypes::Enum.new(:name => "DataType11", :literals => {:a => 1})

    class Class12 < RGen::MetamodelBuilder::MMBase
    end

    class Class13 < RGen::MetamodelBuilder::MMBase
    end
  end

  # datatypes outside of a module won't be handled
  DataType1 = RGen::MetamodelBuilder::DataTypes::Enum.new(:name => "DataType1", :literals => {:b => 1})

  # classes outside of a module won't be handled
  class Class1 < RGen::MetamodelBuilder::MMBase
  end

  module TestMM2
    extend RGen::MetamodelBuilder::ModuleExtension
  
    TestMM1::Module11.extend(RGen::MetamodelBuilder::ModuleExtension)
    # this is a critical case: because of the previous extension of Module11 which is in a different
    # hierarchy, DataType21 is looked for in Module11 and its parents; finally it is not
    # found and the definition is ignored for order calculation
    DataType21 = RGen::MetamodelBuilder::DataTypes::Enum.new(:name => "DataType21", :literals => {:b => 1})

    module Module21
      extend RGen::MetamodelBuilder::ModuleExtension
    end

    module Module22
      extend RGen::MetamodelBuilder::ModuleExtension
    end

    module Module23
      extend RGen::MetamodelBuilder::ModuleExtension
    end

    # if there is no other class or module after the last datatype, it won't show up in _constantOrder
    # however, the order of eClassifiers can still be reconstructed
    # note that this can not be tested if the test is executed as part of the whole testsuite 
    # since there will be classes and modules created within other test files
    DataType22 = RGen::MetamodelBuilder::DataTypes::Enum.new(:name => "DataType22", :literals => {:b => 1})
  end

  def test_constant_order
    assert_equal ["Class11", "Module11", "DataType11", "Class12", "Class13"], TestMM1._constantOrder
    assert_equal ["DataType111", "DataType112", "Class111", "DataType113", "Module112", "DataType114", "DataType115", "DataType116"], TestMM1::Module11._constantOrder
    assert_equal ["Class1122"], TestMM1::Module11::Module112._constantOrder
    if File.basename($0) == "metamodel_order_test.rb"
      # this won't work if run in the whole test suite (see comment at DataType22)
      assert_equal ["Module21", "Module22", "Module23"], TestMM2._constantOrder
    end
  end

  def test_classifier_order
    # eClassifiers also contains the ones which where ignored in order calculation, these are expected at the end
    # (in an arbitrary order)
    assert_equal ["Class11", "DataType11", "Class12", "Class13"], TestMM1.ecore.eClassifiers.name
    assert_equal ["DataType111", "DataType112", "Class111", "DataType113", "DataType114", "DataType115", "DataType116", "Class112"], TestMM1::Module11.ecore.eClassifiers.name
    assert_equal ["Class1122", "Class1121"], TestMM1::Module11::Module112.ecore.eClassifiers.name
    # no classifiers in TestMM2._constantOrder, so the datatypes can appear in arbitrary order
    assert_equal ["DataType21","DataType22"], TestMM2.ecore.eClassifiers.name.sort
  end

  def test_subpackage_order
    assert_equal ["Module11"], TestMM1.ecore.eSubpackages.name
    assert_equal ["Module112"], TestMM1::Module11.ecore.eSubpackages.name
    assert_equal [], TestMM1::Module11::Module112.ecore.eSubpackages.name
    assert_equal ["Module21", "Module22", "Module23"], TestMM2.ecore.eSubpackages.name
  end
end


