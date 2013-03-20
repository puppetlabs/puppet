$:.unshift File.dirname(__FILE__) + "/../lib"

require 'test/unit'
require 'rgen/ecore/ecore'
require 'rgen/ecore/ecore_builder_methods'
require 'rgen/environment'
require 'rgen/model_builder'
require 'model_builder/statemachine_metamodel'

class ModelBuilderTest < Test::Unit::TestCase
      
  def test_statemachine
    result = RGen::ModelBuilder.build(StatemachineMetamodel) do 
      statemachine "Airconditioner" do
        state "Off", :kind => :START
        compositeState "On" do
          state "Heating" do
            transition :as => :outgoingTransition, :targetState => "Cooling",
              :statemachine => "Airconditioner"
          end
          state "Cooling" do
          end
        end
        transition :sourceState => "On.Cooling", :targetState => "On.Heating" do
          _using Condition::TimeCondition do
            timeCondition :as => :condition, :timeout => 100
          end
          Condition::TimeCondition.timeCondition :as => :condition, :timeout => 10
        end
      end
      _using Condition do
        statemachine "AirconExtension" do
          s = state "StartState"
          transition :sourceState => s, :targetState => "Airconditioner.Off"
        end
      end
    end
    
    assert result.is_a?(Array)
    assert_equal 2, result.size
    
    sm1 = result[0]
    assert sm1.is_a?(StatemachineMetamodel::Statemachine)
    assert_equal "Airconditioner", sm1.name
    
    assert_equal 2, sm1.state.size
    offState = sm1.state[0]
    assert offState.is_a?(StatemachineMetamodel::State)
    assert_equal "Off", offState.name
    assert_equal :START, offState.kind
    
    onState = sm1.state[1]
    assert onState.is_a?(StatemachineMetamodel::CompositeState)
    assert_equal "On", onState.name
    
    assert_equal 2, onState.state.size
    hState = onState.state[0]
    assert hState.is_a?(StatemachineMetamodel::State)
    assert_equal "Heating", hState.name
    
    cState = onState.state[1]
    assert cState.is_a?(StatemachineMetamodel::State)
    assert_equal "Cooling", cState.name
    
    assert_equal 1, hState.outgoingTransition.size
    hOutTrans = hState.outgoingTransition[0]
    assert hOutTrans.is_a?(StatemachineMetamodel::Transition)
    assert_equal cState, hOutTrans.targetState
    assert_equal sm1, hOutTrans.statemachine
    
    assert_equal 1, hState.incomingTransition.size
    hInTrans = hState.incomingTransition[0]
    assert hInTrans.is_a?(StatemachineMetamodel::Transition)
    assert_equal cState, hInTrans.sourceState
    assert_equal sm1, hInTrans.statemachine
    
    assert_equal 2, hInTrans.condition.size
    assert hInTrans.condition[0].is_a?(StatemachineMetamodel::Condition::TimeCondition::TimeCondition)
    assert_equal 100, hInTrans.condition[0].timeout
    assert hInTrans.condition[1].is_a?(StatemachineMetamodel::Condition::TimeCondition::TimeCondition)
    assert_equal 10, hInTrans.condition[1].timeout
    
    sm2 = result[1]
    assert sm2.is_a?(StatemachineMetamodel::Statemachine)
    assert_equal "AirconExtension", sm2.name
    
    assert_equal 1, sm2.state.size
    sState = sm2.state[0]
    assert sState.is_a?(StatemachineMetamodel::State)
    assert_equal "StartState", sState.name
    
    assert_equal 1, sState.outgoingTransition.size
    assert sState.outgoingTransition[0].is_a?(StatemachineMetamodel::Transition)
    assert_equal offState, sState.outgoingTransition[0].targetState
    assert_equal sm2, sState.outgoingTransition[0].statemachine
  end
  
  def test_dynamic
    numStates = 5
    env = RGen::Environment.new
    result = RGen::ModelBuilder.build(StatemachineMetamodel, env) do
      sm = statemachine "SM#{numStates}" do
        (1..numStates).each do |i|
          state "State#{i}" do
            transition :as => :outgoingTransition, :targetState => "State#{i < numStates ? i+1 : 1}",
              :statemachine => sm
          end
        end
      end
    end
    assert_equal 11, env.elements.size
    assert_equal "SM5", result[0].name
    state = result[0].state.first
    assert_equal "State1", state.name
    state = state.outgoingTransition.first.targetState
    assert_equal "State2", state.name
    state = state.outgoingTransition.first.targetState
    assert_equal "State3", state.name
    state = state.outgoingTransition.first.targetState
    assert_equal "State4", state.name
    state = state.outgoingTransition.first.targetState
    assert_equal "State5", state.name
    assert_equal result[0].state[0], state.outgoingTransition.first.targetState
  end
  
  def test_multiref
    result = RGen::ModelBuilder.build(StatemachineMetamodel) do
      a = transition
      transition "b"
      transition "c"
      state :outgoingTransition => [a, "b", "c"]
    end    
    
    assert result[0].is_a?(StatemachineMetamodel::Transition)
    assert result[1].is_a?(StatemachineMetamodel::Transition)
    assert !result[1].respond_to?(:name)
    assert result[2].is_a?(StatemachineMetamodel::Transition)
    assert !result[2].respond_to?(:name)
    state = result[3]
    assert state.is_a?(StatemachineMetamodel::State)
    assert_equal result[0], state.outgoingTransition[0]
    assert_equal result[1], state.outgoingTransition[1]
    assert_equal result[2], state.outgoingTransition[2]
  end
  
  module TestMetamodel
    extend RGen::MetamodelBuilder::ModuleExtension
    
    # these classes have no name
    class TestA < RGen::MetamodelBuilder::MMBase
    end
    class TestB < RGen::MetamodelBuilder::MMBase
    end
    class TestC < RGen::MetamodelBuilder::MMBase
    end
    TestA.contains_many 'testB', TestB, 'testA'
    TestC.has_one 'testB', TestB
  end
  
  def test_helper_names
    result = RGen::ModelBuilder.build(TestMetamodel) do
      testA "_a" do
        testB "_b"
      end
      testC :testB => "_a._b"
    end
    assert result[0].is_a?(TestMetamodel::TestA)
    assert result[1].is_a?(TestMetamodel::TestC)
    assert_equal result[0].testB[0], result[1].testB
  end
    
  def test_ecore
    result = RGen::ModelBuilder.build(RGen::ECore, nil, RGen::ECore::ECoreBuilderMethods) do
      ePackage "TestPackage1" do
        eClass "TestClass1" do
          eAttribute "attr1", :eType => RGen::ECore::EString
          eAttr "attr2", RGen::ECore::EInt
          eBiRef "biRef1", "TestClass2", "testClass1"
          contains_1toN 'testClass2', "TestClass2", "tc1Parent"
        end
        eClass "TestClass2" do
          eRef "ref1", "TestClass1"
        end
      end
    end
    
    assert result.is_a?(Array)
    assert_equal 1, result.size
    p1 = result.first
    
    assert p1.is_a?(RGen::ECore::EPackage)
    assert_equal "TestPackage1", p1.name
    
    # TestClass1
    class1 = p1.eClassifiers.find{|c| c.name == "TestClass1"}
    assert_not_nil class1
    assert class1.is_a?(RGen::ECore::EClass)
    
    # TestClass1.attr1
    attr1 = class1.eAllAttributes.find{|a| a.name == "attr1"}
    assert_not_nil attr1
    assert_equal RGen::ECore::EString, attr1.eType
    
    # TestClass1.attr2
    attr2 = class1.eAllAttributes.find{|a| a.name == "attr2"}
    assert_not_nil attr2
    assert_equal RGen::ECore::EInt, attr2.eType
    
    # TestClass2
    class2 = p1.eClassifiers.find{|c| c.name == "TestClass2"}
    assert_not_nil class2
    assert class2.is_a?(RGen::ECore::EClass)

    # TestClass2.ref1
    ref1 = class2.eAllReferences.find{|a| a.name == "ref1"}
    assert_not_nil ref1
    assert_equal class1, ref1.eType

    # TestClass1.biRef1
    biRef1 = class1.eAllReferences.find{|r| r.name == "biRef1"}
    assert_not_nil biRef1
    assert_equal class2, biRef1.eType
    biRef1Opp = class2.eAllReferences.find {|r| r.name == "testClass1"}
    assert_not_nil biRef1Opp
    assert_equal class1, biRef1Opp.eType
    assert_equal biRef1Opp, biRef1.eOpposite
    assert_equal biRef1, biRef1Opp.eOpposite
    
    # TestClass1.testClass2
    tc2Ref = class1.eAllReferences.find{|r| r.name == "testClass2"}
    assert_not_nil tc2Ref
    assert_equal class2, tc2Ref.eType
    assert  tc2Ref.containment
    assert_equal -1, tc2Ref.upperBound
    tc2RefOpp = class2.eAllReferences.find{|r| r.name == "tc1Parent"}
    assert_not_nil tc2RefOpp
    assert_equal class1, tc2RefOpp.eType
    assert !tc2RefOpp.containment
    assert_equal 1, tc2RefOpp.upperBound
  end
  
end