#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Node, " when initializing" do
    before do
        @node = Puppet::Node.new("testnode")
    end

    it "should set the node name" do
        @node.name.should == "testnode"
    end

    it "should default to an empty parameter hash" do
        @node.parameters.should == {}
    end

    it "should default to an empty class array" do
        @node.classes.should == []
    end

    it "should note its creation time" do
        @node.time.should be_instance_of(Time)
    end

    it "should accept parameters passed in during initialization" do
        params = {"a" => "b"}
        @node = Puppet::Node.new("testing", :parameters => params)
        @node.parameters.should == params
    end

    it "should accept classes passed in during initialization" do
        classes = %w{one two}
        @node = Puppet::Node.new("testing", :classes => classes)
        @node.classes.should == classes
    end

    it "should always return classes as an array" do
        @node = Puppet::Node.new("testing", :classes => "myclass")
        @node.classes.should == ["myclass"]
    end

    it "should accept the environment during initialization" do
        @node = Puppet::Node.new("testing", :environment => "myenv")
        @node.environment.should == "myenv"
    end

    it "should accept names passed in" do
        @node = Puppet::Node.new("testing", :names => ["myenv"])
        @node.names.should == ["myenv"]
    end
end

describe Puppet::Node, " when returning the environment" do
    before do
        @node = Puppet::Node.new("testnode")
    end

    it "should return the 'environment' fact if present and there is no explicit environment" do
        @node.parameters = {"environment" => "myenv"}
        @node.environment.should == "myenv"
    end

    it "should return the central environment if there is no environment fact nor explicit environment" do
        Puppet.config.expects(:[]).with(:environment).returns(:centralenv)
        @node.environment.should == :centralenv
    end

    it "should not use an explicit environment that is an empty string" do
        @node.environment == ""
        @node.environment.should be_nil
    end

    it "should not use an environment fact that is an empty string" do
        @node.parameters = {"environment" => ""}
        @node.environment.should be_nil
    end

    it "should not use an explicit environment that is an empty string" do
        Puppet.config.expects(:[]).with(:environment).returns(nil)
        @node.environment.should be_nil
    end
end

describe Puppet::Node, " when merging facts" do
    before do
        @node = Puppet::Node.new("testnode")
    end

    it "should prefer parameters already set on the node over facts from the node" do
        @node.parameters = {"one" => "a"}
        @node.fact_merge("one" => "c")
        @node.parameters["one"].should == "a"
    end

    it "should add passed parameters to the parameter list" do
        @node.parameters = {"one" => "a"}
        @node.fact_merge("two" => "b")
        @node.parameters["two"].should == "b"
    end
end

describe Puppet::Node, " when indirecting" do
    before do
        Puppet[:node_source] = :test_source
        @terminus_class = mock 'terminus_class'
        @terminus = mock 'terminus'
        @terminus_class.expects(:new).returns(@terminus)
        Puppet::Indirector.expects(:terminus).with(:node, :test_source).returns(@terminus_class)
    end

    it "should redirect to the specified node source" do
        @terminus.expects(:get).with(:my_node)
        Puppet::Node.get(:my_node)
    end
end
