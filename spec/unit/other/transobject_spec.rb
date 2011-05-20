#!/usr/bin/env rspec
require 'spec_helper'

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

describe Puppet::TransObject, " when converting to a Puppet::Resource" do
  before do
    @trans = Puppet::TransObject.new("/my/file", "file")
    @trans["one"] = "test"
    @trans["two"] = "other"
  end

  it "should create a resource with the correct type and title" do
    result = @trans.to_resource
    result.type.should == "File"
    result.title.should == "/my/file"
  end

  it "should add all of its parameters to the created resource" do
    @trans[:noop] = true
    @trans.to_resource[:noop].should be_true
  end

  it "should copy over the tags" do
    @trans.tags = %w{foo bar}
    result = @trans.to_resource
    result.should be_tagged("foo")
    result.should be_tagged("bar")
  end
end

describe Puppet::TransObject, " when converting to a RAL resource" do
  before do
    @resource = Puppet::TransObject.new("/my/file", "file")
    @resource["one"] = "test"
    @resource["two"] = "other"
  end

  it "should use a Puppet::Resource to create the resource" do
    resource = mock 'resource'
    @resource.expects(:to_resource).returns resource
    resource.expects(:to_ral).returns "myral"
    @resource.to_ral.should == "myral"
  end
end

describe Puppet::TransObject, " when converting to a RAL component instance" do
  before do
    @resource = Puppet::TransObject.new("/my/file", "one::two")
    @resource["one"] = "test"
    @resource["noop"] = "other"
  end

  it "should use a new TransObject whose name is a resource reference of the type and title of the original TransObject" do
    Puppet::Type::Component.expects(:new).with { |resource| resource.type == "component" and resource.name == "One::Two[/my/file]" }.returns(:yay)
    @resource.to_component.should == :yay
  end

  it "should pass the resource parameters on to the newly created TransObject" do
    Puppet::Type::Component.expects(:new).with { |resource| resource["noop"] == "other" }.returns(:yay)
    @resource.to_component.should == :yay
  end

  it "should copy over the catalog" do
    @resource.catalog = "mycat"
    Puppet::Type::Component.expects(:new).with { |resource| resource.catalog == "mycat" }.returns(:yay)
    @resource.to_component
  end

  # LAK:FIXME This really isn't the design we want going forward, but it's
  # good enough for now.
  it "should not pass resource parameters that are not metaparams" do
    Puppet::Type::Component.expects(:new).with { |resource| resource["one"].nil? }.returns(:yay)
    @resource.to_component.should == :yay
  end
end
