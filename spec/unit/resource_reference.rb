#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/resource_reference'

describe Puppet::ResourceReference do
    it "should have a :title attribute" do
        Puppet::ResourceReference.new(:file, "foo").title.should == "foo"
    end

    it "should canonize types to capitalized strings" do
        Puppet::ResourceReference.new(:file, "foo").type.should == "File"
    end

    it "should canonize qualified types so all strings are capitalized" do
        Puppet::ResourceReference.new("foo::bar", "foo").type.should == "Foo::Bar"
    end

    it "should set its type to 'Class' and its title to the passed title if the passed type is :component and the title has no square brackets in it" do
        ref = Puppet::ResourceReference.new(:component, "foo")
        ref.type.should == "Class"
        ref.title.should == "foo"
    end

    it "should interpret the title as a reference and assign appropriately if the type is :component and the title contains square brackets" do
        ref = Puppet::ResourceReference.new(:component, "foo::bar[yay]")
        ref.type.should == "Foo::Bar"
        ref.title.should == "yay"
    end

    it "should set the type to 'Class' if it is nil and the title contains no square brackets" do
        ref = Puppet::ResourceReference.new(nil, "yay")
        ref.type.should == "Class"
        ref.title.should == "yay"
    end

    it "should interpret the title as a reference and assign appropriately if the type is nil and the title contains square brackets" do
        ref = Puppet::ResourceReference.new(nil, "foo::bar[yay]")
        ref.type.should == "Foo::Bar"
        ref.title.should == "yay"
    end
end

describe Puppet::ResourceReference, "when resolving resources without a catalog" do
    it "should be able to resolve builtin resources from their types" do
        Puppet::Type.type(:file).expects(:[]).with("myfile").returns(:myfile)
        Puppet::ResourceReference.new(:file, "myfile").resolve.should == :myfile
    end

    it "should be able to resolve defined resources from Components" do
        Puppet::Type.type(:component).expects(:[]).with("Foo::Bar[yay]").returns(:mything)
        Puppet::ResourceReference.new("foo::bar", "yay").resolve.should == :mything
    end
end

describe Puppet::ResourceReference, "when resolving resources with a catalog" do
    it "should resolve all resources using the catalog" do
        config = mock 'catalog'
        ref = Puppet::ResourceReference.new("foo::bar", "yay")
        ref.catalog = config

        config.expects(:resource).with("Foo::Bar[yay]").returns(:myresource)

        ref.resolve.should == :myresource
    end
end
