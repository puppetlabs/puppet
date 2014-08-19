$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/metamodel_builder'
require 'rgen/instantiator/reference_resolver'

class ReferenceResolverTest < Test::Unit::TestCase

  class TestNode < RGen::MetamodelBuilder::MMBase
    has_attr 'name', String
    has_one 'other', TestNode
    has_many 'others', TestNode
  end

  class TestNode2 < RGen::MetamodelBuilder::MMBase
    has_attr 'name', String
  end

  def test_identifier_resolver
    nodeA, nodeB, nodeC, unresolved_refs = create_model
    resolver = RGen::Instantiator::ReferenceResolver.new(
      :identifier_resolver => proc do |ident|
        {:a => nodeA, :b => nodeB, :c => nodeC}[ident]
      end)
    urefs = resolver.resolve(unresolved_refs)
    check_model(nodeA, nodeB, nodeC)
    assert urefs.empty?
  end

  def test_add_identifier
    nodeA, nodeB, nodeC, unresolved_refs = create_model
    resolver = RGen::Instantiator::ReferenceResolver.new
    resolver.add_identifier(:a, nodeA)
    resolver.add_identifier(:b, nodeB)
    resolver.add_identifier(:c, nodeC)
    urefs = resolver.resolve(unresolved_refs)
    check_model(nodeA, nodeB, nodeC)
    assert urefs.empty?
  end

  def test_problems
    nodeA, nodeB, nodeC, unresolved_refs = create_model
    resolver = RGen::Instantiator::ReferenceResolver.new(
      :identifier_resolver => proc do |ident|
        {:a => [nodeA, nodeB], :c => nodeC}[ident]
      end)
    problems = []
    urefs = resolver.resolve(unresolved_refs, :problems => problems)
    assert_equal ["identifier b not found", "identifier a not uniq"], problems
    assert_equal 2, urefs.size
    assert urefs.all?{|ur| !ur.target_type_error}
  end

  def test_on_resolve_proc
    nodeA, nodeB, nodeC, unresolved_refs = create_model
    resolver = RGen::Instantiator::ReferenceResolver.new
    resolver.add_identifier(:a, nodeA)
    resolver.add_identifier(:b, nodeB)
    resolver.add_identifier(:c, nodeC)
    data = []
    resolver.resolve(unresolved_refs, 
      :on_resolve => proc {|ur, e| data << [ ur, e ]})
    assert data[0][0].is_a?(RGen::Instantiator::ReferenceResolver::UnresolvedReference)
    assert_equal nodeA, data[0][0].element 
    assert_equal "other", data[0][0].feature_name 
    assert_equal :b, data[0][0].proxy.targetIdentifier 
    assert_equal nodeB, data[0][1]
  end

  def test_target_type_error
    nodeA, nodeB, nodeC, unresolved_refs = create_model
    resolver = RGen::Instantiator::ReferenceResolver.new(
      :identifier_resolver => proc do |ident|
        {:a => TestNode2.new, :b => TestNode2.new, :c => nodeC}[ident]
      end)
    problems = []
    urefs = resolver.resolve(unresolved_refs, :problems => problems)
    assert_equal 2, problems.size
    assert problems[0] =~ /invalid target type .*TestNode2/
    assert problems[1] =~ /invalid target type .*TestNode2/
    assert_equal 2, urefs.uniq.size
    assert urefs[0].target_type_error
    assert urefs[1].target_type_error
    assert urefs.any?{|ur| ur.proxy.object_id == nodeA.other.object_id}
    assert urefs.any?{|ur| ur.proxy.object_id == nodeB.others[0].object_id}
  end

  private

  def create_model
    nodeA = TestNode.new(:name => "NodeA")
    nodeB = TestNode.new(:name => "NodeB")
    nodeC = TestNode.new(:name => "NodeC")
    bProxy = RGen::MetamodelBuilder::MMProxy.new(:b) 
    nodeA.other = bProxy 
    aProxy = RGen::MetamodelBuilder::MMProxy.new(:a) 
    cProxy = RGen::MetamodelBuilder::MMProxy.new(:c) 
    nodeB.others = [aProxy, cProxy] 
    unresolved_refs = [
      RGen::Instantiator::ReferenceResolver::UnresolvedReference.new(nodeA, "other", bProxy),
      RGen::Instantiator::ReferenceResolver::UnresolvedReference.new(nodeB, "others", aProxy),
      RGen::Instantiator::ReferenceResolver::UnresolvedReference.new(nodeB, "others", cProxy)
    ]
    return nodeA, nodeB, nodeC, unresolved_refs
  end

  def check_model(nodeA, nodeB, nodeC)
    assert_equal nodeB, nodeA.other
    assert_equal [], nodeA.others
    assert_equal nil, nodeB.other
    assert_equal [nodeA, nodeC], nodeB.others
    assert_equal nil, nodeC.other
    assert_equal [], nodeC.others
  end

end
 
