require 'spec_helper'
require 'pops/impl/type_creator'

describe Pops::Impl::TypeCreator do
  it "should create a package" do
    tc = Pops::Impl::TypeCreator.new
    result = tc.test_create_type()

    #    result = tc.example_using_ModelBuilder
    result.class.should == Class

    x = result.new
    x.attr1 = 'hello'
    #puts "x.attr1 = #{x.attr1}"
    #puts "The name of the Class is #{x.class}"

    eclass = result.ecore
    #puts "got eclass as a #{eclass}, an #{eclass.class}"
    result2 = tc.test_create_type2 eclass
    y = result2.new
    y.attr1 = 'check'
    y.attr2 = 'check again'
    y.attr1.should == 'check'

    x.class.name.should == "Pops::Impl::Types::TestClass1"
    y.class.name.should == "Pops::Impl::Types::TestClass2"
    Pops::Impl.const_defined?(:Types).should == false

    #puts "TestClass2 anscestors: " + y.class.ancestors.join(", ")
    pending "TypeCreator - should create a package is unfinished"
  end
  # TODO: More things to test - see aboce for ideas
end
