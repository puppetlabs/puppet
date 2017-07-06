require 'rgen/array_extensions'
require 'rgen/ecore/ecore'

module RGen
  module ECore
  	
    # make super type reference bidirectional
    EClass.many_to_many 'eSuperTypes', ECore::EClass, 'eSubTypes'
    
	  module EModelElement::ClassModule
	    
	    def annotationValue(source, tag)
  			detail = eAnnotations.select{ |a| a.source == source }.details.find{ |d| d.key == tag }
			  detail && detail.value
  		end
      
  	end
		
  	module EPackage::ClassModule
  	  
			def qualifiedName
				if eSuperPackage
					eSuperPackage.qualifiedName+"::"+name
				else
					name
				end
			end
      
  		def eAllClassifiers
  			eClassifiers + eSubpackages.eAllClassifiers
  		end
      def eAllSubpackages
        eSubpackages + eSubpackages.eAllSubpackages
      end
      
      def eClasses
        eClassifiers.select{|c| c.is_a?(ECore::EClass)}
      end
      
      def eAllClasses
        eClasses + eSubpackages.eAllClasses
      end
      
      def eDataTypes
        eClassifiers.select{|c| c.is_a?(ECore::EDataType)}
      end
      
      def eAllDataTypes
        eDataTypes + eSubpackages.eAllDataTypes
      end      
  	end
		
		module EClass::ClassModule
		  
			def qualifiedName
				if ePackage
					ePackage.qualifiedName+"::"+name
				else
					name
				end
			end
      
      def eAllSubTypes
        eSubTypes + eSubTypes.eAllSubTypes
      end
      
		end
  end
end
