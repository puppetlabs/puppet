ePackage "ecore", :nsPrefix => "ecore", :nsURI => "http://www.eclipse.org/emf/2002/Ecore" do
  eClass "EAttribute" do
    eAttribute "iD"
    eReference "eAttributeType", :changeable => false, :derived => true, :transient => true, :volatile => true, :lowerBound => 1
  end
  eClass "EAnnotation" do
    eAttribute "source"
    eReference "details", :containment => true, :resolveProxies => false, :upperBound => -1
    eReference "eModelElement", :resolveProxies => false, :transient => true
    eReference "contents", :containment => true, :resolveProxies => false, :upperBound => -1
    eReference "references", :upperBound => -1
  end
  eClass "EClass" do
    eAttribute "abstract"
    eAttribute "interface"
    eReference "eSuperTypes", :unsettable => true, :upperBound => -1
    eReference "eOperations", :containment => true, :resolveProxies => false, :upperBound => -1
    eReference "eAllAttributes", :changeable => false, :derived => true, :transient => true, :volatile => true, :upperBound => -1
    eReference "eAllReferences", :changeable => false, :derived => true, :transient => true, :volatile => true, :upperBound => -1
    eReference "eReferences", :changeable => false, :derived => true, :transient => true, :volatile => true, :upperBound => -1
    eReference "eAttributes", :changeable => false, :derived => true, :transient => true, :volatile => true, :upperBound => -1
    eReference "eAllContainments", :changeable => false, :derived => true, :transient => true, :volatile => true, :upperBound => -1
    eReference "eAllOperations", :changeable => false, :derived => true, :transient => true, :volatile => true, :upperBound => -1
    eReference "eAllStructuralFeatures", :changeable => false, :derived => true, :transient => true, :volatile => true, :upperBound => -1
    eReference "eAllSuperTypes", :changeable => false, :derived => true, :transient => true, :volatile => true, :upperBound => -1
    eReference "eIDAttribute", :resolveProxies => false, :changeable => false, :derived => true, :transient => true, :volatile => true
    eReference "eStructuralFeatures", :containment => true, :resolveProxies => false, :upperBound => -1
    eReference "eGenericSuperTypes", :containment => true, :resolveProxies => false, :unsettable => true, :upperBound => -1
    eReference "eAllGenericSuperTypes", :changeable => false, :derived => true, :transient => true, :volatile => true, :upperBound => -1
  end
  eClass "EClassifier", :abstract => true do
    eAttribute "instanceClassName", :unsettable => true, :volatile => true
    eAttribute "instanceClass", :changeable => false, :derived => true, :transient => true, :volatile => true
    eAttribute "defaultValue", :changeable => false, :derived => true, :transient => true, :volatile => true
    eAttribute "instanceTypeName", :unsettable => true, :volatile => true
    eReference "ePackage", :changeable => false, :transient => true
    eReference "eTypeParameters", :containment => true, :upperBound => -1
  end
  eClass "EDataType" do
    eAttribute "serializable", :defaultValueLiteral => "true"
  end
  eClass "EEnum" do
    eReference "eLiterals", :containment => true, :resolveProxies => false, :upperBound => -1
  end
  eClass "EEnumLiteral" do
    eAttribute "value"
    eAttribute "instance", :transient => true
    eAttribute "literal"
    eReference "eEnum", :resolveProxies => false, :changeable => false, :transient => true
  end
  eClass "EFactory" do
    eReference "ePackage", :resolveProxies => false, :transient => true, :lowerBound => 1
  end
  eClass "EModelElement", :abstract => true do
    eReference "eAnnotations", :containment => true, :resolveProxies => false, :upperBound => -1
  end
  eClass "ENamedElement", :abstract => true do
    eAttribute "name"
  end
  eClass "EObject"
  eClass "EOperation" do
    eReference "eContainingClass", :resolveProxies => false, :changeable => false, :transient => true
    eReference "eTypeParameters", :containment => true, :upperBound => -1
    eReference "eParameters", :containment => true, :resolveProxies => false, :upperBound => -1
    eReference "eExceptions", :unsettable => true, :upperBound => -1
    eReference "eGenericExceptions", :containment => true, :resolveProxies => false, :unsettable => true, :upperBound => -1
  end
  eClass "EPackage" do
    eAttribute "nsURI"
    eAttribute "nsPrefix"
    eReference "eFactoryInstance", :resolveProxies => false, :transient => true, :lowerBound => 1
    eReference "eClassifiers", :containment => true, :upperBound => -1
    eReference "eSubpackages", :containment => true, :upperBound => -1
    eReference "eSuperPackage", :changeable => false, :transient => true
  end
  eClass "EParameter" do
    eReference "eOperation", :resolveProxies => false, :changeable => false, :transient => true
  end
  eClass "EReference" do
    eAttribute "containment"
    eAttribute "container", :changeable => false, :derived => true, :transient => true, :volatile => true
    eAttribute "resolveProxies", :defaultValueLiteral => "true"
    eReference "eOpposite"
    eReference "eReferenceType", :changeable => false, :derived => true, :transient => true, :volatile => true, :lowerBound => 1
    eReference "eKeys", :upperBound => -1
  end
  eClass "EStructuralFeature", :abstract => true do
    eAttribute "changeable", :defaultValueLiteral => "true"
    eAttribute "volatile"
    eAttribute "transient"
    eAttribute "defaultValueLiteral"
    eAttribute "defaultValue", :changeable => false, :derived => true, :transient => true, :volatile => true
    eAttribute "unsettable"
    eAttribute "derived"
    eReference "eContainingClass", :resolveProxies => false, :changeable => false, :transient => true
  end
  eClass "ETypedElement", :abstract => true do
    eAttribute "ordered", :defaultValueLiteral => "true"
    eAttribute "unique", :defaultValueLiteral => "true"
    eAttribute "lowerBound"
    eAttribute "upperBound", :defaultValueLiteral => "1"
    eAttribute "many", :changeable => false, :derived => true, :transient => true, :volatile => true
    eAttribute "required", :changeable => false, :derived => true, :transient => true, :volatile => true
    eReference "eType", :unsettable => true, :volatile => true
    eReference "eGenericType", :containment => true, :resolveProxies => false, :unsettable => true, :volatile => true
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
  eClass "EGenericType" do
    eReference "eUpperBound", :containment => true, :resolveProxies => false
    eReference "eTypeArguments", :containment => true, :resolveProxies => false, :upperBound => -1
    eReference "eRawType", :changeable => false, :derived => true, :transient => true, :lowerBound => 1
    eReference "eLowerBound", :containment => true, :resolveProxies => false
    eReference "eTypeParameter", :resolveProxies => false
    eReference "eClassifier"
  end
  eClass "ETypeParameter" do
    eReference "eBounds", :containment => true, :resolveProxies => false, :upperBound => -1
  end
end
