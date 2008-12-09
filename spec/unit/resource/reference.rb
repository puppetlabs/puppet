#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/resource/reference'

describe Puppet::Resource::Reference do
    it "should have a :title attribute" do
        Puppet::Resource::Reference.new(:file, "foo").title.should == "foo"
    end

    it "should canonize types to capitalized strings" do
        Puppet::Resource::Reference.new(:file, "foo").type.should == "File"
    end

    it "should canonize qualified types so all strings are capitalized" do
        Puppet::Resource::Reference.new("foo::bar", "foo").type.should == "Foo::Bar"
    end

    it "should set its type to 'Class' and its title to the passed title if the passed type is :component and the title has no square brackets in it" do
        ref = Puppet::Resource::Reference.new(:component, "foo")
        ref.type.should == "Class"
        ref.title.should == "foo"
    end

    it "should interpret the title as a reference and assign appropriately if the type is :component and the title contains square brackets" do
        ref = Puppet::Resource::Reference.new(:component, "foo::bar[yay]")
        ref.type.should == "Foo::Bar"
        ref.title.should == "yay"
    end

    it "should set the type to 'Class' if it is nil and the title contains no square brackets" do
        ref = Puppet::Resource::Reference.new(nil, "yay")
        ref.type.should == "Class"
        ref.title.should == "yay"
    end

    it "should interpret the title as a reference and assign appropriately if the type is nil and the title contains square brackets" do
        ref = Puppet::Resource::Reference.new(nil, "foo::bar[yay]")
        ref.type.should == "Foo::Bar"
        ref.title.should == "yay"
    end

    it "should interpret the title as a reference and assign appropriately if the type is nil and the title contains nested square brackets" do
        ref = Puppet::Resource::Reference.new(nil, "foo::bar[baz[yay]]")
        ref.type.should == "Foo::Bar"
        ref.title.should =="baz[yay]"
    end

    it "should be considered builtin if an existing resource type matches the type" do
        Puppet::Resource::Reference.new("file", "/f").should be_builtin_type
    end

    it "should be not considered builtin if an existing resource type does not match the type" do
        Puppet::Resource::Reference.new("foobar", "/f").should_not be_builtin_type
    end

    it "should be able to produce a backward-compatible reference array" do
        Puppet::Resource::Reference.new("foobar", "/f").to_trans_ref.should == %w{Foobar /f}
    end

    it "should downcase resource types when producing a backward-compatible reference array for builtin resource types" do
        Puppet::Resource::Reference.new("file", "/f").to_trans_ref.should == %w{file /f}
    end
end

describe Puppet::Resource::Reference, "when resolving resources with a catalog" do
    it "should resolve all resources using the catalog" do
        config = mock 'catalog'
        ref = Puppet::Resource::Reference.new("foo::bar", "yay")
        ref.catalog = config

        config.expects(:resource).with("Foo::Bar[yay]").returns(:myresource)

        ref.resolve.should == :myresource
    end
end
