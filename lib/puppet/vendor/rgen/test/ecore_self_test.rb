$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/ecore/ecore'
require 'rgen/array_extensions'

class ECoreSelfTest < Test::Unit::TestCase
  include RGen::ECore
  
  def test_simple
    assert_equal \
      %w(lowerBound ordered unique upperBound many required eType).sort,
      ETypedElement.ecore.eStructuralFeatures.name.sort
      
    assert_equal \
      EClassifier.ecore,
      ETypedElement.ecore.eStructuralFeatures.find{|f| f.name=="eType"}.eType
    assert_equal %w(ENamedElement), ETypedElement.ecore.eSuperTypes.name

    assert_equal \
      EModelElement.ecore,
      EModelElement.ecore.eStructuralFeatures.find{|f| f.name=="eAnnotations"}.eOpposite.eType

    assert_equal \
      %w(eType),
      ETypedElement.ecore.eReferences.name
      
    assert_equal \
      %w(lowerBound ordered unique upperBound many required).sort,
      ETypedElement.ecore.eAttributes.name.sort
      
    assert RGen::ECore.ecore.is_a?(EPackage)
    assert_equal "ECore", RGen::ECore.ecore.name
    assert_equal "RGen", RGen::ECore.ecore.eSuperPackage.name
    assert_equal %w(ECore), RGen.ecore.eSubpackages.name
    assert_equal\
      %w(EObject EModelElement EAnnotation ENamedElement ETypedElement 
        EStructuralFeature EAttribute EClassifier EDataType EEnum EEnumLiteral EFactory
        EOperation EPackage EParameter EReference EStringToStringMapEntry EClass 
        ETypeArgument EGenericType).sort,
      RGen::ECore.ecore.eClassifiers.name.sort
      
    assert_equal "false", EAttribute.ecore.eAllAttributes.
      find{|a|a.name == "derived"}.defaultValueLiteral
    assert_equal false, EAttribute.ecore.eAllAttributes.
      find{|a|a.name == "derived"}.defaultValue

    assert_nil EAttribute.ecore.eAllAttributes.
      find{|a|a.name == "defaultValueLiteral"}.defaultValueLiteral
    assert_nil EAttribute.ecore.eAllAttributes.
      find{|a|a.name == "defaultValueLiteral"}.defaultValue

  end
end
