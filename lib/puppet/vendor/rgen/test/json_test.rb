$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/environment'
require 'rgen/metamodel_builder'
require 'rgen/serializer/json_serializer'
require 'rgen/instantiator/json_instantiator'

class JsonTest < Test::Unit::TestCase

  module TestMM
    extend RGen::MetamodelBuilder::ModuleExtension
    class TestNode < RGen::MetamodelBuilder::MMBase
      has_attr 'text', String
      has_attr 'integer', Integer
      has_attr 'float', Float
      has_one 'other', TestNode
      contains_many 'childs', TestNode, 'parent'
    end
  end

  module TestMMData
    extend RGen::MetamodelBuilder::ModuleExtension
    # class "Data" exists in the standard Ruby namespace
    class Data < RGen::MetamodelBuilder::MMBase
      has_attr 'notTheBuiltin', String
    end
  end

  module TestMMSubpackage
    extend RGen::MetamodelBuilder::ModuleExtension
    module SubPackage
      extend RGen::MetamodelBuilder::ModuleExtension
      class Data < RGen::MetamodelBuilder::MMBase
        has_attr 'notTheBuiltin', String
      end
      class Data2 < RGen::MetamodelBuilder::MMBase
        has_attr 'data2', String
      end
    end
  end

  class StringWriter < String
    alias write concat
  end

  def test_json_serializer
    testModel = TestMM::TestNode.new(:text => "some text", :childs => [
      TestMM::TestNode.new(:text => "child")])

    output = StringWriter.new
    ser = RGen::Serializer::JsonSerializer.new(output)

    assert_equal %q({ "_class": "TestNode", "text": "some text", "childs": [ 
  { "_class": "TestNode", "text": "child" }] }), ser.serialize(testModel)
  end

  def test_json_instantiator
    env = RGen::Environment.new
    inst = RGen::Instantiator::JsonInstantiator.new(env, TestMM)
    inst.instantiate(%q({ "_class": "TestNode", "text": "some text", "childs": [ 
  { "_class": "TestNode", "text": "child" }] }))
    root = env.find(:class => TestMM::TestNode, :text => "some text").first
    assert_not_nil root
    assert_equal 1, root.childs.size
    assert_equal TestMM::TestNode, root.childs.first.class
    assert_equal "child", root.childs.first.text
  end

  def test_json_serializer_escapes
    testModel = TestMM::TestNode.new(:text => %Q(some " \\ \\" text \r xx \n xx \r\n xx \t xx \b xx \f))
    output = StringWriter.new
    ser = RGen::Serializer::JsonSerializer.new(output)

    assert_equal %q({ "_class": "TestNode", "text": "some \" \\\\ \\\\\" text \r xx \n xx \r\n xx \t xx \b xx \f" }),
      ser.serialize(testModel) 
  end
   
  def test_json_instantiator_escapes
    env = RGen::Environment.new
    inst = RGen::Instantiator::JsonInstantiator.new(env, TestMM)
    inst.instantiate(%q({ "_class": "TestNode", "text": "some \" \\\\ \\\\\" text \r xx \n xx \r\n xx \t xx \b xx \f" }))
    assert_equal %Q(some " \\ \\" text \r xx \n xx \r\n xx \t xx \b xx \f), env.elements.first.text
  end

  def test_json_instantiator_escape_single_backslash
    env = RGen::Environment.new
    inst = RGen::Instantiator::JsonInstantiator.new(env, TestMM)
    inst.instantiate(%q({ "_class": "TestNode", "text": "a single \\ will be just itself" }))
    assert_equal %q(a single \\ will be just itself), env.elements.first.text
  end

  def test_json_serializer_integer
    testModel = TestMM::TestNode.new(:integer => 7)
    output = StringWriter.new
    ser = RGen::Serializer::JsonSerializer.new(output)
    assert_equal %q({ "_class": "TestNode", "integer": 7 }), ser.serialize(testModel) 
  end

  def test_json_instantiator_integer
    env = RGen::Environment.new
    inst = RGen::Instantiator::JsonInstantiator.new(env, TestMM)
    inst.instantiate(%q({ "_class": "TestNode", "integer": 7 }))
    assert_equal 7, env.elements.first.integer
  end

  def test_json_serializer_float
    testModel = TestMM::TestNode.new(:float => 1.23)
    output = StringWriter.new
    ser = RGen::Serializer::JsonSerializer.new(output)
    assert_equal %q({ "_class": "TestNode", "float": 1.23 }), ser.serialize(testModel) 
  end

  def test_json_instantiator_float
    env = RGen::Environment.new
    inst = RGen::Instantiator::JsonInstantiator.new(env, TestMM)
    inst.instantiate(%q({ "_class": "TestNode", "float": 1.23 }))
    assert_equal 1.23, env.elements.first.float
  end

  def test_json_instantiator_conflict_builtin
    env = RGen::Environment.new
    inst = RGen::Instantiator::JsonInstantiator.new(env, TestMMData)
    inst.instantiate(%q({ "_class": "Data", "notTheBuiltin": "for sure" }))
    assert_equal "for sure", env.elements.first.notTheBuiltin
  end

  def test_json_serializer_subpacakge
    testModel = TestMMSubpackage::SubPackage::Data2.new(:data2 => "xxx")
    output = StringWriter.new
    ser = RGen::Serializer::JsonSerializer.new(output)
    assert_equal %q({ "_class": "Data2", "data2": "xxx" }), ser.serialize(testModel) 
  end

  def test_json_instantiator_builtin_in_subpackage
    env = RGen::Environment.new
    inst = RGen::Instantiator::JsonInstantiator.new(env, TestMMSubpackage)
    inst.instantiate(%q({ "_class": "Data", "notTheBuiltin": "for sure" }))
    assert_equal "for sure", env.elements.first.notTheBuiltin
  end

  def test_json_instantiator_subpackage
    env = RGen::Environment.new
    inst = RGen::Instantiator::JsonInstantiator.new(env, TestMMSubpackage)
    inst.instantiate(%q({ "_class": "Data2", "data2": "something" }))
    assert_equal "something", env.elements.first.data2
  end

  def test_json_instantiator_subpackage_no_shortname_opt
    env = RGen::Environment.new
    inst = RGen::Instantiator::JsonInstantiator.new(env, TestMMSubpackage, :short_class_names => false)
    assert_raise RuntimeError do
      inst.instantiate(%q({ "_class": "Data2", "data2": "something" }))
    end
  end

  def test_json_instantiator_references
    env = RGen::Environment.new
    inst = RGen::Instantiator::JsonInstantiator.new(env, TestMM, :nameAttribute => "text")
    inst.instantiate(%q([
    { "_class": "TestNode", "text": "A", "childs": [ 
      { "_class": "TestNode", "text": "B" } ]},
    { "_class": "TestNode", "text": "C", "other": "/A/B"}]
    ))
    nodeA = env.find(:class => TestMM::TestNode, :text => "A").first
    nodeC = env.find(:class => TestMM::TestNode, :text => "C").first
    assert_equal 1, nodeA.childs.size
    assert_equal nodeA.childs[0], nodeC.other 
  end
end
	
