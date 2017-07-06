require 'rgen/transformer'
require 'rgen/ecore/ecore'

module RGen
  
module ECore
  
# This transformer creates an ECore model from Ruby classes built
# by RGen::MetamodelBuilder.
# 
class RubyToECore < Transformer
  
  transform Class, :to => EClass, :if => :convert? do
    { :name => name.gsub(/.*::(\w+)$/,'\1'),
      :abstract => _abstract_class,
      :interface => false,
      :eStructuralFeatures => trans(_metamodel_description),
      :ePackage =>  trans(name =~ /(.*)::\w+$/ ? eval($1) : nil),
      :eSuperTypes => trans(superclasses),
      :instanceClassName => name,
      :eAnnotations => trans(_annotations)
    }
  end
  
  method :superclasses do
    if superclass.respond_to?(:multiple_superclasses) && superclass.multiple_superclasses
      superclass.multiple_superclasses
    else
      [ superclass ]
    end
  end
  
  transform Module, :to => EPackage, :if => :convert?  do
    @enumParentModule ||= {}
    _constants = _constantOrder + (constants - _constantOrder)
    _constants.select {|c| const_get(c).is_a?(MetamodelBuilder::DataTypes::Enum)}.
      each {|c| @enumParentModule[const_get(c)] = @current_object}
    { :name => name.gsub(/.*::(\w+)$/,'\1'),
      :eClassifiers => trans(_constants.collect{|c| const_get(c)}.select{|c| c.is_a?(Class) || 
        (c.is_a?(MetamodelBuilder::DataTypes::Enum) && c != MetamodelBuilder::DataTypes::Boolean) }),
      :eSuperPackage => trans(name =~ /(.*)::\w+$/ ? eval($1) : nil),
      :eSubpackages => trans(_constants.collect{|c| const_get(c)}.select{|c| c.is_a?(Module) && !c.is_a?(Class)}),
      :eAnnotations => trans(_annotations)
    }
  end
  
  method :convert? do
    @current_object.respond_to?(:ecore) && @current_object != RGen::MetamodelBuilder::MMBase
  end
  
  transform MetamodelBuilder::Intermediate::Attribute, :to => EAttribute do
    Hash[*MetamodelBuilder::Intermediate::Attribute.properties.collect{|p| [p, value(p)]}.flatten].merge({
      :eType => (etype == :EEnumerable ? trans(impl_type) : RGen::ECore.const_get(etype)),
      :eAnnotations => trans(annotations)
    })
  end
  
  transform MetamodelBuilder::Intermediate::Reference, :to => EReference do
    Hash[*MetamodelBuilder::Intermediate::Reference.properties.collect{|p| [p, value(p)]}.flatten].merge({
      :eType => trans(impl_type),
      :eOpposite => trans(opposite),
      :eAnnotations => trans(annotations)
    })
  end
  
  transform MetamodelBuilder::Intermediate::Annotation, :to => EAnnotation do
    { :source => source,
      :details => details.keys.collect do |k|
        e = RGen::ECore::EStringToStringMapEntry.new
        e.key = k
        e.value = details[k]
        e
      end
    }
  end
  
  transform MetamodelBuilder::DataTypes::Enum, :to => EEnum do
    { :name => name, 
      :instanceClassName => @enumParentModule && @enumParentModule[@current_object] && @enumParentModule[@current_object].name+"::"+name,
      :eLiterals => literals.collect do |l|
        lit = RGen::ECore::EEnumLiteral.new
        lit.name = l.to_s
        lit
      end }
  end
  
end
  
end
  
end
