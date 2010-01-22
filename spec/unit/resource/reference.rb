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

    it "should interpret the type as a reference and assign appropriately if the title is nil and the type contains square brackets" do
        ref = Puppet::Resource::Reference.new("foo::bar[baz]")
        ref.type.should == "Foo::Bar"
        ref.title.should =="baz"
    end

    it "should be able to extract its information from a Puppet::Type instance" do
        ral = Puppet::Type.type(:file).new :path => "/foo"
        ref = Puppet::Resource::Reference.new(ral)
        ref.type.should == "File"
        ref.title.should == "/foo"
    end


    it "should fail if the title is nil and the type is not a valid resource reference string" do
        lambda { Puppet::Resource::Reference.new("foo") }.should raise_error(ArgumentError)
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

    it "should be considered equivalent to another reference if their type and title match" do
        Puppet::Resource::Reference.new("file", "/f").should == Puppet::Resource::Reference.new("file", "/f")
    end

    it "should not be considered equivalent to a non-reference" do
        Puppet::Resource::Reference.new("file", "/f").should_not == "foo"
    end

    it "should not be considered equivalent to another reference if their types do not match" do
        Puppet::Resource::Reference.new("file", "/f").should_not == Puppet::Resource::Reference.new("exec", "/f")
    end

    it "should not be considered equivalent to another reference if their titles do not match" do
        Puppet::Resource::Reference.new("file", "/foo").should_not == Puppet::Resource::Reference.new("file", "/f")
    end

    describe "when resolving resources with a catalog" do
        it "should resolve all resources using the catalog" do
            config = mock 'catalog'
            ref = Puppet::Resource::Reference.new("foo::bar", "yay")
            ref.catalog = config

            config.expects(:resource).with("Foo::Bar[yay]").returns(:myresource)

            ref.resolve.should == :myresource
        end
    end
end
