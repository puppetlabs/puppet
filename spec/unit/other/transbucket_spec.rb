#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::TransBucket do
  before do
    @bucket = Puppet::TransBucket.new
  end

  it "should be able to produce a RAL component" do
    @bucket.name = "luke"
    @bucket.type = "foo"

    resource = nil
    proc { resource = @bucket.to_ral }.should_not raise_error
    resource.should be_instance_of(Puppet::Type::Component)
    resource.title.should == "Foo[luke]"
  end

  it "should accept TransObjects into its children list" do
    object = Puppet::TransObject.new("luke", "user")
    proc { @bucket.push(object) }.should_not raise_error
    @bucket.each do |o|
      o.should equal(object)
    end
  end

  it "should accept TransBuckets into its children list" do
    object = Puppet::TransBucket.new
    proc { @bucket.push(object) }.should_not raise_error
    @bucket.each do |o|
      o.should equal(object)
    end
  end

  it "should refuse to accept any children that are not TransObjects or TransBuckets" do
    proc { @bucket.push "a test" }.should raise_error
  end

  it "should return use 'node' as the type and the provided name as the title if only a type is provided" do
    @bucket.type = "mystuff"
    @bucket.to_ref.should == "Node[mystuff]"
  end

  it "should return use 'component' as the type and the provided type as the title if only a name is provided" do
    @bucket.name = "mystuff"
    @bucket.to_ref.should == "Class[Mystuff]"
  end

  it "should return nil as its reference when type and name are missing" do
    @bucket.to_ref.should be_nil
  end

  it "should return the title as its reference" do
    @bucket.name = "luke"
    @bucket.type = "user"
    @bucket.to_ref.should == "User[luke]"
  end

  it "should canonize resource references when the type is 'component'" do
    @bucket.name = 'something'
    @bucket.type = 'foo::bar'

    @bucket.to_ref.should == "Foo::Bar[something]"
  end
end

describe Puppet::TransBucket, " when generating a catalog" do
  before do
    @bottom = Puppet::TransBucket.new
    @bottom.type = "fake"
    @bottom.name = "bottom"
    @bottomobj = Puppet::TransObject.new("bottom", "notify")
    @bottom.push @bottomobj

    @middle = Puppet::TransBucket.new
    @middle.type = "fake"
    @middle.name = "middle"
    @middleobj = Puppet::TransObject.new("middle", "notify")
    @middle.push(@middleobj)
    @middle.push(@bottom)

    @top = Puppet::TransBucket.new
    @top.type = "fake"
    @top.name = "top"
    @topobj = Puppet::TransObject.new("top", "notify")
    @top.push(@topobj)
    @top.push(@middle)

    @users = %w{top middle bottom}
    @fakes = %w{Fake[bottom] Fake[middle] Fake[top]}
  end

  it "should convert all transportable objects to RAL resources" do
    @catalog = @top.to_catalog
    @users.each do |name|
      @catalog.vertices.find { |r| r.class.name == :notify and r.title == name }.should be_instance_of(Puppet::Type.type(:notify))
    end
  end

  it "should fail if any transportable resources fail to convert to RAL resources" do
    @bottomobj.expects(:to_ral).raises ArgumentError
    lambda { @bottom.to_catalog }.should raise_error(ArgumentError)
  end

  it "should convert all transportable buckets to RAL components" do
    @catalog = @top.to_catalog
    @fakes.each do |name|
      @catalog.vertices.find { |r| r.class.name == :component and r.title == name }.should be_instance_of(Puppet::Type.type(:component))
    end
  end

  it "should add all resources to the graph's resource table" do
    @catalog = @top.to_catalog
    @catalog.resource("fake[top]").should equal(@top)
  end

  it "should finalize all resources" do
    @catalog = @top.to_catalog
    @catalog.vertices.each do |vertex| vertex.should be_finalized end
  end

  it "should only call to_ral on each resource once" do
    # We just raise exceptions here because we're not interested in
    # what happens with the result, only that the method only
    # gets called once.
    resource = @topobj.to_ral
    @topobj.expects(:to_ral).once.returns resource
    @top.to_catalog
  end

  it "should set each TransObject's catalog before converting to a RAL resource" do
    @middleobj.expects(:catalog=).with { |c| c.is_a?(Puppet::Resource::Catalog) }
    @top.to_catalog
  end

  it "should set each TransBucket's catalog before converting to a RAL resource" do
    # each bucket is seen twice in the loop, so we have to handle the case where the config
    # is set twice
    @bottom.expects(:catalog=).with { |c| c.is_a?(Puppet::Resource::Catalog) }.at_least_once
    @top.to_catalog
  end
end

describe Puppet::TransBucket, " when serializing" do
  before do
    @bucket = Puppet::TransBucket.new(%w{one two})
    @bucket.name = "one"
    @bucket.type = "two"
  end

  it "should be able to be dumped to yaml" do
    proc { YAML.dump(@bucket) }.should_not raise_error
  end

  it "should dump YAML that produces an equivalent object" do
    result = YAML.dump(@bucket)

    newobj = YAML.load(result)
    newobj.name.should == "one"
    newobj.type.should == "two"
    children = []
    newobj.each do |o|
      children << o
    end
    children.should == %w{one two}
  end
end

describe Puppet::TransBucket, " when converting to a Puppet::Resource" do
  before do
    @trans = Puppet::TransBucket.new
    @trans.name = "foo"
    @trans.type = "bar"
    @trans.param(:noop, true)
  end

  it "should create a resource with the correct type and title" do
    result = @trans.to_resource
    result.type.should == "Bar"
    result.title.should == "foo"
  end

  it "should add all of its parameters to the created resource" do
    @trans.param(:noop, true)
    @trans.to_resource[:noop].should be_true
  end
end
