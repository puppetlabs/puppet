require 'rgen/transformer'
require 'rgen/ecore/ecore'
require 'metamodels/uml13_metamodel'

class ECoreToUML13 < RGen::Transformer
  include RGen::ECore
  
  def transform
    trans(:class => EPackage)
    trans(:class => EClass)
    trans(:class => EEnum)
  end

  transform EPackage, :to => UML13::Package do
    {:name => name,
      :namespace => trans(eSuperPackage) || model,
      :ownedElement => trans(eClassifiers.select{|c| c.is_a?(EClass)} + eSubpackages)
    }
  end
  
  transform EClass, :to => UML13::Class do
    {:name => name,
      :namespace => trans(ePackage),
      :feature => trans(eStructuralFeatures.select{|f| f.is_a?(EAttribute)} + eOperations),
      :associationEnd => trans(eStructuralFeatures.select{|f| f.is_a?(EReference)}),
      :generalization => eSuperTypes.collect { |st| 
        @env_out.new(UML13::Generalization, :parent => trans(st), :namespace => trans(ePackage) || model)
      }
    }
  end
  
  transform EEnum, :to => UML13::Class do
    {:name => name,
      :namespace => trans(ePackage),
      :feature => trans(eLiterals)
    }
  end

  transform EEnumLiteral, :to => UML13::Attribute do
    {:name => name }
  end

  transform EAttribute, :to => UML13::Attribute do
    _typemap = {"String" => "string", "Boolean" => "boolean", "Integer" => "int", "Float" => "float"}
    {:name => name, 
     :taggedValue => [@env_out.new(UML13::TaggedValue, :tag => "type", 
       :value => _typemap[eType.instanceClassName] || eType.name)] 
    }
  end
  
  transform EReference, :to => UML13::AssociationEnd do
    _otherAssocEnd = eOpposite ? trans(eOpposite) : 
      @env_out.new(UML13::AssociationEnd, 
        :type => trans(eType), :name => name, :multiplicity => createMultiplicity(@current_object), 
        :aggregation => :none, :isNavigable => true)
    { :association => trans(@current_object).association || @env_out.new(UML13::Association, 
        :connection => [_otherAssocEnd], :namespace => trans(eContainingClass.ePackage) || model),
      :name => eOpposite && eOpposite.name,
      :multiplicity => eOpposite && createMultiplicity(eOpposite),
      :aggregation => containment ? :composite : :none,
      :isNavigable => !eOpposite.nil?
    }
  end
  
  transform EOperation, :to => UML13::Operation do 
    {:name => name}
  end
  
  def createMultiplicity(ref)
    @env_out.new(UML13::Multiplicity, :range => [
      @env_out.new(UML13::MultiplicityRange, 
        :lower => ref.lowerBound.to_s.sub("-1","*"), :upper => ref.upperBound.to_s.sub("-1","*"))])    
  end
  
  def model
    @model ||= @env_out.new(UML13::Model, :name => "Model")
  end
  
end
