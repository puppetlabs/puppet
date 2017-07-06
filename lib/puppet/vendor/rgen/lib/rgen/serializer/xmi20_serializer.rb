require 'rgen/serializer/xml_serializer'

module RGen

module Serializer

class XMI20Serializer < XMLSerializer

	def serialize(rootElement)
		@referenceStrings = {}
		buildReferenceStrings(rootElement, "#/")
    addBuiltinReferenceStrings
		attrs = attributeValues(rootElement)
		attrs << ['xmi:version', "2.0"]
		attrs << ['xmlns:xmi', "http://www.omg.org/XMI"]
		attrs << ['xmlns:xsi', "http://www.w3.org/2001/XMLSchema-instance"]
		attrs << ['xmlns:ecore', "http://www.eclipse.org/emf/2002/Ecore" ]
		tag = "ecore:"+rootElement.class.ecore.name
		startTag(tag, attrs)
		writeComposites(rootElement)
		endTag(tag)
	end
	
	def writeComposites(element)
		eachReferencedElement(element, containmentReferences(element)) do |r,te|
			attrs = attributeValues(te)
			attrs << ['xsi:type', "ecore:"+te.class.ecore.name]
			tag = r.name
			startTag(tag, attrs)
			writeComposites(te)
			endTag(tag)
		end
	end

	def attributeValues(element)
		result = [] 
		eAllAttributes(element).select{|a| !a.derived}.each do |a|
			val = element.getGeneric(a.name)
			result << [a.name, val] unless val.nil? || val == ""
		end
		eAllReferences(element).select{|r| !r.containment && !(r.eOpposite && r.eOpposite.containment) && !r.derived}.each do |r|
			targetElements = element.getGenericAsArray(r.name)
			val = targetElements.collect{|te| @referenceStrings[te]}.compact.join(' ')
			result << [r.name, val] unless val.nil? || val == ""
		end
		result	
	end
	
	def buildReferenceStrings(element, string)
		@referenceStrings[element] = string
		eachReferencedElement(element, containmentReferences(element)) do |r,te|
			buildReferenceStrings(te, string+"/"+te.name) if te.respond_to?(:name)
		end
	end

  def addBuiltinReferenceStrings
    pre = "ecore:EDataType http://www.eclipse.org/emf/2002/Ecore"
    @referenceStrings[RGen::ECore::EString] = pre+"#//EString"
    @referenceStrings[RGen::ECore::EInt] = pre+"#//EInt"
    @referenceStrings[RGen::ECore::ELong] = pre+"#//ELong"
    @referenceStrings[RGen::ECore::EFloat] = pre+"#//EFloat"
    @referenceStrings[RGen::ECore::EBoolean] = pre+"#//EBoolean"
    @referenceStrings[RGen::ECore::EJavaObject] = pre+"#//EJavaObject"
    @referenceStrings[RGen::ECore::EJavaClass] = pre+"#//EJavaClass"
  end

end

end

end
