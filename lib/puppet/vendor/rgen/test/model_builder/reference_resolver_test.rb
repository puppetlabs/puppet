$:.unshift File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'rgen/metamodel_builder'
require 'rgen/model_builder/reference_resolver'

class ReferenceResolverTest < Test::Unit::TestCase

  class ClassA < RGen::MetamodelBuilder::MMBase
    has_attr "name"
  end
  
  class ClassB < RGen::MetamodelBuilder::MMBase
    has_attr "name"
  end

  class ClassC < RGen::MetamodelBuilder::MMBase
    has_attr "name"
  end

  ClassA.contains_many 'childB', ClassB, 'parentA'
  ClassB.contains_many 'childC', ClassC, 'parentB'
  ClassA.has_one 'refC', ClassC
  ClassB.has_one 'refC', ClassC
  ClassC.has_many 'refCs', ClassC
  ClassC.has_one 'refA', ClassA
  ClassC.has_one 'refB', ClassB
  
  def testModel
    a1 = ClassA.new(:name => "a1")
    a2 = ClassA.new(:name => "a2")
    b1 = ClassB.new(:name => "b1", :parentA => a1)
    b2 = ClassB.new(:name => "b2", :parentA => a1)
    c1 = ClassC.new(:name => "c1", :parentB => b1)
    c2 = ClassC.new(:name => "c2", :parentB => b1)
    c3 = ClassC.new(:name => "c3", :parentB => b1)
    [a1, a2, b1, b2, c1, c2, c3]
  end
  
  def setElementNames(resolver, elements)
    elements.each do |e|
      resolver.setElementName(e, e.name)
    end
  end
  
  def createJob(hash)
    raise "Invalid arguments" unless \
      hash.is_a?(Hash) && (hash.keys & [:receiver, :reference, :namespace, :string]).size == 4
    RGen::ModelBuilder::ReferenceResolver::ResolverJob.new(
      hash[:receiver], hash[:reference], hash[:namespace], hash[:string])
  end
  
  def test_resolve_same_namespace
    a1, a2, b1, b2, c1, c2, c3 = testModel    
    
    toplevelNamespace = [a1, a2]
    resolver = RGen::ModelBuilder::ReferenceResolver.new
    setElementNames(resolver, [a1, a2, b1, b2, c1, c2, c3])
    resolver.addJob(createJob(
      :receiver => c2,
      :reference => ClassC.ecore.eReferences.find{|r| r.name == "refCs"},
      :namespace => b1,
      :string => "c1"))
    resolver.addJob(createJob(
      :receiver => b2,
      :reference => ClassB.ecore.eReferences.find{|r| r.name == "refC"},
      :namespace => a1,
      :string => "b1.c1"))
    resolver.addJob(createJob(
      :receiver => a2,
      :reference => ClassA.ecore.eReferences.find{|r| r.name == "refC"},
      :namespace => nil,
      :string => "a1.b1.c1"))
    resolver.resolve(toplevelNamespace)
    
    assert_equal [c1], c2.refCs
    assert_equal c1, b2.refC
    assert_equal c1, a2.refC
  end

  def test_resolve_parent_namespace
    a1, a2, b1, b2, c1, c2, c3 = testModel    
    
    toplevelNamespace = [a1, a2]
    resolver = RGen::ModelBuilder::ReferenceResolver.new
    setElementNames(resolver, [a1, a2, b1, b2, c1, c2, c3])
    resolver.addJob(createJob(
      :receiver => c2,
      :reference => ClassC.ecore.eReferences.find{|r| r.name == "refA"},
      :namespace => b1,
      :string => "a1"))
    resolver.addJob(createJob(
      :receiver => c2,
      :reference => ClassC.ecore.eReferences.find{|r| r.name == "refB"},
      :namespace => b1,
      :string => "b1"))
    resolver.addJob(createJob(
      :receiver => c2,
      :reference => ClassC.ecore.eReferences.find{|r| r.name == "refCs"},
      :namespace => b1,
      :string => "b1.c1"))
    resolver.addJob(createJob(
      :receiver => c2,
      :reference => ClassC.ecore.eReferences.find{|r| r.name == "refCs"},
      :namespace => b1,
      :string => "a1.b1.c3"))
    resolver.resolve(toplevelNamespace)
    
    assert_equal a1, c2.refA
    assert_equal b1, c2.refB
    assert_equal [c1, c3], c2.refCs
  end
  
  def test_resolve_faulty
    a1, a2, b1, b2, c1, c2, c3 = testModel    
    
    toplevelNamespace = [a1, a2]
    resolver = RGen::ModelBuilder::ReferenceResolver.new
    setElementNames(resolver, [a1, a2, b1, b2, c1, c2, c3])
    resolver.addJob(createJob(
      :receiver => c2,
      :reference => ClassC.ecore.eReferences.find{|r| r.name == "refCs"},
      :namespace => b1,
      :string => "b1.c5"))
    assert_raise RGen::ModelBuilder::ReferenceResolver::ResolverException do
      resolver.resolve(toplevelNamespace)
    end
  end
      
  def test_ambiguous_prefix
    a = ClassA.new(:name => "name1")
    b1 = ClassB.new(:name => "name1", :parentA => a)
    b2 = ClassB.new(:name => "target", :parentA => a)
    c1 = ClassC.new(:name => "name21", :parentB => b1)
    c2 = ClassC.new(:name => "name22", :parentB => b1)
    
    toplevelNamespace = [a]
    resolver = RGen::ModelBuilder::ReferenceResolver.new
    setElementNames(resolver, [a, b1, b2, c1, c2])
    resolver.addJob(createJob(
      :receiver => c2,
      :reference => ClassC.ecore.eReferences.find{|r| r.name == "refCs"},
      :namespace => b1,
      :string => "name1.name1.name21"))
    resolver.addJob(createJob(
      :receiver => c2,
      :reference => ClassC.ecore.eReferences.find{|r| r.name == "refB"},
      :namespace => b1,
      :string => "name1.target"))
    resolver.resolve(toplevelNamespace)
    
    assert_equal [c1], c2.refCs
    assert_equal b2, c2.refB
  end

end