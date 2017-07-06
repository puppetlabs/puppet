require 'rgen/util/name_helper'

module RGen
  
  module ECore
    
    module EPackage::ClassModule
      include RGen::Util::NameHelper
      
      def moduleName
        firstToUpper(name)
      end
      
      def qualifiedModuleName(rootPackage)
        return moduleName unless eSuperPackage and self != rootPackage
        eSuperPackage.qualifiedModuleName(rootPackage) + "::" + moduleName
      end
      
      def ancestorPackages
        return [] unless eSuperPackage
        [eSuperPackage] + eSuperPackage.ancestorPackages
      end
      
      def ownClasses
        eClassifiers.select{|c| c.is_a?(EClass)}
      end
      
      def classesInGenerationOrdering
        ownClasses + eSubpackages.collect{|s| s.classesInGenerationOrdering}.flatten
      end
      
      def needClassReorder?
        classesInGenerationOrdering != inheritanceOrderClasses(classesInGenerationOrdering)
      end
      
      def allClassesSorted
        inheritanceOrderClasses(classesInGenerationOrdering)
      end
      
      def inheritanceOrderClasses(cls)
        sortArray = cls.dup
        i1 = 0
        while i1 < sortArray.size-1
          again = false
          for i2 in i1+1..sortArray.size-1
            e2 = sortArray[i2]
            if sortArray[i1].eSuperTypes.include?(e2)
              sortArray.delete(e2)
              sortArray.insert(i1,e2)
              again = true
              break
            end
          end
          i1 += 1 unless again
        end
        sortArray
      end
    end
    
    module EClassifier::ClassModule
      include RGen::Util::NameHelper
      def classifierName
        firstToUpper(name)			
      end
      def qualifiedClassifierName(rootPackage)
       (ePackage ? ePackage.qualifiedModuleName(rootPackage) + "::" : "") + classifierName
      end
      def ancestorPackages
        return [] unless ePackage
        [ePackage] + ePackage.ancestorPackages
      end
      def qualifiedClassifierNameIfRequired(package)
        if ePackage != package
          commonSuper = (package.ancestorPackages & ancestorPackages).first
          qualifiedClassifierName(commonSuper)
        else
          classifierName
        end
      end
    end
    
    module EAttribute::ClassModule
      def RubyType
        typeMap = {'float' => 'Float', 'int' => 'Integer'}
         (self.getType && typeMap[self.getType.downcase]) || 'String'
      end
    end
    
  end
  
end
