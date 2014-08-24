$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/array_extensions'

class ArrayExtensionsTest < Test::Unit::TestCase

  def test_element_methods
    c = Struct.new("SomeClass",:name,:age)
    a = []
    a << c.new('MyName',33)
    a << c.new('YourName',22)
    assert_equal ["MyName", "YourName"], a >> :name
    assert_raise NoMethodError do
      a.name
    end
    assert_equal [33, 22], a>>:age
    assert_raise NoMethodError do
      a.age
    end
    # unfortunately, any method can be called on an empty array
    assert_equal [], [].age
  end
  
  class MMBaseClass < RGen::MetamodelBuilder::MMBase
    has_attr 'name'
    has_attr 'age', Integer
  end
  
  def test_with_mmbase
    e1 = MMBaseClass.new
    e1.name = "MyName"
    e1.age = 33
    e2 = MMBaseClass.new
    e2.name = "YourName"
    e2.age = 22
    a = [e1, e2]
    assert_equal ["MyName", "YourName"], a >> :name
    assert_equal ["MyName", "YourName"], a.name
    assert_equal [33, 22], a>>:age
    assert_equal [33, 22], a.age
    # put something into the array that is not an MMBase
    a << "not a MMBase"
    # the dot operator will tell that there is something not a MMBase
    assert_raise StandardError do
      a.age
    end
    # the >> operator will try to call the method anyway
    assert_raise NoMethodError do
      a >> :age
    end
  end

  def test_hash_square
    assert_equal({}, Hash[[]])
  end

  def test_to_str_on_empty_array
    assert_raise NoMethodError do
      [].to_str
    end
  end
  
end
