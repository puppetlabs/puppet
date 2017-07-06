$:.unshift(File.dirname(__FILE__)+"/../../lib")

require 'test/unit'
require 'rgen/environment'
require 'rgen/metamodel_builder'
require 'rgen/model_builder'
require 'rgen/util/pattern_matcher'

class PatternMatcherTest < Test::Unit::TestCase

module TestMM
  extend RGen::MetamodelBuilder::ModuleExtension

  class Node < RGen::MetamodelBuilder::MMBase
    has_attr 'name', String
    contains_many 'children', Node, 'parent'
  end
end

def modelA 
  env = RGen::Environment.new
  RGen::ModelBuilder.build(TestMM, env) do 
    node "A" do
      node "AA"
    end
    node "B" do
      node "B1"
      node "B2"
      node "B3"
    end
    node "C" do
      node "C1"
      node "C2"
    end
    node "D" do
      node "DD"
    end
  end
  env
end

def test_simple
  matcher = RGen::Util::PatternMatcher.new
  matcher.add_pattern("simple") do |env, c|
    TestMM::Node.new(:name => "A", :children => [
      TestMM::Node.new(:name => "AA")])
  end
  matcher.add_pattern("bad") do |env, c|
    TestMM::Node.new(:name => "X")
  end
  env = modelA

  match = matcher.find_pattern(env, "simple")
  assert_not_nil match
  assert_equal "A", match.root.name
  assert_equal env.find(:class => TestMM::Node, :name => "A").first.object_id, match.root.object_id
  assert_equal 2, match.elements.size
  assert_equal [nil], match.bound_values

  assert_nil matcher.find_pattern(env, "bad")
end

def test_value_binding
  matcher = RGen::Util::PatternMatcher.new
  matcher.add_pattern("single_child") do |env, name, child|
    TestMM::Node.new(:name => name, :children => [ child ])
  end
  matcher.add_pattern("double_child") do |env, name, child1, child2|
    TestMM::Node.new(:name => name, :children => [ child1, child2 ])
  end
  matcher.add_pattern("child_pattern") do |env, child_name|
    TestMM::Node.new(:name => "A", :children => [
      TestMM::Node.new(:name => child_name)])
  end
  env = modelA

  match = matcher.find_pattern(env, "single_child")
  assert_not_nil match
  assert_equal "A", match.root.name
  assert_equal "AA", match.bound_values[1].name

  match = matcher.find_pattern(env, "single_child", "D")
  assert_not_nil match
  assert_equal "D", match.root.name
  assert_equal "DD", match.bound_values[0].name

  match = matcher.find_pattern(env, "double_child")
  assert_not_nil match
  assert_equal "C", match.root.name

  match = matcher.find_pattern(env, "child_pattern")
  assert_not_nil match
  assert_equal ["AA"], match.bound_values
end

end

