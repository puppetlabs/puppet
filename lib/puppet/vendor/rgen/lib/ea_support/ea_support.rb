require 'ea_support/uml13_ea_metamodel'
require 'ea_support/uml13_ea_metamodel_ext'
require 'ea_support/uml13_to_uml13_ea'
require 'ea_support/uml13_ea_to_uml13'
require 'ea_support/id_store'
require 'rgen/serializer/xmi11_serializer'
require 'rgen/instantiator/xmi11_instantiator'
require 'rgen/environment'

module EASupport
  
  FIXMAP = {
    :tags => {
      "EAStub" => proc { |tag, attr| 
        UML13EA::Class.new(:name => attr["name"]) if attr["UMLType"] == "Class"
      }
    }
  }
  
  INFO = XMI11Instantiator::INFO
  WARN = XMI11Instantiator::WARN
  ERROR = XMI11Instantiator::ERROR
  
  def self.instantiateUML13FromXMI11(envUML, fileName, options={})
    envUMLEA = RGen::Environment.new
    xmiInst = XMI11Instantiator.new(envUMLEA, FIXMAP, options[:loglevel] || ERROR)
    xmiInst.add_metamodel("omg.org/UML1.3", UML13EA)
    File.open(fileName) do |f|
      xmiInst.instantiate(f.read)
    end
    trans = UML13EAToUML13.new(envUMLEA, envUML)
    trans.transform
    trans.cleanModel if options[:clean_model]
  end

  def self.serializeUML13ToXMI11(envUML, fileName, options={})
    envUMLEA = RGen::Environment.new
    
    UML13EA.idStore = options[:keep_ids] ? 
      IdStore.new(File.dirname(fileName)+"/"+File.basename(fileName)+".ids") : IdStore.new
    
    UML13ToUML13EA.new(envUML, envUMLEA).transform
    
    File.open(fileName, "w") do |f|
      xmiSer = RGen::Serializer::XMI11Serializer.new(f)
      xmiSer.setNamespace("UML","omg.org/UML1.3")
      xmiSer.serialize(envUMLEA.find(:class => UML13EA::Model).first, 
        {:documentation => {:exporter => "Enterprise Architect", :exporterVersion => "2.5"}})
    end
    
    UML13EA.idStore.store
  end
  
end