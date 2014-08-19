$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/environment'
require 'metamodels/uml13_metamodel'
require 'ea_support/ea_support'
require 'transformers/uml13_to_ecore'
require 'testmodel/class_model_checker'
require 'testmodel/object_model_checker'
require 'testmodel/ecore_model_checker'

class EAInstantiatorTest < Test::Unit::TestCase

    include Testmodel::ClassModelChecker
    include Testmodel::ObjectModelChecker
    include Testmodel::ECoreModelChecker
    
	MODEL_DIR = File.join(File.dirname(__FILE__),"testmodel")
		
	def test_instantiator
		envUML = RGen::Environment.new
    EASupport.instantiateUML13FromXMI11(envUML, MODEL_DIR+"/ea_testmodel.xml") 
    checkClassModel(envUML)
    checkObjectModel(envUML)
    envECore = RGen::Environment.new
    UML13ToECore.new(envUML, envECore).transform
    checkECoreModel(envECore)
	end
	
	def test_partial
		envUML = RGen::Environment.new
    EASupport.instantiateUML13FromXMI11(envUML, MODEL_DIR+"/ea_testmodel_partial.xml") 
		checkClassModelPartial(envUML)
	end
end