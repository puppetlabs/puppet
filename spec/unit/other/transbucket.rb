#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::TransBucket do
    before do
        @bucket = Puppet::TransBucket.new
    end

    it "should be able to produce a RAL component" do
        @bucket.name = "luke"
        @bucket.type = "user"

        resource = nil
        proc { resource = @bucket.to_type }.should_not raise_error
        resource.should be_instance_of(Puppet::Type::Component)
        resource.title.should == "user[luke]"
    end

    it "should accept TransObjects into its children list" do
        object = Puppet::TransObject.new("luke", "user")
        proc { @bucket.push(object) }.should_not raise_error
        @bucket.each do |o|
            o.should equal(object)
        end
    end

    it "should accept TransBuckets into its children list" do
        object = Puppet::TransBucket.new()
        proc { @bucket.push(object) }.should_not raise_error
        @bucket.each do |o|
            o.should equal(object)
        end
    end

    it "should refuse to accept any children that are not TransObjects or TransBuckets" do
        proc { @bucket.push "a test" }.should raise_error
    end

    it "should return nil as its reference when type or name is missing" do
        @bucket.to_ref.should be_nil
    end

    it "should return the title as its reference" do
        @bucket.name = "luke"
        @bucket.type = "user"
        @bucket.to_ref.should == "user[luke]"
    end
end

describe Puppet::TransBucket, " when generating a configuration" do
    before do
        @bottom = Puppet::TransBucket.new
        @bottom.type = "fake"
        @bottom.name = "bottom"
        @bottomobj = Puppet::TransObject.new("bottom", "user")
        @bottom.push @bottomobj

        @middle = Puppet::TransBucket.new
        @middle.type = "fake"
        @middle.name = "middle"
        @middleobj = Puppet::TransObject.new("middle", "user")
        @middle.push(@middleobj)
        @middle.push(@bottom)

        @top = Puppet::TransBucket.new
        @top.type = "fake"
        @top.name = "top"
        @topobj = Puppet::TransObject.new("top", "user")
        @top.push(@topobj)
        @top.push(@middle)

        @config = @top.to_configuration

        @users = %w{top middle bottom}
        @fakes = %w{fake[bottom] fake[middle] fake[top]}
    end

    it "should convert all transportable objects to RAL resources" do
        @users.each do |name|
            @config.vertices.find { |r| r.class.name == :user and r.title == name }.should be_instance_of(Puppet::Type.type(:user))
        end
    end

    it "should convert all transportable buckets to RAL components" do
        @fakes.each do |name|
            @config.vertices.find { |r| r.class.name == :component and r.title == name }.should be_instance_of(Puppet::Type.type(:component))
        end
    end

    it "should add all resources to the graph's resource table" do
        @config.resource("fake[top]").should equal(@top)
    end

    it "should finalize all resources" do
        @config.vertices.each do |vertex| vertex.should be_finalized end
    end

    it "should only call to_type on each resource once" do
        @topobj.expects(:to_type)
        @bottomobj.expects(:to_type)
        Puppet::Type.allclear
        @top.to_configuration
    end

    it "should set each TransObject's configuration before converting to a RAL resource" do
        @middleobj.expects(:configuration=).with { |c| c.is_a?(Puppet::Node::Configuration) }
        Puppet::Type.allclear
        @top.to_configuration
    end

    it "should set each TransBucket's configuration before converting to a RAL resource" do
        # each bucket is seen twice in the loop, so we have to handle the case where the config
        # is set twice
        @bottom.expects(:configuration=).with { |c| c.is_a?(Puppet::Node::Configuration) }.at_least_once
        Puppet::Type.allclear
        @top.to_configuration
    end

    after do
        Puppet::Type.allclear
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
