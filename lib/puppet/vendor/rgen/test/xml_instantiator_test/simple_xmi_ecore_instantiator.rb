require 'rgen/instantiator/default_xml_instantiator'
require 'rgen/environment'
require 'rgen/ecore/ecore'
require 'xml_instantiator_test/simple_xmi_metamodel'

# SimpleXMIECoreInstantiator demonstrates the usage of the DefaultXMLInstantiator.
# It can be used to instantiate an ECore model from an XMI description
# produced by Enterprise Architect.
# 
# Note however, that this is *not* the recommended way to read an EA model.
# See EAInstantiatorTest for the clean way to do this.
# 
# This example shows how arbitrary XML content can be used to instantiate
# an implicit metamodel. The resulting model is transformed into a simple
# ECore model.
# 
# See XMLInstantiatorTest for an example of how to use this class.
# 
class SimpleXMIECoreInstantiator < RGen::Instantiator::DefaultXMLInstantiator
  
  map_tag_ns "omg.org/UML1.3", SimpleXMIMetaModel::UML
  
  resolve_by_id :typeClass, :src => :type, :id => :xmi_id
  resolve_by_id :subtypeClass, :src => :subtype, :id => :xmi_id
  resolve_by_id :supertypeClass, :src => :supertype, :id => :xmi_id
  
  def initialize
    @envXMI = RGen::Environment.new 
    super(@envXMI, SimpleXMIMetaModel, true)
  end
  
  def new_object(node)
    if node.tag == "EAStub"
      class_name = saneClassName(node.attributes["UMLType"])
      mod = XMIMetaModel::UML
      build_on_error(NameError, :build_class, class_name, mod) do
        mod.const_get(class_name).new
      end	 
    else
      super
    end
  end	
  
  # This method does the actual work.
  def instantiateECoreModel(envOut, str)
    instantiate(str)
    
    require 'xml_instantiator_test/simple_xmi_to_ecore'
    
    SimpleXmiToECore.new(@envXMI,envOut).transform
  end
  
end
