#! /usr/bin/env ruby
require 'spec_helper'

component = Puppet::Type.type(:component)

describe component do
  it "should have a :name attribute" do
    expect(component.attrclass(:name)).not_to be_nil
  end

  it "should use Class as its type when a normal string is provided as the title" do
    expect(component.new(:name => "bar").ref).to eq("Class[Bar]")
  end

  it "should always produce a resource reference string as its title" do
    expect(component.new(:name => "bar").title).to eq("Class[Bar]")
  end

  it "should have a reference string equivalent to its title" do
    comp = component.new(:name => "Foo[bar]")
    expect(comp.title).to eq(comp.ref)
  end

  it "should not fail when provided an invalid value" do
    comp = component.new(:name => "Foo[bar]")
    expect { comp[:yayness] = "ey" }.not_to raise_error
  end

  it "should return previously provided invalid values" do
    comp = component.new(:name => "Foo[bar]")
    comp[:yayness] = "eh"
    expect(comp[:yayness]).to eq("eh")
  end

  it "should correctly support metaparameters" do
    comp = component.new(:name => "Foo[bar]", :require => "Foo[bar]")
    expect(comp.parameter(:require)).to be_instance_of(component.attrclass(:require))
  end

  describe "when building up the path" do
    it "should produce the class name if the component models a class" do
      expect(component.new(:name => "Class[foo]").pathbuilder).to eq(["Foo"])
    end

    it "should produce the class name even for the class named main" do
      expect(component.new(:name => "Class[main]").pathbuilder).to eq(["Main"])
    end

    it "should produce a resource reference if the component does not model a class" do
      expect(component.new(:name => "Foo[bar]").pathbuilder).to eq(["Foo[bar]"])
    end
  end
end
