$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/metamodel_builder'
require 'rgen/array_extensions'
require 'bigdecimal'

class MetamodelBuilderTest < Test::Unit::TestCase
  
  module TestMetamodel
    extend RGen::MetamodelBuilder::ModuleExtension

    class SimpleClass < RGen::MetamodelBuilder::MMBase
      KindType = RGen::MetamodelBuilder::DataTypes::Enum.new([:simple, :extended])
      has_attr 'name' # default is String
      has_attr 'stringWithDefault', String, :defaultValueLiteral => "xtest"
      has_attr 'integerWithDefault', Integer, :defaultValueLiteral => "123"
      has_attr 'longWithDefault', Long, :defaultValueLiteral => "1234567890"
      has_attr 'floatWithDefault', Float, :defaultValueLiteral => "0.123"
      has_attr 'boolWithDefault', Boolean, :defaultValueLiteral => "true"
      has_attr 'anything', Object
      has_attr 'allowed', RGen::MetamodelBuilder::DataTypes::Boolean
      has_attr 'kind', KindType
      has_attr 'kindWithDefault', KindType, :defaultValueLiteral => "extended"
    end

    class ManyAttrClass < RGen::MetamodelBuilder::MMBase
      has_many_attr 'literals', String
      has_many_attr 'bools', Boolean
      has_many_attr 'integers', Integer
      has_many_attr 'enums', RGen::MetamodelBuilder::DataTypes::Enum.new([:a, :b, :c])
      has_many_attr 'limitTest', Integer, :upperBound => 2
    end

    class ClassA < RGen::MetamodelBuilder::MMBase
      # metamodel accessors must work independent of the ==() method
      module ClassModule
        def ==(o)
          o.is_a?(ClassA)
        end
      end
    end
    
    class ClassB < RGen::MetamodelBuilder::MMBase
    end
    
    class ClassC < RGen::MetamodelBuilder::MMBase
    end
    
    class HasOneTestClass < RGen::MetamodelBuilder::MMBase
      has_one 'classA', ClassA
      has_one 'classB', ClassB
    end
    
    class HasManyTestClass < RGen::MetamodelBuilder::MMBase
      has_many 'classA', ClassA
    end
    
    class OneClass < RGen::MetamodelBuilder::MMBase
    end
    class ManyClass < RGen::MetamodelBuilder::MMBase
    end
    OneClass.one_to_many 'manyClasses', ManyClass, 'oneClass', :upperBound => 5
    
    class AClassMM < RGen::MetamodelBuilder::MMBase
    end
    class BClassMM < RGen::MetamodelBuilder::MMBase
    end
    AClassMM.many_to_many 'bClasses', BClassMM, 'aClasses'
    
    module SomePackage 
      extend RGen::MetamodelBuilder::ModuleExtension
      
      class ClassA < RGen::MetamodelBuilder::MMBase
      end
      
      module SubPackage 
        extend RGen::MetamodelBuilder::ModuleExtension
      
        class ClassB < RGen::MetamodelBuilder::MMBase
        end
      end
    end
    
    class OneClass2 < RGen::MetamodelBuilder::MMBase
    end
    class ManyClass2 < RGen::MetamodelBuilder::MMBase
    end
    ManyClass2.many_to_one 'oneClass', OneClass2, 'manyClasses'
    
    class AClassOO < RGen::MetamodelBuilder::MMBase
    end
    class BClassOO < RGen::MetamodelBuilder::MMBase
    end
    AClassOO.one_to_one 'bClass', BClassOO, 'aClass'
    
    class SomeSuperClass < RGen::MetamodelBuilder::MMBase
      has_attr "name"
      has_many "classAs", ClassA
    end
    
    class SomeSubClass < SomeSuperClass
      has_attr "subname"
      has_many "classBs", ClassB
    end
    
    class OtherSubClass < SomeSuperClass
      has_attr "othersubname"
      has_many "classCs", ClassC
    end

    class SubSubClass < RGen::MetamodelBuilder::MMMultiple(SomeSubClass, OtherSubClass)
      has_attr "subsubname"
    end
    
    module AnnotatedModule 
      extend RGen::MetamodelBuilder::ModuleExtension

      annotation "moduletag" => "modulevalue"
      
      class AnnotatedClass < RGen::MetamodelBuilder::MMBase
        annotation "sometag" => "somevalue", "othertag" => "othervalue"
        annotation :source => "rgen/test", :details => {"thirdtag" => "thirdvalue"}
      
        has_attr "boolAttr", Boolean do
          annotation "attrtag" => "attrval"
          annotation :source => "rgen/test2", :details => {"attrtag2" => "attrvalue2", "attrtag3" => "attrvalue3"}
        end

        has_many "others", AnnotatedClass do
          annotation "reftag" => "refval"
          annotation :source => "rgen/test3", :details => {"reftag2" => "refvalue2", "reftag3" => "refvalue3"}
        end

        many_to_many "m2m", AnnotatedClass, "m2mback" do
          annotation "m2mtag" => "m2mval"
          opposite_annotation "opposite_m2mtag" => "opposite_m2mval"
        end
      end
      
    end
    
    class AbstractClass < RGen::MetamodelBuilder::MMBase
      abstract
    end

    class ContainedClass < RGen::MetamodelBuilder::MMBase
    end

    class ContainerClass < RGen::MetamodelBuilder::MMBase
      contains_one_uni 'oneChildUni', ContainedClass
      contains_one_uni 'oneChildUni2', ContainedClass
      contains_one 'oneChild', ContainedClass, 'parentOne'
      contains_one 'oneChild2', ContainedClass, 'parentOne2'
      contains_many_uni 'manyChildUni', ContainedClass
      contains_many_uni 'manyChildUni2', ContainedClass
      contains_many 'manyChild', ContainedClass, 'parentMany'
      contains_many 'manyChild2', ContainedClass, 'parentMany2'
    end

    class NestedContainerClass < ContainedClass
      contains_one_uni 'oneChildUni', ContainedClass
    end

    class OppositeRefAssocA < RGen::MetamodelBuilder::MMBase
    end
    class OppositeRefAssocB < RGen::MetamodelBuilder::MMBase
    end
    OppositeRefAssocA.one_to_one 'bClass', OppositeRefAssocB, 'aClass'

  end
   
  def mm
    TestMetamodel
  end

  def test_has_attr
    sc = mm::SimpleClass.new
    
    assert_respond_to sc, :name
    assert_respond_to sc, :name=
    sc.name = "TestName"
    assert_equal "TestName", sc.name
    sc.name = nil
    assert_equal nil, sc.name
    err = assert_raise StandardError do
      sc.name = 5
    end
    assert_match /In (\w+::)+SimpleClass : Can not use a Fixnum where a String is expected/, err.message
    assert_equal "EString", mm::SimpleClass.ecore.eAttributes.find{|a| a.name=="name"}.eType.name

    assert_equal "xtest", sc.stringWithDefault
    assert_equal :extended, sc.kindWithDefault
    assert_equal 123, sc.integerWithDefault
    assert_equal 1234567890, sc.longWithDefault
    assert_equal 0.123, sc.floatWithDefault
    assert_equal true, sc.boolWithDefault

    # setting nil should not make the default value appear on next read
    sc.stringWithDefault = nil
    assert_nil sc.stringWithDefault
    
    sc.anything = :asymbol
    assert_equal :asymbol, sc.anything
    sc.anything = self # a class
    assert_equal self, sc.anything
    
    assert_respond_to sc, :allowed
    assert_respond_to sc, :allowed=
    sc.allowed = true
    assert_equal true, sc.allowed
    sc.allowed = false
    assert_equal false, sc.allowed
    sc.allowed = nil
    assert_equal nil, sc.allowed
    err = assert_raise StandardError do
      sc.allowed = :someSymbol
    end
    assert_match /In (\w+::)+SimpleClass : Can not use a Symbol\(:someSymbol\) where a \[true,false\] is expected/, err.message
    err = assert_raise StandardError do
      sc.allowed = "a string"
    end
    assert_match /In (\w+::)+SimpleClass : Can not use a String where a \[true,false\] is expected/, err.message
    assert_equal "EBoolean", mm::SimpleClass.ecore.eAttributes.find{|a| a.name=="allowed"}.eType.name
    
    assert_respond_to sc, :kind
    assert_respond_to sc, :kind=
    sc.kind = :simple
    assert_equal :simple, sc.kind
    sc.kind = :extended
    assert_equal :extended, sc.kind
    sc.kind = nil
    assert_equal nil, sc.kind
    err = assert_raise StandardError do
      sc.kind = :false
    end
    assert_match /In (\w+::)+SimpleClass : Can not use a Symbol\(:false\) where a \[:simple,:extended\] is expected/, err.message
    err = assert_raise StandardError do
      sc.kind = "a string"
    end
    assert_match /In (\w+::)+SimpleClass : Can not use a String where a \[:simple,:extended\] is expected/, err.message
    
    enum = mm::SimpleClass.ecore.eAttributes.find{|a| a.name=="kind"}.eType
    assert_equal ["extended", "simple"], enum.eLiterals.name.sort
  end

  def test_float
    sc = mm::SimpleClass.new
    sc.floatWithDefault = 7.89
    assert_equal 7.89, sc.floatWithDefault
    if BigDecimal.double_fig == 16
      sc.floatWithDefault = 123456789012345678.0
      # loss of precision
      assert_equal "123456789012345680.0", sprintf("%.1f", sc.floatWithDefault)
    end
    sc.floatWithDefault = nil
    sc.floatWithDefault = BigDecimal.new("123456789012345678.0")
    assert sc.floatWithDefault.is_a?(BigDecimal)
    assert_equal "123456789012345678.0", sc.floatWithDefault.to_s("F")

    dump = Marshal.dump(sc)
    sc2 = Marshal.load(dump)
    assert sc2.floatWithDefault.is_a?(BigDecimal)
    assert_equal "123456789012345678.0", sc2.floatWithDefault.to_s("F")
  end

  def test_long
    sc = mm::SimpleClass.new
    sc.longWithDefault = 5
    assert_equal 5, sc.longWithDefault
    sc.longWithDefault = 1234567890
    assert_equal 1234567890, sc.longWithDefault
    assert sc.longWithDefault.is_a?(Bignum)
    assert sc.longWithDefault.is_a?(Integer)
    err = assert_raise StandardError do
      sc.longWithDefault = "a string"
    end
    assert_match /In (\w+::)+SimpleClass : Can not use a String where a Integer is expected/, err.message
  end
  
  def test_many_attr
    o = mm::ManyAttrClass.new

    assert_respond_to o, :literals
    assert_respond_to o, :addLiterals
    assert_respond_to o, :removeLiterals

    err = assert_raise(StandardError) do
      o.addLiterals(1)
    end
    assert_match /In (\w+::)+ManyAttrClass : Can not use a Fixnum where a String is expected/, err.message

    assert_equal [], o.literals
    o.addLiterals("a")
    assert_equal ["a"], o.literals
    o.addLiterals("b")
    assert_equal ["a", "b"], o.literals
    o.addLiterals("b")
    assert_equal ["a", "b", "b"], o.literals
    # attributes allow the same object several times
    o.addLiterals(o.literals.first)
    assert_equal ["a", "b", "b", "a"], o.literals
    assert o.literals[0].object_id == o.literals[3].object_id
    # removing works by object identity, so providing a new string won't delete an existing one
    o.removeLiterals("a")
    assert_equal ["a", "b", "b", "a"], o.literals
    theA = o.literals.first
    # each remove command removes only one element: remove first "a"
    o.removeLiterals(theA)
    assert_equal ["b", "b", "a"], o.literals
    # remove second "a" (same object)
    o.removeLiterals(theA)
    assert_equal ["b", "b"], o.literals
    o.removeLiterals(o.literals.first)
    assert_equal ["b"], o.literals
    o.removeLiterals(o.literals.first)
    assert_equal [], o.literals
  
    # setting multiple elements at a time
    o.literals = ["a", "b", "c"]
    assert_equal ["a", "b", "c"], o.literals
    # can only take enumerables
    err = assert_raise(StandardError) do
      o.literals = 1
    end
    assert_match /In (\w+::)+ManyAttrClass : Can not use a Fixnum where a Enumerable is expected/, err.message
 
    o.bools = [true, false, true, false]
    assert_equal [true, false, true, false], o.bools

    o.integers = [1, 2, 2, 3, 3]
    assert_equal [1, 2, 2, 3, 3], o.integers

    o.enums = [:a, :a, :b, :c, :c]
    assert_equal [:a, :a, :b, :c, :c], o.enums

    lit = mm::ManyAttrClass.ecore.eAttributes.find{|a| a.name == "literals"}
    assert lit.is_a?(RGen::ECore::EAttribute)
    assert lit.many

    lim = mm::ManyAttrClass.ecore.eAttributes.find{|a| a.name == "limitTest"}
    assert lit.many
    assert_equal 2, lim.upperBound
  end

  def test_many_attr_insert
    o = mm::ManyAttrClass.new
    o.addLiterals("a")
    o.addLiterals("b", 0)
    o.addLiterals("c", 1)
    assert_equal ["b", "c", "a"], o.literals
  end

  def test_has_one
    sc = mm::HasOneTestClass.new
    assert_respond_to sc, :classA
    assert_respond_to sc, :classA=
    ca = mm::ClassA.new
    sc.classA = ca
    assert_equal ca, sc.classA
    sc.classA = nil
    assert_equal nil, sc.classA
    
    assert_respond_to sc, :classB
    assert_respond_to sc, :classB=
    cb = mm::ClassB.new
    sc.classB = cb
    assert_equal cb, sc.classB
    
    err = assert_raise StandardError do
      sc.classB = ca
    end
    assert_match /In (\w+::)+HasOneTestClass : Can not use a (\w+::)+ClassA where a (\w+::)+ClassB is expected/, err.message
    
    assert_equal [], mm::ClassA.ecore.eReferences
    assert_equal [], mm::ClassB.ecore.eReferences
    assert_equal ["classA", "classB"].sort, mm::HasOneTestClass.ecore.eReferences.name.sort
    assert_equal [], mm::HasOneTestClass.ecore.eReferences.select { |a| a.many == true }
    assert_equal [], mm::HasOneTestClass.ecore.eAttributes
  end
  
  def test_has_many
    o = mm::HasManyTestClass.new
    ca1 = mm::ClassA.new
    ca2 = mm::ClassA.new
    ca3 = mm::ClassA.new
    o.addClassA(ca1)
    o.addClassA(ca2)
    assert_equal [ca1, ca2], o.classA
    # make sure we get a copy
    o.classA.clear
    assert_equal [ca1, ca2], o.classA
    o.removeClassA(ca3)
    assert_equal [ca1, ca2], o.classA
    o.removeClassA(ca2)
    assert_equal [ca1], o.classA
    err = assert_raise StandardError do
      o.addClassA(mm::ClassB.new)
    end
    assert_match /In (\w+::)+HasManyTestClass : Can not use a (\w+::)+ClassB where a (\w+::)+ClassA is expected/, err.message
    assert_equal [], mm::HasManyTestClass.ecore.eReferences.select{|r| r.many == false}
    assert_equal ["classA"], mm::HasManyTestClass.ecore.eReferences.select{|r| r.many == true}.name
  end

  def test_has_many_insert
    o = mm::HasManyTestClass.new
    ca1 = mm::ClassA.new
    ca2 = mm::ClassA.new
    ca3 = mm::ClassA.new
    ca4 = mm::ClassA.new
    ca5 = mm::ClassA.new
    o.addClassA(ca1)
    o.addClassA(ca2)
    o.addClassA(ca3,0)
    o.addClassA(ca4,1)
    o.addGeneric("classA",ca5,2)
    assert_equal [ca3, ca4, ca5, ca1, ca2], o.classA
  end
  
  def test_one_to_many
    oc = mm::OneClass.new
    assert_respond_to oc, :manyClasses
    assert oc.manyClasses.empty?
    
    mc = mm::ManyClass.new
    assert_respond_to mc, :oneClass
    assert_respond_to mc, :oneClass=
    assert_nil mc.oneClass
    
    # put the OneClass into the ManyClass
    mc.oneClass = oc
    assert_equal oc, mc.oneClass
    assert oc.manyClasses.include?(mc)
    
    # remove the OneClass from the ManyClass
    mc.oneClass = nil
    assert_equal nil, mc.oneClass
    assert !oc.manyClasses.include?(mc)
    
    # put the ManyClass into the OneClass
    oc.addManyClasses mc
    assert oc.manyClasses.include?(mc)
    assert_equal oc, mc.oneClass
    
    # remove the ManyClass from the OneClass
    oc.removeManyClasses mc
    assert !oc.manyClasses.include?(mc)
    assert_equal nil, mc.oneClass
    
    assert_equal [], mm::OneClass.ecore.eReferences.select{|r| r.many == false}
    assert_equal ["manyClasses"], mm::OneClass.ecore.eReferences.select{|r| r.many == true}.name
    assert_equal 5, mm::OneClass.ecore.eReferences.find{|r| r.many == true}.upperBound
    assert_equal ["oneClass"], mm::ManyClass.ecore.eReferences.select{|r| r.many == false}.name
    assert_equal [], mm::ManyClass.ecore.eReferences.select{|r| r.many == true}
  end
  
  def test_one_to_many_replace1
    oc1 = mm::OneClass.new
    oc2 = mm::OneClass.new
    mc = mm::ManyClass.new  	
    
    oc1.manyClasses = [mc]
    assert_equal [mc], oc1.manyClasses
    assert_equal [], oc2.manyClasses
    assert_equal oc1, mc.oneClass
    
    oc2.manyClasses = [mc]
    assert_equal [mc], oc2.manyClasses
    assert_equal [], oc1.manyClasses
    assert_equal oc2, mc.oneClass
	end

  def test_one_to_many_replace2
    oc = mm::OneClass.new
    mc1 = mm::ManyClass.new  	
    mc2 = mm::ManyClass.new  	
    
    mc1.oneClass = oc
    assert_equal [mc1], oc.manyClasses
    assert_equal oc, mc1.oneClass
    assert_equal nil, mc2.oneClass
    
    mc2.oneClass = oc
    assert_equal [mc1, mc2], oc.manyClasses
    assert_equal oc, mc1.oneClass
    assert_equal oc, mc2.oneClass
	end
	
  def test_one_to_many_insert
    oc = mm::OneClass.new
    mc1 = mm::ManyClass.new  	
    mc2 = mm::ManyClass.new  	

    oc.addManyClasses(mc1, 0)
    oc.addManyClasses(mc2, 0)
    assert_equal [mc2, mc1], oc.manyClasses
    assert_equal oc, mc1.oneClass
    assert_equal oc, mc2.oneClass
  end

  def test_one_to_many2
    oc = mm::OneClass2.new
    assert_respond_to oc, :manyClasses
    assert oc.manyClasses.empty?
    
    mc = mm::ManyClass2.new
    assert_respond_to mc, :oneClass
    assert_respond_to mc, :oneClass=
    assert_nil mc.oneClass
    
    # put the OneClass into the ManyClass
    mc.oneClass = oc
    assert_equal oc, mc.oneClass
    assert oc.manyClasses.include?(mc)
    
    # remove the OneClass from the ManyClass
    mc.oneClass = nil
    assert_equal nil, mc.oneClass
    assert !oc.manyClasses.include?(mc)
    
    # put the ManyClass into the OneClass
    oc.addManyClasses mc
    assert oc.manyClasses.include?(mc)
    assert_equal oc, mc.oneClass
    
    # remove the ManyClass from the OneClass
    oc.removeManyClasses mc
    assert !oc.manyClasses.include?(mc)
    assert_equal nil, mc.oneClass
    
    assert_equal [], mm::OneClass2.ecore.eReferences.select{|r| r.many == false}
    assert_equal ["manyClasses"], mm::OneClass2.ecore.eReferences.select{|r| r.many == true}.name
    assert_equal ["oneClass"], mm::ManyClass2.ecore.eReferences.select{|r| r.many == false}.name
    assert_equal [], mm::ManyClass2.ecore.eReferences.select{|r| r.many == true}
  end
  
  def test_one_to_one
    ac = mm::AClassOO.new
    assert_respond_to ac, :bClass
    assert_respond_to ac, :bClass=
    assert_nil ac.bClass
    
    bc = mm::BClassOO.new
    assert_respond_to bc, :aClass
    assert_respond_to bc, :aClass=
    assert_nil bc.aClass

    # put the AClass into the BClass
    bc.aClass = ac
    assert_equal ac, bc.aClass
    assert_equal bc, ac.bClass
    
    # remove the AClass from the BClass
    bc.aClass = nil
    assert_equal nil, bc.aClass
    assert_equal nil, ac.bClass
    
    # put the BClass into the AClass
    ac.bClass = bc
    assert_equal bc, ac.bClass
    assert_equal ac, bc.aClass
    
    # remove the BClass from the AClass
    ac.bClass = nil
    assert_equal nil, ac.bClass
    assert_equal nil, bc.aClass
    
    assert_equal ["bClass"], mm::AClassOO.ecore.eReferences.select{|r| r.many == false}.name
    assert_equal [], mm::AClassOO.ecore.eReferences.select{|r| r.many == true}
    assert_equal ["aClass"], mm::BClassOO.ecore.eReferences.select{|r| r.many == false}.name
    assert_equal [], mm::BClassOO.ecore.eReferences.select{|r| r.many == true}
  end
  
  def test_one_to_one_replace
    a = mm::AClassOO.new
    b1 = mm::BClassOO.new
    b2 = mm::BClassOO.new
    
    a.bClass = b1
    assert_equal b1, a.bClass
    assert_equal a, b1.aClass
    assert_equal nil, b2.aClass
  
    a.bClass = b2
    assert_equal b2, a.bClass
    assert_equal nil, b1.aClass
    assert_equal a, b2.aClass
	end	
  
  def test_many_to_many
    
    ac = mm::AClassMM.new
    assert_respond_to ac, :bClasses
    assert ac.bClasses.empty?
    
    bc = mm::BClassMM.new
    assert_respond_to bc, :aClasses
    assert bc.aClasses.empty?
    
    # put the AClass into the BClass
    bc.addAClasses ac
    assert bc.aClasses.include?(ac)
    assert ac.bClasses.include?(bc)
    
    # put something else into the BClass
    err = assert_raise StandardError do
      bc.addAClasses :notaaclass
    end
    assert_match /In (\w+::)+BClassMM : Can not use a Symbol\(:notaaclass\) where a (\w+::)+AClassMM is expected/, err.message
    
    # remove the AClass from the BClass
    bc.removeAClasses ac
    assert !bc.aClasses.include?(ac)
    assert !ac.bClasses.include?(bc)
    
    # put the BClass into the AClass
    ac.addBClasses bc
    assert ac.bClasses.include?(bc)
    assert bc.aClasses.include?(ac)
    
    # put something else into the AClass
    err = assert_raise StandardError do
      ac.addBClasses :notabclass
    end
    assert_match /In (\w+::)+AClassMM : Can not use a Symbol\(:notabclass\) where a (\w+::)+BClassMM is expected/, err.message
    
    # remove the BClass from the AClass
    ac.removeBClasses bc
    assert !ac.bClasses.include?(bc)
    assert !bc.aClasses.include?(ac)
    
    assert_equal [], mm::AClassMM.ecore.eReferences.select{|r| r.many == false}
    assert_equal  ["bClasses"], mm::AClassMM.ecore.eReferences.select{|r| r.many == true}.name
    assert_equal [], mm::BClassMM.ecore.eReferences.select{|r| r.many == false}
    assert_equal  ["aClasses"], mm::BClassMM.ecore.eReferences.select{|r| r.many == true}.name
  end
  
  def test_many_to_many_insert
    ac1 = mm::AClassMM.new
    ac2 = mm::AClassMM.new
    bc1= mm::BClassMM.new
    bc2= mm::BClassMM.new

    ac1.addBClasses(bc1)
    ac1.addBClasses(bc2, 0)
    ac2.addBClasses(bc1)
    ac2.addBClasses(bc2, 0)

    assert_equal [bc2, bc1], ac1.bClasses
    assert_equal [bc2, bc1], ac2.bClasses
    assert_equal [ac1, ac2], bc1.aClasses
    assert_equal [ac1, ac2], bc2.aClasses
  end
   
  def test_inheritance
    assert_equal ["name"], mm::SomeSuperClass.ecore.eAllAttributes.name
    assert_equal ["classAs"], mm::SomeSuperClass.ecore.eAllReferences.name
    assert_equal ["name", "subname"], mm::SomeSubClass.ecore.eAllAttributes.name.sort
    assert_equal ["classAs", "classBs"], mm::SomeSubClass.ecore.eAllReferences.name.sort
    assert_equal ["name", "othersubname"], mm::OtherSubClass.ecore.eAllAttributes.name.sort
    assert_equal ["classAs", "classCs"], mm::OtherSubClass.ecore.eAllReferences.name.sort
    assert mm::SomeSubClass.new.is_a?(mm::SomeSuperClass)
    assert_equal ["name", "othersubname", "subname", "subsubname"], mm::SubSubClass.ecore.eAllAttributes.name.sort
    assert_equal ["classAs", "classBs", "classCs"], mm::SubSubClass.ecore.eAllReferences.name.sort
    assert mm::SubSubClass.new.is_a?(mm::SomeSuperClass)
    assert mm::SubSubClass.new.is_a?(mm::SomeSubClass)
    assert mm::SubSubClass.new.is_a?(mm::OtherSubClass)
  end
  
  def test_annotations
    assert_equal 1, mm::AnnotatedModule.ecore.eAnnotations.size
    anno = mm::AnnotatedModule.ecore.eAnnotations.first
    checkAnnotation(anno, nil, {"moduletag" => "modulevalue"})

    eClass = mm::AnnotatedModule::AnnotatedClass.ecore
    assert_equal 2, eClass.eAnnotations.size
    anno = eClass.eAnnotations.find{|a| a.source == "rgen/test"}
    checkAnnotation(anno, "rgen/test", {"thirdtag" => "thirdvalue"})
    anno = eClass.eAnnotations.find{|a| a.source == nil}
    checkAnnotation(anno, nil, {"sometag" => "somevalue", "othertag" => "othervalue"})

    eAttr = eClass.eAttributes.first
    assert_equal 2, eAttr.eAnnotations.size
    anno = eAttr.eAnnotations.find{|a| a.source == "rgen/test2"}
    checkAnnotation(anno, "rgen/test2", {"attrtag2" => "attrvalue2", "attrtag3" => "attrvalue3"})
    anno = eAttr.eAnnotations.find{|a| a.source == nil}
    checkAnnotation(anno, nil, {"attrtag" => "attrval"})

    eRef = eClass.eReferences.find{|r| !r.eOpposite}
    assert_equal 2, eRef.eAnnotations.size
    anno = eRef.eAnnotations.find{|a| a.source == "rgen/test3"}
    checkAnnotation(anno, "rgen/test3", {"reftag2" => "refvalue2", "reftag3" => "refvalue3"})
    anno = eRef.eAnnotations.find{|a| a.source == nil}
    checkAnnotation(anno, nil, {"reftag" => "refval"})

    eRef = eClass.eReferences.find{|r| r.eOpposite}
    assert_equal 1, eRef.eAnnotations.size
    anno = eRef.eAnnotations.first
    checkAnnotation(anno, nil, {"m2mtag" => "m2mval"})
    eRef = eRef.eOpposite
    assert_equal 1, eRef.eAnnotations.size
    anno = eRef.eAnnotations.first
    checkAnnotation(anno, nil, {"opposite_m2mtag" => "opposite_m2mval"})
  end

  def checkAnnotation(anno, source, hash)
    assert anno.is_a?(RGen::ECore::EAnnotation)
    assert_equal source, anno.source
    assert_equal hash.size, anno.details.size
    hash.each_pair do |k, v|
      detail = anno.details.find{|d| d.key == k}
      assert detail.is_a?(RGen::ECore::EStringToStringMapEntry)
      assert_equal v, detail.value
    end
  end
  
	def test_ecore_identity
		subPackage = mm::SomePackage::SubPackage.ecore
		assert_equal subPackage.eClassifiers.first.object_id, mm::SomePackage::SubPackage::ClassB.ecore.object_id
		
		somePackage = mm::SomePackage.ecore
		assert_equal somePackage.eSubpackages.first.object_id, subPackage.object_id
	end

  def test_proxy
    p = RGen::MetamodelBuilder::MMProxy.new("test")
    assert_equal "test", p.targetIdentifier
    p.targetIdentifier = 123
    assert_equal 123, p.targetIdentifier
    p.data = "additional info"
    assert_equal "additional info", p.data
    q = RGen::MetamodelBuilder::MMProxy.new("ident", "data")
    assert_equal "data", q.data
  end
 
  def test_proxies_has_one
    e = mm::HasOneTestClass.new 
    proxy = RGen::MetamodelBuilder::MMProxy.new
    e.classA = proxy
    assert_equal proxy, e.classA
    a = mm::ClassA.new 
    # displace proxy
    e.classA = a
    assert_equal a, e.classA
    # displace by proxy
    e.classA = proxy
    assert_equal proxy, e.classA
  end

  def test_proxies_has_many
    e = mm::HasManyTestClass.new
    proxy = RGen::MetamodelBuilder::MMProxy.new
    e.addClassA(proxy)
    assert_equal [proxy], e.classA 
    # again
    e.addClassA(proxy)
    assert_equal [proxy], e.classA 
    proxy2 = RGen::MetamodelBuilder::MMProxy.new
    e.addClassA(proxy2)
    assert_equal [proxy, proxy2], e.classA 
    e.removeClassA(proxy)
    assert_equal [proxy2], e.classA
    # again
    e.removeClassA(proxy)
    assert_equal [proxy2], e.classA 
    e.removeClassA(proxy2)
    assert_equal [], e.classA 
  end

  def test_proxies_one_to_one
    ea = mm::AClassOO.new
    eb = mm::BClassOO.new
    proxy1 = RGen::MetamodelBuilder::MMProxy.new
    proxy2 = RGen::MetamodelBuilder::MMProxy.new
    ea.bClass = proxy1
    eb.aClass = proxy2
    assert_equal proxy1, ea.bClass
    assert_equal proxy2, eb.aClass
    # displace proxies
    ea.bClass = eb
    assert_equal eb, ea.bClass
    assert_equal ea, eb.aClass
    # displace by proxy
    ea.bClass = proxy1
    assert_equal proxy1, ea.bClass
    assert_nil eb.aClass
  end

  def test_proxies_one_to_many
    eo = mm::OneClass.new
    em = mm::ManyClass.new
    proxy1 = RGen::MetamodelBuilder::MMProxy.new
    proxy2 = RGen::MetamodelBuilder::MMProxy.new
    eo.addManyClasses(proxy1)
    assert_equal [proxy1], eo.manyClasses
    em.oneClass = proxy2
    assert_equal proxy2, em.oneClass
    # displace proxies at many side
    # adding em will set em.oneClass to eo and displace the proxy from em.oneClass
    eo.addManyClasses(em)
    assert_equal [proxy1, em], eo.manyClasses
    assert_equal eo, em.oneClass
    eo.removeManyClasses(proxy1)
    assert_equal [em], eo.manyClasses
    assert_equal eo, em.oneClass
    # displace by proxy
    em.oneClass = proxy2
    assert_equal [], eo.manyClasses
    assert_equal proxy2, em.oneClass
    # displace proxies at one side
    em.oneClass = eo
    assert_equal [em], eo.manyClasses
    assert_equal eo, em.oneClass
  end

  def test_proxies_many_to_many
    e1 = mm::AClassMM.new
    e2 = mm::BClassMM.new
    proxy1 = RGen::MetamodelBuilder::MMProxy.new
    proxy2 = RGen::MetamodelBuilder::MMProxy.new
    e1.addBClasses(proxy1)
    e2.addAClasses(proxy2)
    assert_equal [proxy1], e1.bClasses
    assert_equal [proxy2], e2.aClasses
    e1.addBClasses(e2)
    assert_equal [proxy1, e2], e1.bClasses
    assert_equal [proxy2, e1], e2.aClasses
    e1.removeBClasses(proxy1) 
    e2.removeAClasses(proxy2) 
    assert_equal [e2], e1.bClasses
    assert_equal [e1], e2.aClasses
  end
  
  # Multiplicity agnostic convenience methods

  def test_genericAccess
    e1 = mm::OneClass.new
    e2 = mm::ManyClass.new
    e3 = mm::OneClass.new
    e4 = mm::ManyClass.new
    # use on "many" feature
    e1.setOrAddGeneric("manyClasses", e2)
    assert_equal [e2], e1.manyClasses
    assert_equal [e2], e1.getGeneric("manyClasses")
    assert_equal [e2], e1.getGenericAsArray("manyClasses")
    # use on "one" feature
    e2.setOrAddGeneric("oneClass", e3)
    assert_equal e3, e2.oneClass
    assert_equal e3, e2.getGeneric("oneClass")
    assert_equal [e3], e2.getGenericAsArray("oneClass")
    assert_nil e4.getGeneric("oneClass")
    assert_equal [], e4.getGenericAsArray("oneClass")
  end

  def test_setNilOrRemoveGeneric
    e1 = mm::OneClass.new
    e2 = mm::ManyClass.new
    e3 = mm::OneClass.new
    # use on "many" feature
    e1.addManyClasses(e2)
    assert_equal [e2], e1.manyClasses
    e1.setNilOrRemoveGeneric("manyClasses", e2)
    assert_equal [], e1.manyClasses
    # use on "one" feature
    e2.oneClass = e3
    assert_equal e3, e2.oneClass
    e2.setNilOrRemoveGeneric("oneClass", e3)
    assert_nil e2.oneClass
  end

  def test_setNilOrRemoveAllGeneric
    e1 = mm::OneClass.new
    e2 = mm::ManyClass.new
    e3 = mm::OneClass.new
    e4 = mm::ManyClass.new
    # use on "many" feature
    e1.addManyClasses(e2)
    e1.addManyClasses(e4)
    assert_equal [e2, e4], e1.manyClasses
    e1.setNilOrRemoveAllGeneric("manyClasses")
    assert_equal [], e1.manyClasses
    # use on "one" feature
    e2.oneClass = e3
    assert_equal e3, e2.oneClass
    e2.setNilOrRemoveAllGeneric("oneClass")
    assert_nil e2.oneClass
  end

  def test_abstract
    err = assert_raise StandardError do
      mm::AbstractClass.new
    end
    assert_match /Class (\w+::)+AbstractClass is abstract/, err.message
  end

  module BadDefaultValueLiteralContainer
    Test1 = proc do 
      class BadClass < RGen::MetamodelBuilder::MMBase
        has_attr 'integerWithDefault', Integer, :defaultValueLiteral => "1.1"
      end
    end
    Test2 = proc do 
      class BadClass < RGen::MetamodelBuilder::MMBase
        has_attr 'integerWithDefault', Integer, :defaultValueLiteral => "x"
      end
    end
    Test3 = proc do 
      class BadClass < RGen::MetamodelBuilder::MMBase
        has_attr 'boolWithDefault', Boolean, :defaultValueLiteral => "1"
      end
    end
    Test4 = proc do 
      class BadClass < RGen::MetamodelBuilder::MMBase
        has_attr 'floatWithDefault', Float, :defaultValueLiteral => "1"
      end
    end
    Test5 = proc do 
      class BadClass < RGen::MetamodelBuilder::MMBase
        has_attr 'floatWithDefault', Float, :defaultValueLiteral => "true"
      end
    end
    Test6 = proc do 
      class BadClass < RGen::MetamodelBuilder::MMBase
        kindType = RGen::MetamodelBuilder::DataTypes::Enum.new([:simple, :extended])
        has_attr 'enumWithDefault', kindType, :defaultValueLiteral => "xxx"
      end
    end
    Test7 = proc do 
      class BadClass < RGen::MetamodelBuilder::MMBase
        kindType = RGen::MetamodelBuilder::DataTypes::Enum.new([:simple, :extended])
        has_attr 'enumWithDefault', kindType, :defaultValueLiteral => "7"
      end
    end
    Test8 = proc do 
      class BadClass < RGen::MetamodelBuilder::MMBase
        has_attr 'longWithDefault', Integer, :defaultValueLiteral => "1.1"
      end
    end
  end

  def test_bad_default_value_literal
    err = assert_raise StandardError do
      BadDefaultValueLiteralContainer::Test1.call
    end
    assert_equal "Property integerWithDefault can not take value 1.1, expected an Integer", err.message
    err = assert_raise StandardError do
      BadDefaultValueLiteralContainer::Test2.call
    end
    assert_equal "Property integerWithDefault can not take value x, expected an Integer", err.message
    err = assert_raise StandardError do
      BadDefaultValueLiteralContainer::Test3.call
    end
    assert_equal "Property boolWithDefault can not take value 1, expected true or false", err.message
    err = assert_raise StandardError do
      BadDefaultValueLiteralContainer::Test4.call
    end
    assert_equal "Property floatWithDefault can not take value 1, expected a Float", err.message
    err = assert_raise StandardError do
      BadDefaultValueLiteralContainer::Test5.call
    end
    assert_equal "Property floatWithDefault can not take value true, expected a Float", err.message
    err = assert_raise StandardError do
      BadDefaultValueLiteralContainer::Test6.call
    end
    assert_equal "Property enumWithDefault can not take value xxx, expected one of :simple, :extended", err.message
    err = assert_raise StandardError do
      BadDefaultValueLiteralContainer::Test7.call
    end
    assert_equal "Property enumWithDefault can not take value 7, expected one of :simple, :extended", err.message
    err = assert_raise StandardError do
      BadDefaultValueLiteralContainer::Test8.call
    end
    assert_equal "Property longWithDefault can not take value 1.1, expected an Integer", err.message
  end

  def test_isset_set_to_nil
    e = mm::SimpleClass.new
    assert_respond_to e, :name
    assert !e.eIsSet(:name)
    assert !e.eIsSet("name")
    e.name = nil
    assert e.eIsSet(:name)
  end

  def test_isset_set_to_default
    e = mm::SimpleClass.new
    assert !e.eIsSet(:stringWithDefault)
    # set the default value
    e.name = "xtest"
    assert e.eIsSet(:name)
  end

  def test_isset_many_add
    e = mm::ManyAttrClass.new
    assert_equal [], e.literals
    assert !e.eIsSet(:literals)
    e.addLiterals("x")
    assert e.eIsSet(:literals)
  end

  def test_isset_many_remove
    e = mm::ManyAttrClass.new
    assert_equal [], e.literals
    assert !e.eIsSet(:literals)
    # removing a value which is not there
    e.removeLiterals("x")
    assert e.eIsSet(:literals)
  end

  def test_isset_ref
    ac = mm::AClassOO.new
    bc = mm::BClassOO.new
    assert !bc.eIsSet(:aClass)
    assert !ac.eIsSet(:bClass)
    bc.aClass = ac
    assert bc.eIsSet(:aClass)
    assert ac.eIsSet(:bClass)
  end

  def test_isset_ref_many
    ac = mm::AClassMM.new
    bc = mm::BClassMM.new
    assert !bc.eIsSet(:aClasses)
    assert !ac.eIsSet(:bClasses)
    bc.aClasses = [ac]
    assert bc.eIsSet(:aClasses)
    assert ac.eIsSet(:bClasses)
  end

  def test_unset_nil
    e = mm::SimpleClass.new
    e.name = nil
    assert e.eIsSet(:name)
    e.eUnset(:name)
    assert !e.eIsSet(:name)
  end

  def test_unset_string
    e = mm::SimpleClass.new
    e.name = "someone"
    assert e.eIsSet(:name)
    e.eUnset(:name)
    assert !e.eIsSet(:name)
  end

  def test_unset_ref
    ac = mm::AClassOO.new
    bc = mm::BClassOO.new
    bc.aClass = ac
    assert bc.eIsSet(:aClass)
    assert ac.eIsSet(:bClass)
    assert_equal bc, ac.bClass
    bc.eUnset(:aClass)
    assert_nil bc.aClass
    assert_nil ac.bClass
    assert !bc.eIsSet(:aClass)
    # opposite ref is nil but still "set"
    assert ac.eIsSet(:bClass)
  end

  def test_unset_ref_many
    ac = mm::AClassMM.new
    bc = mm::BClassMM.new
    bc.aClasses = [ac]
    assert bc.eIsSet(:aClasses)
    assert ac.eIsSet(:bClasses)
    assert_equal [bc], ac.bClasses
    bc.eUnset(:aClasses)
    assert_equal [], bc.aClasses
    assert_equal [], ac.bClasses
    assert !bc.eIsSet(:aClasses)
    # opposite ref is empty but still "set"
    assert ac.eIsSet(:bClasses)
  end

  def test_unset_marshal
    e = mm::SimpleClass.new
    e.name = "someone"
    e.eUnset(:name)
    e2 = Marshal.load(Marshal.dump(e))
    assert e.object_id != e2.object_id
    assert !e2.eIsSet(:name)
  end

  def test_conainer_one_uni
    a = mm::ContainerClass.new
    b = mm::ContainedClass.new
    c = mm::ContainedClass.new
    assert_equal [], a.eContents
    assert_equal [], a.eAllContents
    assert_nil b.eContainer
    assert_nil b.eContainingFeature
    a.oneChildUni = b
    assert_equal a, b.eContainer
    assert_equal :oneChildUni, b.eContainingFeature
    assert_equal [b], a.eContents
    assert_equal [b], a.eAllContents
    a.oneChildUni = c
    assert_nil b.eContainer
    assert_nil b.eContainingFeature
    assert_equal a, c.eContainer
    assert_equal :oneChildUni, c.eContainingFeature
    assert_equal [c], a.eContents
    assert_equal [c], a.eAllContents
    a.oneChildUni = nil
    assert_nil c.eContainer
    assert_nil c.eContainingFeature
    assert_equal [], a.eContents
    assert_equal [], a.eAllContents
  end

  def test_container_many_uni
    a = mm::ContainerClass.new
    b = mm::ContainedClass.new
    c = mm::ContainedClass.new
    assert_equal [], a.eContents
    assert_equal [], a.eAllContents
    a.addManyChildUni(b)
    assert_equal a, b.eContainer
    assert_equal :manyChildUni, b.eContainingFeature
    assert_equal [b], a.eContents
    assert_equal [b], a.eAllContents
    a.addManyChildUni(c)
    assert_equal a, c.eContainer
    assert_equal :manyChildUni, c.eContainingFeature
    assert_equal [b, c], a.eContents
    assert_equal [b, c], a.eAllContents
    a.removeManyChildUni(b)
    assert_nil b.eContainer
    assert_nil b.eContainingFeature
    assert_equal a, c.eContainer
    assert_equal :manyChildUni, c.eContainingFeature
    assert_equal [c], a.eContents
    assert_equal [c], a.eAllContents
    a.removeManyChildUni(c)
    assert_nil c.eContainer
    assert_nil c.eContainingFeature
    assert_equal [], a.eContents
    assert_equal [], a.eAllContents
  end

  def test_conainer_one_bi
    a = mm::ContainerClass.new
    b = mm::ContainedClass.new
    c = mm::ContainerClass.new
    d = mm::ContainedClass.new
    a.oneChild = b
    assert_equal a, b.eContainer
    assert_equal :oneChild, b.eContainingFeature
    assert_equal [b], a.eContents
    assert_equal [b], a.eAllContents
    c.oneChild = d 
    assert_equal c, d.eContainer
    assert_equal :oneChild, d.eContainingFeature
    assert_equal [d], c.eContents
    assert_equal [d], c.eAllContents
    a.oneChild = d
    assert_nil b.eContainer
    assert_nil b.eContainingFeature
    assert_equal a, d.eContainer
    assert_equal :oneChild, d.eContainingFeature
    assert_equal [d], a.eContents
    assert_equal [d], a.eAllContents
    assert_equal [], c.eContents
    assert_equal [], c.eAllContents
  end

  def test_conainer_one_bi_rev
    a = mm::ContainerClass.new
    b = mm::ContainedClass.new
    c = mm::ContainerClass.new
    d = mm::ContainedClass.new
    a.oneChild = b
    assert_equal a, b.eContainer
    assert_equal :oneChild, b.eContainingFeature
    assert_equal [b], a.eContents
    assert_equal [b], a.eAllContents
    c.oneChild = d 
    assert_equal c, d.eContainer
    assert_equal :oneChild, d.eContainingFeature
    assert_equal [d], c.eContents
    assert_equal [d], c.eAllContents
    d.parentOne = a
    assert_nil b.eContainer
    assert_nil b.eContainingFeature
    assert_equal a, d.eContainer
    assert_equal :oneChild, d.eContainingFeature
    assert_equal [d], a.eContents
    assert_equal [d], a.eAllContents
    assert_equal [], c.eContents
    assert_equal [], c.eAllContents
  end

  def test_conainer_one_bi_nil
    a = mm::ContainerClass.new
    b = mm::ContainedClass.new
    a.oneChild = b
    assert_equal a, b.eContainer
    assert_equal :oneChild, b.eContainingFeature
    assert_equal [b], a.eContents
    assert_equal [b], a.eAllContents
    a.oneChild = nil 
    assert_nil b.eContainer
    assert_nil b.eContainingFeature
    assert_equal [], a.eContents
    assert_equal [], a.eAllContents
  end

  def test_conainer_one_bi_nil_rev
    a = mm::ContainerClass.new
    b = mm::ContainedClass.new
    a.oneChild = b
    assert_equal a, b.eContainer
    assert_equal :oneChild, b.eContainingFeature
    assert_equal [b], a.eContents
    assert_equal [b], a.eAllContents
    b.parentOne = nil 
    assert_nil b.eContainer
    assert_nil b.eContainingFeature
    assert_equal [], a.eContents
    assert_equal [], a.eAllContents
  end

  def test_container_many_bi
    a = mm::ContainerClass.new
    b = mm::ContainedClass.new
    c = mm::ContainedClass.new
    a.addManyChild(b)
    a.addManyChild(c)
    assert_equal a, b.eContainer
    assert_equal :manyChild, b.eContainingFeature
    assert_equal a, c.eContainer
    assert_equal :manyChild, c.eContainingFeature
    assert_equal [b, c], a.eContents
    assert_equal [b, c], a.eAllContents
    a.removeManyChild(b)
    assert_nil b.eContainer
    assert_nil b.eContainingFeature
    assert_equal [c], a.eContents
    assert_equal [c], a.eAllContents
  end

  def test_conainer_many_bi_steal
    a = mm::ContainerClass.new
    b = mm::ContainedClass.new
    c = mm::ContainedClass.new
    d = mm::ContainerClass.new
    a.addManyChild(b)
    a.addManyChild(c)
    assert_equal a, b.eContainer
    assert_equal :manyChild, b.eContainingFeature
    assert_equal a, c.eContainer
    assert_equal :manyChild, c.eContainingFeature
    assert_equal [b, c], a.eContents
    assert_equal [b, c], a.eAllContents
    d.addManyChild(b)
    assert_equal d, b.eContainer
    assert_equal :manyChild, b.eContainingFeature
    assert_equal [c], a.eContents
    assert_equal [c], a.eAllContents
    assert_equal [b], d.eContents
    assert_equal [b], d.eAllContents
  end

  def test_conainer_many_bi_steal_rev
    a = mm::ContainerClass.new
    b = mm::ContainedClass.new
    c = mm::ContainedClass.new
    d = mm::ContainerClass.new
    a.addManyChild(b)
    a.addManyChild(c)
    assert_equal a, b.eContainer
    assert_equal :manyChild, b.eContainingFeature
    assert_equal a, c.eContainer
    assert_equal :manyChild, c.eContainingFeature
    assert_equal [b, c], a.eContents
    assert_equal [b, c], a.eAllContents
    b.parentMany = d
    assert_equal d, b.eContainer
    assert_equal :manyChild, b.eContainingFeature
    assert_equal [c], a.eContents
    assert_equal [c], a.eAllContents
    assert_equal [b], d.eContents
    assert_equal [b], d.eAllContents
  end

  def test_all_contents
    a = mm::ContainerClass.new
    b = mm::NestedContainerClass.new
    c = mm::ContainedClass.new
    a.oneChildUni = b
    b.oneChildUni = c
    assert_equal [b, c], a.eAllContents
  end

  def test_all_contents_with_block
    a = mm::ContainerClass.new
    b = mm::NestedContainerClass.new
    c = mm::ContainedClass.new
    a.oneChildUni = b
    b.oneChildUni = c
    yielded = []
    a.eAllContents do |e|
      yielded << e
    end
    assert_equal [b, c], yielded
  end

  def test_all_contents_prune
    a = mm::ContainerClass.new
    b = mm::NestedContainerClass.new
    c = mm::ContainedClass.new
    a.oneChildUni = b
    b.oneChildUni = c
    yielded = []
    a.eAllContents do |e|
      yielded << e
      :prune
    end
    assert_equal [b], yielded
  end

  def test_container_generic
    a = mm::ContainerClass.new
    assert_nothing_raised do
      a.oneChild = RGen::MetamodelBuilder::MMGeneric.new
    end
  end

  def test_opposite_assoc_on_first_write
    ac = mm::OppositeRefAssocA.new
    bc = mm::OppositeRefAssocB.new

    # no access to 'aClass' or 'bClass' methods before
    # test if on-demand metamodel building creates opposite ref association on first write
    bc.aClass = ac
    assert_equal ac, bc.aClass
    assert_equal bc, ac.bClass
  end

  def test_clear_by_array_assignment
    oc1 = mm::OneClass.new
    mc1 = mm::ManyClass.new  	
    mc2 = mm::ManyClass.new  	
    mc3 = mm::ManyClass.new  	
    
    oc1.manyClasses = [mc1, mc2]
    assert_equal [mc1, mc2], oc1.manyClasses
    oc1.manyClasses = []
    assert_equal [], oc1.manyClasses
	end

  def test_clear_by_array_assignment_uni
    a = mm::ContainerClass.new
    b = mm::ContainedClass.new
    c = mm::ContainedClass.new

    a.manyChildUni = [b, c]
    assert_equal [b, c], a.manyChildUni
    a.manyChildUni = []
    assert_equal [], a.manyChildUni
  end

  def test_disconnectContainer_one_uni
    a = mm::ContainerClass.new
    b = mm::ContainedClass.new
    a.oneChildUni = b
    b.disconnectContainer
    assert_nil a.oneChildUni
  end

  def test_disconnectContainer_one
    a = mm::ContainerClass.new
    b = mm::ContainedClass.new
    a.oneChild = b
    b.disconnectContainer
    assert_nil a.oneChild
    assert_nil b.parentOne
  end

  def test_disconnectContainer_many_uni
    a = mm::ContainerClass.new
    b = mm::ContainedClass.new
    c = mm::ContainedClass.new
    a.addManyChildUni(b)
    a.addManyChildUni(c)
    b.disconnectContainer
    assert_equal [c], a.manyChildUni
  end

  def test_disconnectContainer_many
    a = mm::ContainerClass.new
    b = mm::ContainedClass.new
    c = mm::ContainedClass.new
    a.addManyChild(b)
    a.addManyChild(c)
    b.disconnectContainer
    assert_nil b.parentMany
    assert_equal [c], a.manyChild
  end

  # Duplicate Containment Tests
  #
  # Testing that no element is contained in two different containers at a time.
  # This must also work for uni-directional containments as well as
  # for containments via different roles.

  # here the bi-dir reference disconnects from the previous container
  def test_duplicate_containment_bidir_samerole_one
    a1 = mm::ContainerClass.new
    a2 = mm::ContainerClass.new
    b = mm::ContainedClass.new
    a1.oneChild = b
    a2.oneChild = b
    assert_nil a1.oneChild
  end

  # here the bi-dir reference disconnects from the previous container
  def test_duplicate_containment_bidir_samerole_many
    a1 = mm::ContainerClass.new
    a2 = mm::ContainerClass.new
    b = mm::ContainedClass.new
    a1.addManyChild(b)
    a2.addManyChild(b)
    assert_equal [], a1.manyChild
  end

  def test_duplicate_containment_unidir_samerole_one
    a1 = mm::ContainerClass.new
    a2 = mm::ContainerClass.new
    b = mm::ContainedClass.new
    a1.oneChildUni = b
    a2.oneChildUni = b
    assert_nil a1.oneChildUni
  end

  def test_duplicate_containment_unidir_samerole_many
    a1 = mm::ContainerClass.new
    a2 = mm::ContainerClass.new
    b = mm::ContainedClass.new
    a1.addManyChildUni(b)
    a2.addManyChildUni(b)
    assert_equal [], a1.manyChildUni
  end

  def test_duplicate_containment_bidir_otherrole_one
    a1 = mm::ContainerClass.new
    a2 = mm::ContainerClass.new
    b = mm::ContainedClass.new
    a1.oneChild = b
    a2.oneChild2 = b
    assert_nil a1.oneChild
  end

  def test_duplicate_containment_bidir_otherrole_many
    a1 = mm::ContainerClass.new
    a2 = mm::ContainerClass.new
    b = mm::ContainedClass.new
    a1.addManyChild(b)
    a2.addManyChild2(b)
    assert_equal [], a1.manyChild
  end

  def test_duplicate_containment_unidir_otherrole_one
    a1 = mm::ContainerClass.new
    a2 = mm::ContainerClass.new
    b = mm::ContainedClass.new
    a1.oneChildUni = b
    a2.oneChildUni2 = b
    assert_nil a1.oneChildUni
  end

  def test_duplicate_containment_unidir_otherrole_many
    a1 = mm::ContainerClass.new
    a2 = mm::ContainerClass.new
    b = mm::ContainedClass.new
    a1.addManyChildUni(b)
    a2.addManyChildUni2(b)
    assert_equal [], a1.manyChildUni
  end

end
