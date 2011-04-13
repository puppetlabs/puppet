#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Parser::AST::Hostclass do
  def ast
    Puppet::Parser::AST
  end

  def newarray(*elems)
    ast::ASTArray.new({}).push(*elems)
  end

  it "should make its name and context available through accessors" do
    hostclass = ast::Hostclass.new('foo', :line => 5)
    hostclass.name.should == 'foo'
    hostclass.context.should == {:line => 5}
  end

  it "should make its code available through an accessor" do
    code = newarray
    hostclass = ast::Hostclass.new('foo', :code => code)
    hostclass.code.should be_equal(code)
  end

  describe "when instantiated" do
    it "should create a class with the proper type, code, name, context, and module name" do
      code = newarray
      hostclass = ast::Hostclass.new('foo', :code => code, :line => 5)
      instantiated_class = hostclass.instantiate('modname')[0]
      instantiated_class.type.should == :hostclass
      instantiated_class.name.should == 'foo'
      instantiated_class.code.should be_equal(code)
      instantiated_class.line.should == 5
      instantiated_class.module_name.should == 'modname'
    end

    it "should instantiate all nested classes, defines, and nodes with the same module name." do
      nested_objects = newarray(ast::Hostclass.new('foo::child1'),
                                ast::Definition.new('foo::child2'),
                                ast::Definition.new('child3'))
      hostclass = ast::Hostclass.new('foo', :code => nested_objects)
      instantiated_classes = hostclass.instantiate('modname')
      instantiated_classes.length.should == 4
      instantiated_classes[0].name.should == 'foo'
      instantiated_classes[1].name.should == 'foo::child1'
      instantiated_classes[2].name.should == 'foo::child2'
      instantiated_classes[3].name.should == 'child3'
      instantiated_classes.each { |cls| cls.module_name.should == 'modname' }
    end

    it "should handle a nested class that contains its own nested classes." do
      foo_bar_baz = ast::Hostclass.new('foo::bar::baz')
      foo_bar = ast::Hostclass.new('foo::bar', :code => newarray(foo_bar_baz))
      foo = ast::Hostclass.new('foo', :code => newarray(foo_bar))
      instantiated_classes = foo.instantiate('')
      instantiated_classes.length.should == 3
      instantiated_classes[0].name.should == 'foo'
      instantiated_classes[1].name.should == 'foo::bar'
      instantiated_classes[2].name.should == 'foo::bar::baz'
    end

    it "should skip nested elements that are not classes, definitions, or nodes." do
      func = ast::Function.new(:name => 'biz', :arguments => newarray(ast::Name.new(:value => 'baz')))
      foo = ast::Hostclass.new('foo', :code => newarray(func))
      instantiated_classes = foo.instantiate('')
      instantiated_classes.length.should == 1
      instantiated_classes[0].should be_a(Puppet::Resource::Type)
      instantiated_classes[0].name.should == 'foo'
    end
  end
end

