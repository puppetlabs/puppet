ePackage "ecore", :nsPrefix => "ecore", :nsURI => "http://www.eclipse.org/emf/2002/Ecore" do
  eClass "EAttribute", :eSuperTypes => ["EStructuralFeature"] do
    eAttribute "iD"
    eReference "eAttributeType", :changeable => false, :derived => true, :transient => true, :volatile => true, :lowerBound => 1, :eType => "EDataType"
  end
  eClass "EAnnotation", :eSuperTypes => ["EModelElement"] do
    eAttribute "source"
    eReference "details", :containment => true, :resolveProxies => false, :upperBound => -1, :eType => "EStringToStringMapEntry"
    eReference "eModelElement", :resolveProxies => false, :eOpposite => "EModelElement.eAnnotations", :transient => true, :eType => "EModelElement"
    eReference "contents", :containment => true, :resolveProxies => false, :upperBound => -1, :eType => "EObject"
    eReference "references", :upperBound => -1, :eType => "EObject"
  end
  eClass "EClass", :eSuperTypes => ["EClassifier"] do
    eAttribute "abstract"
    eAttribute "interface"
    eReference "eSuperTypes", :unsettable => true, :upperBound => -1, :eType => "EClass"
    eReference "eOperations", :containment => true, :resolveProxies => false, :eOpposite => "EOperation.eContainingClass", :upperBound => -1, :eType => "EOperation"
    eReference "eAllAttributes", :changeable => false, :derived => true, :transient => true, :volatile => true, :upperBound => -1, :eType => "EAttribute"
    eReference "eAllReferences", :changeable => false, :derived => true, :transient => true, :volatile => true, :upperBound => -1, :eType => "EReference"
    eReference "eReferences", :changeable => false, :derived => true, :transient => true, :volatile => true, :upperBound => -1, :eType => "EReference"
    eReference "eAttributes", :changeable => false, :derived => true, :transient => true, :volatile => true, :upperBound => -1, :eType => "EAttribute"
    eReference "eAllContainments", :changeable => false, :derived => true, :transient => true, :volatile => true, :upperBound => -1, :eType => "EReference"
    eReference "eAllOperations", :changeable => false, :derived => true, :transient => true, :volatile => true, :upperBound => -1, :eType => "EOperation"
    eReference "eAllStructuralFeatures", :changeable => false, :derived => true, :transient => true, :volatile => true, :upperBound => -1, :eType => "EStructuralFeature"
    eReference "eAllSuperTypes", :changeable => false, :derived => true, :transient => true, :volatile => true, :upperBound => -1, :eType => "EClass"
    eReference "eIDAttribute", :resolveProxies => false, :changeable => false, :derived => true, :transient => true, :volatile => true, :eType => "EAttribute"
    eReference "eStructuralFeatures", :containment => true, :resolveProxies => false, :eOpposite => "EStructuralFeature.eContainingClass", :upperBound => -1, :eType => "EStructuralFeature"
    eReference "eGenericSuperTypes", :containment => true, :resolveProxies => false, :unsettable => true, :upperBound => -1, :eType => "EGenericType"
    eReference "eAllGenericSuperTypes", :changeable => false, :derived => true, :transient => true, :volatile => true, :upperBound => -1, :eType => "EGenericType"
  end
  eClass "EClassifier", :abstract => true, :eSuperTypes => ["ENamedElement"], :eSubTypes => ["EClass", "EDataType"] do
    eAttribute "instanceClassName", :unsettable => true, :volatile => true
    eAttribute "instanceClass", :changeable => false, :derived => true, :transient => true, :volatile => true
    eAttribute "defaultValue", :changeable => false, :derived => true, :transient => true, :volatile => true, :eType => "EJavaObject"
    eAttribute "instanceTypeName", :unsettable => true, :volatile => true
    eReference "ePackage", :eOpposite => "EPackage.eClassifiers", :changeable => false, :transient => true, :eType => "EPackage"
    eReference "eTypeParameters", :containment => true, :upperBound => -1, :eType => "ETypeParameter"
  end
  eClass "EDataType", :eSuperTypes => ["EClassifier"], :eSubTypes => ["EEnum"] do
    eAttribute "serializable", :defaultValueLiteral => "true"
  end
  eClass "EEnum", :eSuperTypes => ["EDataType"] do
    eReference "eLiterals", :containment => true, :resolveProxies => false, :eOpposite => "EEnumLiteral.eEnum", :upperBound => -1, :eType => "EEnumLiteral"
  end
  eClass "EEnumLiteral", :eSuperTypes => ["ENamedElement"] do
    eAttribute "value"
    eAttribute "instance", :transient => true, :eType => "EEnumerator"
    eAttribute "literal"
    eReference "eEnum", :resolveProxies => false, :eOpposite => "EEnum.eLiterals", :changeable => false, :transient => true, :eType => "EEnum"
  end
  eClass "EFactory", :eSuperTypes => ["EModelElement"] do
    eReference "ePackage", :resolveProxies => false, :eOpposite => "EPackage.eFactoryInstance", :transient => true, :lowerBound => 1, :eType => "EPackage"
  end
  eClass "EModelElement", :abstract => true, :eSuperTypes => ["EObject"], :eSubTypes => ["EAnnotation", "EFactory", "ENamedElement"] do
    eReference "eAnnotations", :containment => true, :resolveProxies => false, :eOpposite => "EAnnotation.eModelElement", :upperBound => -1, :eType => "EAnnotation"
  end
  eClass "ENamedElement", :abstract => true, :eSuperTypes => ["EModelElement"], :eSubTypes => ["EClassifier", "EEnumLiteral", "EPackage", "ETypedElement", "ETypeParameter"] do
    eAttribute "name"
  end
  eClass "EObject", :eSubTypes => ["EModelElement", "EGenericType"]
  eClass "EOperation", :eSuperTypes => ["ETypedElement"] do
    eReference "eContainingClass", :resolveProxies => false, :eOpposite => "EClass.eOperations", :changeable => false, :transient => true, :eType => "EClass"
    eReference "eTypeParameters", :containment => true, :upperBound => -1, :eType => "ETypeParameter"
    eReference "eParameters", :containment => true, :resolveProxies => false, :eOpposite => "EParameter.eOperation", :upperBound => -1, :eType => "EParameter"
    eReference "eExceptions", :unsettable => true, :upperBound => -1, :eType => "EClassifier"
    eReference "eGenericExceptions", :containment => true, :resolveProxies => false, :unsettable => true, :upperBound => -1, :eType => "EGenericType"
  end
  eClass "EPackage", :eSuperTypes => ["ENamedElement"] do
    eAttribute "nsURI"
    eAttribute "nsPrefix"
    eReference "eFactoryInstance", :resolveProxies => false, :eOpposite => "EFactory.ePackage", :transient => true, :lowerBound => 1, :eType => "EFactory"
    eReference "eClassifiers", :containment => true, :eOpposite => "EClassifier.ePackage", :upperBound => -1, :eType => "EClassifier"
    eReference "eSubpackages", :containment => true, :eOpposite => "eSuperPackage", :upperBound => -1, :eType => "EPackage"
    eReference "eSuperPackage", :eOpposite => "eSubpackages", :changeable => false, :transient => true, :eType => "EPackage"
  end
  eClass "EParameter", :eSuperTypes => ["ETypedElement"] do
    eReference "eOperation", :resolveProxies => false, :eOpposite => "EOperation.eParameters", :changeable => false, :transient => true, :eType => "EOperation"
  end
  eClass "EReference", :eSuperTypes => ["EStructuralFeature"] do
    eAttribute "containment"
    eAttribute "container", :changeable => false, :derived => true, :transient => true, :volatile => true
    eAttribute "resolveProxies", :defaultValueLiteral => "true"
    eReference "eOpposite", :eType => "EReference"
    eReference "eReferenceType", :changeable => false, :derived => true, :transient => true, :volatile => true, :lowerBound => 1, :eType => "EClass"
    eReference "eKeys", :upperBound => -1, :eType => "EAttribute"
  end
  eClass "EStructuralFeature", :abstract => true, :eSuperTypes => ["ETypedElement"], :eSubTypes => ["EAttribute", "EReference"] do
    eAttribute "changeable", :defaultValueLiteral => "true"
    eAttribute "volatile"
    eAttribute "transient"
    eAttribute "defaultValueLiteral"
    eAttribute "defaultValue", :changeable => false, :derived => true, :transient => true, :volatile => true, :eType => "EJavaObject"
    eAttribute "unsettable"
    eAttribute "derived"
    eReference "eContainingClass", :resolveProxies => false, :eOpposite => "EClass.eStructuralFeatures", :changeable => false, :transient => true, :eType => "EClass"
  end
  eClass "ETypedElement", :abstract => true, :eSuperTypes => ["ENamedElement"], :eSubTypes => ["EOperation", "EParameter", "EStructuralFeature"] do
    eAttribute "ordered", :defaultValueLiteral => "true"
    eAttribute "unique", :defaultValueLiteral => "true"
    eAttribute "lowerBound"
    eAttribute "upperBound", :defaultValueLiteral => "1"
    eAttribute "many", :changeable => false, :derived => true, :transient => true, :volatile => true
    eAttribute "required", :changeable => false, :derived => true, :transient => true, :volatile => true
    eReference "eType", :unsettable => true, :volatile => true, :eType => "EClassifier"
    eReference "eGenericType", :containment => true, :resolveProxies => false, :unsettable => true, :volatile => true, :eType => "EGenericType"
  end
  eDataType "EBigDecimal", :instanceClassName => "java.math.BigDecimal"
  eDataType "EBigInteger", :instanceClassName => "java.math.BigInteger"
  eDataType "EBoolean", :instanceClassName => "boolean"
  eDataType "EBooleanObject", :instanceClassName => "java.lang.Boolean"
  eDataType "EByte", :instanceClassName => "byte"
  eDataType "EByteArray", :instanceClassName => "byte[]"
  eDataType "EByteObject", :instanceClassName => "java.lang.Byte"
  eDataType "EChar", :instanceClassName => "char"
  eDataType "ECharacterObject", :instanceClassName => "java.lang.Character"
  eDataType "EDate", :instanceClassName => "java.util.Date"
  eDataType "EDiagnosticChain", :serializable => false, :instanceClassName => "org.eclipse.emf.common.util.DiagnosticChain"
  eDataType "EDouble", :instanceClassName => "double"
  eDataType "EDoubleObject", :instanceClassName => "java.lang.Double"
  eDataType "EEList", :serializable => false, :instanceClassName => "org.eclipse.emf.common.util.EList" do
    eTypeParameter "E"
  end
  eDataType "EEnumerator", :serializable => false, :instanceClassName => "org.eclipse.emf.common.util.Enumerator"
  eDataType "EFeatureMap", :serializable => false, :instanceClassName => "org.eclipse.emf.ecore.util.FeatureMap"
  eDataType "EFeatureMapEntry", :serializable => false, :instanceClassName => "org.eclipse.emf.ecore.util.FeatureMap$Entry"
  eDataType "EFloat", :instanceClassName => "float"
  eDataType "EFloatObject", :instanceClassName => "java.lang.Float"
  eDataType "EInt", :instanceClassName => "int"
  eDataType "EIntegerObject", :instanceClassName => "java.lang.Integer"
  eDataType "EJavaClass", :instanceClassName => "java.lang.Class" do
    eTypeParameter "T"
  end
  eDataType "EJavaObject", :instanceClassName => "java.lang.Object"
  eDataType "ELong", :instanceClassName => "long"
  eDataType "ELongObject", :instanceClassName => "java.lang.Long"
  eDataType "EMap", :serializable => false, :instanceClassName => "java.util.Map" do
    eTypeParameter "K"
    eTypeParameter "V"
  end
  eDataType "EResource", :serializable => false, :instanceClassName => "org.eclipse.emf.ecore.resource.Resource"
  eDataType "EResourceSet", :serializable => false, :instanceClassName => "org.eclipse.emf.ecore.resource.ResourceSet"
  eDataType "EShort", :instanceClassName => "short"
  eDataType "EShortObject", :instanceClassName => "java.lang.Short"
  eDataType "EString", :instanceClassName => "java.lang.String"
  eClass "EStringToStringMapEntry", :instanceClassName => "java.util.Map$Entry" do
    eAttribute "key"
    eAttribute "value"
  end
  eDataType "ETreeIterator", :serializable => false, :instanceClassName => "org.eclipse.emf.common.util.TreeIterator" do
    eTypeParameter "E"
  end
  eClass "EGenericType", :eSuperTypes => ["EObject"] do
    eReference "eUpperBound", :containment => true, :resolveProxies => false, :eType => "EGenericType"
    eReference "eTypeArguments", :containment => true, :resolveProxies => false, :upperBound => -1, :eType => "EGenericType"
    eReference "eRawType", :changeable => false, :derived => true, :transient => true, :lowerBound => 1, :eType => "EClassifier"
    eReference "eLowerBound", :containment => true, :resolveProxies => false, :eType => "EGenericType"
    eReference "eTypeParameter", :resolveProxies => false, :eType => "ETypeParameter"
    eReference "eClassifier", :eType => "EClassifier"
  end
  eClass "ETypeParameter", :eSuperTypes => ["ENamedElement"] do
    eReference "eBounds", :containment => true, :resolveProxies => false, :upperBound => -1, :eType => "EGenericType"
  end
end
