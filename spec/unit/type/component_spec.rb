#!/usr/bin/env rspec
require 'spec_helper'

component = Puppet::Type.type(:component)

describe component do
  it "should have a :name attribute" do
    component.attrclass(:name).should_not be_nil
  end

  it "should use Class as its type when a normal string is provided as the title" do
    component.new(:name => "bar").ref.should == "Class[Bar]"
  end

  it "should always produce a resource reference string as its title" do
    component.new(:name => "bar").title.should == "Class[Bar]"
  end

  it "should have a reference string equivalent to its title" do
    comp = component.new(:name => "Foo[bar]")
    comp.title.should == comp.ref
  end

  it "should alias itself to its reference if it has a catalog and the catalog does not already have a resource with the same reference" do
    catalog = mock 'catalog'
    catalog.expects(:resource).with("Foo[bar]").returns nil

    catalog.expects(:alias).with { |resource, name| resource.is_a?(component) and name == "Foo[bar]" }

    component.new(:name => "Foo[bar]", :catalog => catalog)
  end

  it "should not fail when provided an invalid value" do
    comp = component.new(:name => "Foo[bar]")
    lambda { comp[:yayness] = "ey" }.should_not raise_error
  end

  it "should return previously provided invalid values" do
    comp = component.new(:name => "Foo[bar]")
    comp[:yayness] = "eh"
    comp[:yayness].should == "eh"
  end

  it "should correctly support metaparameters" do
    comp = component.new(:name => "Foo[bar]", :require => "Foo[bar]")
    comp.parameter(:require).should be_instance_of(component.attrclass(:require))
  end

  describe "when building up the path" do
    it "should produce the class name if the component models a class" do
      component.new(:name => "Class[foo]").pathbuilder.must == ["Foo"]
    end

    it "should produce an empty string if the component models the 'main' class" do
      component.new(:name => "Class[main]").pathbuilder.must == [""]
    end

    it "should produce a resource reference if the component does not model a class" do
      component.new(:name => "Foo[bar]").pathbuilder.must == ["Foo[bar]"]
    end
  end
end
