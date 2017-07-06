require 'rgen/transformer'
require 'rgen/ecore/ecore'
require 'rgen/array_extensions'
require 'xml_instantiator_test/simple_xmi_metamodel'

class SimpleXmiToECore < RGen::Transformer
  include RGen::ECore
  
  class MapHelper
    def initialize(keyMethod,valueMethod,elements)
      @keyMethod, @valueMethod, @elements = keyMethod, valueMethod, elements
    end
    def [](key)
      return @elements.select{|e| e.send(@keyMethod) == key}.first.send(@valueMethod) rescue NoMethodError
    nil
    end
  end
  
  class TaggedValueHelper < MapHelper
    def initialize(element)	
      super('tag','value',element.modelElement_taggedValue.taggedValue)
    end
  end  
  
  # Do the actual transformation.
  # Input and output environment have to be provided to the transformer constructor.
  def transform
    trans(:class => SimpleXMIMetaModel::UML::Clazz)
  end
  
  transform SimpleXMIMetaModel::UML::Package, :to => EPackage do
    { :name => name, 
      :eSuperPackage => trans(parent.parent.is_a?(SimpleXMIMetaModel::UML::Package) ? parent.parent : nil) }
  end
  
  transform SimpleXMIMetaModel::UML::Clazz, :to => EClass do
    { :name => name,
      :ePackage => trans(parent.parent.is_a?(SimpleXMIMetaModel::UML::Package) ? parent.parent : nil),
      :eStructuralFeatures => trans(classifier_feature.attribute + associationEnds),
      :eOperations => trans(classifier_feature.operation),
      :eSuperTypes =>  trans(generalizationsAsSubtype.supertypeClass),
      :eAnnotations => [ EAnnotation.new(:details => trans(modelElement_taggedValue.taggedValue)) ] }
  end
  
  transform SimpleXMIMetaModel::UML::TaggedValue, :to => EStringToStringMapEntry do
    { :key => tag, :value => value}
  end
  
  transform SimpleXMIMetaModel::UML::Attribute, :to => EAttribute do
    typemap = { "String" => EString, "boolean" => EBoolean, "int" => EInt, "long" => ELong, "float" => EFloat }
    tv = TaggedValueHelper.new(@current_object)
    {	:name => name, :eType => typemap[tv['type']],
      :eAnnotations => [ EAnnotation.new(:details => trans(modelElement_taggedValue.taggedValue)) ] }
  end
  
  transform SimpleXMIMetaModel::UML::Operation, :to => EOperation do
    { :name => name }
  end
  
  transform SimpleXMIMetaModel::UML::AssociationEnd, :to => EReference, :if => :isReference do
    { :eType => trans(otherEnd.typeClass),
      :name => otherEnd.name,
      :eOpposite => trans(otherEnd),
      :lowerBound => (otherEnd.multiplicity || '0').split('..').first.to_i,
      :upperBound => (otherEnd.multiplicity || '1').split('..').last.gsub('*','-1').to_i,
      :containment => (aggregation == 'composite'),
      :eAnnotations => [ EAnnotation.new(:details => trans(modelElement_taggedValue.taggedValue)) ] }
  end
  
  method :isReference do
    otherEnd.isNavigable == 'true' || 
    # composite assocations are bidirectional
    aggregation == 'composite' || otherEnd.aggregation == 'composite'
  end			
end
