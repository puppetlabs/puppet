#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

describe Puppet::Node, "when initializing" do
    before do
        @node = Puppet::Node.new("testnode")
    end

    it "should set the node name" do
        @node.name.should == "testnode"
    end

    it "should not allow nil node names" do
        proc { Puppet::Node.new(nil) }.should raise_error(ArgumentError)
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

    it "should accept an environment value" do
        Puppet.settings.stubs(:value).with(:environments).returns("myenv")
        @node = Puppet::Node.new("testing", :environment => "myenv")
        @node.environment.should == "myenv"
    end

    it "should validate the environment" do
        Puppet.settings.stubs(:value).with(:environments).returns("myenv")
        proc { Puppet::Node.new("testing", :environment => "other") }.should raise_error(ArgumentError)
    end
end

describe Puppet::Node, "when returning the environment" do
    before do
        Puppet.settings.stubs(:value).with(:environments).returns("one,two")
        Puppet.settings.stubs(:value).with(:environment).returns("one")
        @node = Puppet::Node.new("testnode")
    end

    it "should return the 'environment' fact if present and there is no explicit environment" do
        @node.parameters = {"environment" => "two"}
        @node.environment.should == "two"
    end

    it "should use the default environment if there is no environment fact nor explicit environment" do
        env = mock 'environment', :name => :myenv
        Puppet::Node::Environment.expects(:new).returns(env)
        @node.environment.should == "myenv"
    end

    it "should fail if the parameter environment is invalid" do
        @node.parameters = {"environment" => "three"}
        proc { @node.environment }.should raise_error(ArgumentError)
    end

    it "should fail if the parameter environment is invalid" do
        @node.parameters = {"environment" => "three"}
        proc { @node.environment }.should raise_error(ArgumentError)
    end
end

describe Puppet::Node, "when merging facts" do
    before do
        @node = Puppet::Node.new("testnode")
        Puppet::Node::Facts.stubs(:find).with(@node.name).returns(Puppet::Node::Facts.new(@node.name, "one" => "c", "two" => "b"))
    end

    it "should prefer parameters already set on the node over facts from the node" do
        @node.parameters = {"one" => "a"}
        @node.fact_merge
        @node.parameters["one"].should == "a"
    end

    it "should add passed parameters to the parameter list" do
        @node.parameters = {"one" => "a"}
        @node.fact_merge
        @node.parameters["two"].should == "b"
    end

    it "should accept arbitrary parameters to merge into its parameters" do
        @node.parameters = {"one" => "a"}
        @node.merge "two" => "three"
        @node.parameters["two"].should == "three"
    end

    it "should add the environment to the list of parameters" do
        Puppet.settings.stubs(:value).with(:environments).returns("one,two")
        Puppet.settings.stubs(:value).with(:environment).returns("one")
        @node = Puppet::Node.new("testnode", :environment => "one")
        @node.merge "two" => "three"
        @node.parameters["environment"].should == "one"
    end

    it "should not set the environment if it is already set in the parameters" do
        Puppet.settings.stubs(:value).with(:environments).returns("one,two")
        Puppet.settings.stubs(:value).with(:environment).returns("one")
        @node = Puppet::Node.new("testnode", :environment => "one")
        @node.merge "environment" => "two"
        @node.parameters["environment"].should == "two"
    end
end

describe Puppet::Node, "when indirecting" do
    it "should redirect to the indirection" do
        @indirection = stub 'indirection', :name => :node
        Puppet::Node.stubs(:indirection).returns(@indirection)
        @indirection.expects(:find)
        Puppet::Node.find(:my_node.to_s)
    end

    it "should default to the 'plain' node terminus" do
        Puppet::Node.indirection.terminus_class.should == :plain
    end

    it "should not have a cache class defined" do
        Puppet::Node.indirection.cache_class.should be_nil
    end

    after do
        Puppet::Util::Cacher.invalidate
    end
end

describe Puppet::Node, "when generating the list of names to search through" do
    before do
        @node = Puppet::Node.new("foo.domain.com")
        @node.parameters = {"hostname" => "yay", "domain" => "domain.com"}
    end

    it "should return an array of names" do
        @node.names.should be_instance_of(Array)
    end

    it "should have the node's fqdn as the second name" do
        @node.names[1].should == "yay.domain.com"
    end

    it "should set the fqdn to the node's 'fqdn' fact if it is available" do
        @node.parameters["fqdn"] = "boo.domain.com"
        @node.names[1].should == "boo.domain.com"
    end

    it "should set the fqdn to the node's hostname and domain if no fqdn is available" do
        @node.names[1].should == "yay.domain.com"
    end

    it "should contain an entry for each name available by stripping a segment of the fqdn" do
        @node.parameters["fqdn"] = "foo.deep.sub.domain.com"
        @node.names[2].should == "foo.deep.sub.domain"
        @node.names[3].should == "foo.deep.sub"
    end

    describe "and :node_name is set to 'cert'" do
        before do
            Puppet.settings.stubs(:value).with(:node_name).returns "cert"
        end

        it "should use the passed-in key as the first value" do
            @node.names[0].should == "foo.domain.com"
        end
    end

    describe "and :node_name is set to 'facter'" do
        before do
            Puppet.settings.stubs(:value).with(:node_name).returns "facter"
        end

        it "should use the node's 'hostname' fact as the first value" do
            @node.names[0].should == "yay"
        end
    end
end
