#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/transportable'

describe Puppet::TransObject do
    it "should canonize resource references" do
        resource = Puppet::TransObject.new("me", "foo::bar")
        resource.ref.should == 'Foo::Bar[me]'
    end

    it "should lower-case resource types for backward compatibility with 0.23.2" do
        resource = Puppet::TransObject.new("me", "Foo")
        resource.type.should == 'foo'
    end
end

describe Puppet::TransObject, " when serializing" do
    before do
        @resource = Puppet::TransObject.new("/my/file", "file")
        @resource["one"] = "test"
        @resource["two"] = "other"
    end

    it "should be able to be dumped to yaml" do
        proc { YAML.dump(@resource) }.should_not raise_error
    end

    it "should produce an equivalent yaml object" do
        text = YAML.dump(@resource)

        newresource = YAML.load(text)
        newresource.name.should == "/my/file"
        newresource.type.should == "file"
        %w{one two}.each do |param|
            newresource[param].should == @resource[param]
        end
    end
end

describe Puppet::TransObject, " when converting to a RAL resource" do
    before do
        @resource = Puppet::TransObject.new("/my/file", "file")
        @resource["one"] = "test"
        @resource["two"] = "other"
    end

    it "should use the resource type's :create method to create the resource" do
        type = mock 'resource type'
        type.expects(:create).with(@resource).returns(:myresource)
        Puppet::Type.expects(:type).with("file").returns(type)
        @resource.to_type.should == :myresource
    end

    it "should convert to a component instance if the resource type cannot be found" do
        Puppet::Type.expects(:type).with("file").returns(nil)
        @resource.expects(:to_component).returns(:mycomponent)
        @resource.to_type.should == :mycomponent
    end
end

describe Puppet::TransObject, " when converting to a RAL component instance" do
    before do
        @resource = Puppet::TransObject.new("/my/file", "one::two")
        @resource["one"] = "test"
        @resource["noop"] = "other"
    end

    it "should use a new TransObject whose name is a resource reference of the type and title of the original TransObject" do
        Puppet::Type::Component.expects(:create).with { |resource| resource.type == "component" and resource.name == "One::Two[/my/file]" }.returns(:yay)
        @resource.to_component.should == :yay
    end

    it "should pass the resource parameters on to the newly created TransObject" do
        Puppet::Type::Component.expects(:create).with { |resource| resource["noop"] == "other" }.returns(:yay)
        @resource.to_component.should == :yay
    end

    it "should copy over the catalog" do
        @resource.catalog = "mycat"
        Puppet::Type::Component.expects(:create).with { |resource| resource.catalog == "mycat" }.returns(:yay)
        @resource.to_component
    end

    # LAK:FIXME This really isn't the design we want going forward, but it's
    # good enough for now.
    it "should not pass resource parameters that are not metaparams" do
        Puppet::Type::Component.expects(:create).with { |resource| resource["one"].nil? }.returns(:yay)
        @resource.to_component.should == :yay
    end
end
