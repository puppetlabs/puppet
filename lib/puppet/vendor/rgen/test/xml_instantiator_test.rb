$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/instantiator/default_xml_instantiator'
require 'rgen/environment'
require 'rgen/util/model_dumper'
require 'xml_instantiator_test/simple_xmi_ecore_instantiator'
require 'xml_instantiator_test/simple_ecore_model_checker'

module EmptyMM
end

module DefaultMM
  module MNS
    class Room < RGen::MetamodelBuilder::MMBase; end
  end
  class Person < RGen::MetamodelBuilder::MMBase; end
  Person.one_to_one 'personalRoom', MNS::Room, 'inhabitant'
end

class XMLInstantiatorTest < Test::Unit::TestCase

  XML_DIR = File.join(File.dirname(__FILE__),"testmodel")
  
  include RGen::Util::ModelDumper
  
  class MyInstantiator < RGen::Instantiator::DefaultXMLInstantiator
  
    map_tag_ns "testmodel.org/myNamespace", DefaultMM::MNS
    
    def class_name(str)
      camelize(str)
    end
    
#    resolve :type do
#      @env.find(:xmi_id => getType).first
#    end
  
    resolve_by_id :personalRoom, :id => :getId, :src => :room
    
  end
  
  class PruneTestInstantiator < RGen::Instantiator::NodebasedXMLInstantiator
    attr_reader :max_depth
    
    set_prune_level 2
    
    def initialize(env)
      super(env)
      @max_depth = 0
    end
    
    def on_descent(node)
    end
    
    def on_ascent(node)
      calc_max_depth(node, 0)
    end
    
    def calc_max_depth(node, offset)
      if node.children.nil? || node.children.size == 0
        @max_depth = offset if offset > @max_depth
      else 
        node.children.each do |c|
          calc_max_depth(c, offset+1)
        end
      end
    end
  end
  
  module PruneTestMM
  end
  
  def test_pruning
    env = RGen::Environment.new
    
    # prune level 2 is set in the class body
    inst = PruneTestInstantiator.new(env)
    inst.instantiate_file(File.join(XML_DIR,"manual_testmodel.xml"))
    assert_equal 2, inst.max_depth
    
    PruneTestInstantiator.set_prune_level(0)
    inst = PruneTestInstantiator.new(env)
    inst.instantiate_file(File.join(XML_DIR,"manual_testmodel.xml"))
    assert_equal 5, inst.max_depth
    
    PruneTestInstantiator.set_prune_level(1)
    inst = PruneTestInstantiator.new(env)
    inst.instantiate_file(File.join(XML_DIR,"manual_testmodel.xml"))
    assert_equal 1, inst.max_depth
  end
  
  def test_custom
    env = RGen::Environment.new
    inst = MyInstantiator.new(env, DefaultMM, true)
    inst.instantiate_file(File.join(XML_DIR,"manual_testmodel.xml"))
    
    house = env.find(:class => DefaultMM::MNS::House).first
    assert_not_nil house
    assert_equal 2, house.room.size
    
    rooms = env.find(:class => DefaultMM::MNS::Room)
    assert_equal 2, rooms.size
    assert_equal 0, (house.room - rooms).size
    rooms.each {|r| assert r.parent == house}
    tomsRoom = rooms.select{|r| r.name == "TomsRoom"}.first
    assert_not_nil tomsRoom
    
    persons = env.find(:class => DefaultMM::Person)
    assert_equal 4, persons.size
    tom = persons.select{|p| p.name == "Tom"}.first
    assert_not_nil tom
    
    assert tom.personalRoom == tomsRoom
    
    mpns = env.find(:class => DefaultMM::MultiPartName)
    assert mpns.first.respond_to?("insideMultiPart")
  end
  
  def test_default
    env = RGen::Environment.new
    inst = RGen::Instantiator::DefaultXMLInstantiator.new(env, EmptyMM, true)
    inst.instantiate_file(File.join(XML_DIR,"manual_testmodel.xml"))
    
    house = env.find(:class => EmptyMM::MNS_House).first
    assert_not_nil house
    assert_equal 2, house.mNS_Room.size
    assert_equal "before kitchen", remove_whitespace_elements(house.chardata)[0].strip
    assert_equal "after kitchen", remove_whitespace_elements(house.chardata)[1].strip
    assert_equal "after toms room", remove_whitespace_elements(house.chardata)[2].strip
    
    rooms = env.find(:class => EmptyMM::MNS_Room)
    assert_equal 2, rooms.size
    assert_equal 0, (house.mNS_Room - rooms).size
    rooms.each {|r| assert r.parent == house}
    tomsRoom = rooms.select{|r| r.name == "TomsRoom"}.first
    assert_not_nil tomsRoom
    assert_equal "within toms room", remove_whitespace_elements(tomsRoom.chardata)[0]
    
    persons = env.find(:class => EmptyMM::Person)
    assert_equal 4, persons.size
    tom = persons.select{|p| p.name == "Tom"}.first
    assert_not_nil tom
  end

  def remove_whitespace_elements(elements)
    elements.reject{|e| e.strip == ""} 
  end

  include SimpleECoreModelChecker
  
  def test_simle_xmi_ecore_instantiator
    envECore = RGen::Environment.new
    File.open(XML_DIR+"/ea_testmodel.xml") { |f|
      SimpleXMIECoreInstantiator.new.instantiateECoreModel(envECore, f.read)
    }
    checkECoreModel(envECore)
  end
    
end
