$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/metamodel_builder'
require 'rgen/serializer/qualified_name_provider'

class QualifiedNameProviderTest < Test::Unit::TestCase

  class AbstractTestNode < RGen::MetamodelBuilder::MMBase
    contains_many 'children', AbstractTestNode, "parent"
  end

  class NamedNode < AbstractTestNode
    has_attr 'n', String
  end

  class UnnamedNode < AbstractTestNode
  end

  def test_simple
    root = NamedNode.new(:n => "root", :children => [
      NamedNode.new(:n => "a", :children => [
        NamedNode.new(:n => "a1")
      ]),
      UnnamedNode.new(:children => [
        NamedNode.new(:n => "b1")
      ])
    ])

    qnp = RGen::Serializer::QualifiedNameProvider.new(:attribute_name => "n")

    assert_equal "/root", qnp.identifier(root)
    assert_equal "/root/a", qnp.identifier(root.children[0])
    assert_equal "/root/a/a1", qnp.identifier(root.children[0].children[0])
    assert_equal "/root", qnp.identifier(root.children[1])
    assert_equal "/root/b1", qnp.identifier(root.children[1].children[0])
  end

  def test_unnamed_root
    root = UnnamedNode.new

    qnp = RGen::Serializer::QualifiedNameProvider.new(:attribute_name => "n")

    assert_equal "/", qnp.identifier(root)
  end

end

