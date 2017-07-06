$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/metamodel_builder'
require 'rgen/fragment/model_fragment'

class ModelFragmentTest < Test::Unit::TestCase

module TestMetamodel
  extend RGen::MetamodelBuilder::ModuleExtension

  class SimpleClass < RGen::MetamodelBuilder::MMBase
    has_attr 'name', String
    contains_many 'subclass', SimpleClass, 'parent'
  end
end

def test_elements
  root = TestMetamodel::SimpleClass.new(:name => "parent",
    :subclass => [TestMetamodel::SimpleClass.new(:name => "child")])
  
  frag = RGen::Fragment::ModelFragment.new("location")
  frag.set_root_elements([root])

  assert_equal 2, frag.elements.size
end

end


