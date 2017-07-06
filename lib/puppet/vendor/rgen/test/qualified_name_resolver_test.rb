$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/metamodel_builder'
require 'rgen/instantiator/qualified_name_resolver'

class QualifiedNameResolverTest < Test::Unit::TestCase

  class TestNode < RGen::MetamodelBuilder::MMBase
    has_attr 'name', String
    has_one 'nextSibling', TestNode
    contains_many 'children', TestNode, "parent"
  end

  class TestNode2 < RGen::MetamodelBuilder::MMBase
    has_attr 'cname', String
    has_one 'nextSibling', TestNode2
    contains_many 'children', TestNode2, "parent"
  end

  class TestNode3 < RGen::MetamodelBuilder::MMBase
    has_attr 'name', String
    contains_one 'child', TestNode3, "parent"
  end

  def testModel
    [TestNode.new(:name => "Root1", :children => [
      TestNode.new(:name => "Sub11"),
      TestNode.new(:name => "Sub12", :children => [
        TestNode.new(:name => "Sub121")])]),
     TestNode.new(:name => "Root2", :children => [
      TestNode.new(:name => "Sub21", :children => [
        TestNode.new(:name => "Sub211")])]),
     TestNode.new(:name => "Root3"),
     TestNode.new(:name => "Root3")
     ]
  end

  def testModel2
    [TestNode2.new(:cname => "Root1", :children => [
      TestNode2.new(:cname => "Sub11")])]
  end

  def testModel3
    [TestNode3.new(:name => "Root1", :child =>
      TestNode3.new(:name => "Sub11", :child =>
        TestNode3.new(:name => "Sub111")))]
  end

  def test_customNameAttribute
    model = testModel2
    res = RGen::Instantiator::QualifiedNameResolver.new(model, :nameAttribute => "cname")
    assert_equal model[0], res.resolveIdentifier("/Root1")
    assert_equal model[0].children[0], res.resolveIdentifier("/Root1/Sub11")
  end

  def test_customSeparator
    model = testModel
    res = RGen::Instantiator::QualifiedNameResolver.new(model, :separator => "|")
    assert_equal model[0], res.resolveIdentifier("|Root1")
    assert_nil res.resolveIdentifier("/Root1")
    assert_equal model[0].children[0], res.resolveIdentifier("|Root1|Sub11")
  end

  def test_noLeadingSeparator
    model = testModel
    res = RGen::Instantiator::QualifiedNameResolver.new(model, :leadingSeparator => false)
    assert_equal model[0], res.resolveIdentifier("Root1")
    assert_nil res.resolveIdentifier("/Root1")
    assert_equal model[0].children[0], res.resolveIdentifier("Root1/Sub11")
  end
    
	def test_resolve
    model = testModel
    res = RGen::Instantiator::QualifiedNameResolver.new(model)
    assert_equal model[0], res.resolveIdentifier("/Root1")
    # again
    assert_equal model[0], res.resolveIdentifier("/Root1")
    assert_equal model[0].children[0], res.resolveIdentifier("/Root1/Sub11")
    # again
    assert_equal model[0].children[0], res.resolveIdentifier("/Root1/Sub11")
    assert_equal model[0].children[1], res.resolveIdentifier("/Root1/Sub12")
    assert_equal model[0].children[1].children[0], res.resolveIdentifier("/Root1/Sub12/Sub121")
    assert_equal model[1], res.resolveIdentifier("/Root2")
    assert_equal model[1].children[0], res.resolveIdentifier("/Root2/Sub21")
    assert_equal model[1].children[0].children[0], res.resolveIdentifier("/Root2/Sub21/Sub211")
    # duplicate name yields two result elements
    assert_equal [model[2], model[3]], res.resolveIdentifier("/Root3")
    assert_equal nil, res.resolveIdentifier("/RootX")
    assert_equal nil, res.resolveIdentifier("/Root1/SubX")
  end

  def test_oneChild
    model = testModel3
    res = RGen::Instantiator::QualifiedNameResolver.new(model)
    assert_equal model[0], res.resolveIdentifier("/Root1")
    assert_equal model[0].child, res.resolveIdentifier("/Root1/Sub11")
    assert_equal model[0].child.child, res.resolveIdentifier("/Root1/Sub11/Sub111")
  end

end

