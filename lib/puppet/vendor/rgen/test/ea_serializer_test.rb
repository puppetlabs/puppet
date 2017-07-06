$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/environment'
require 'metamodels/uml13_metamodel'
require 'ea_support/ea_support'
require 'rgen/serializer/xmi11_serializer'

class EASerializerTest < Test::Unit::TestCase

	MODEL_DIR = File.join(File.dirname(__FILE__),"testmodel")
	TEST_DIR = File.join(File.dirname(__FILE__),"ea_serializer_test")
  
	def test_serializer
		envUML = RGen::Environment.new
    EASupport.instantiateUML13FromXMI11(envUML, MODEL_DIR+"/ea_testmodel.xml") 
    models = envUML.find(:class => UML13::Model)
    assert_equal 1, models.size
    
    EASupport.serializeUML13ToXMI11(envUML, MODEL_DIR+"/ea_testmodel_regenerated.xml") 
	end
	
end