#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-9-23.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/facts/facter'

describe Puppet::Node::Facts::Facter do
    it "should be a subclass of the Code terminus" do
        Puppet::Node::Facts::Facter.superclass.should equal(Puppet::Indirector::Code)
    end

    it "should have documentation" do
        Puppet::Node::Facts::Facter.doc.should_not be_nil
    end

    it "should be registered with the configuration store indirection" do
        indirection = Puppet::Indirector::Indirection.instance(:facts)
        Puppet::Node::Facts::Facter.indirection.should equal(indirection)
    end

    it "should have its name set to :facter" do
        Puppet::Node::Facts::Facter.name.should == :facter
    end

    it "should load facts on initialization" do
        Puppet::Node::Facts::Facter.expects(:loadfacts)
        Puppet::Node::Facts::Facter.new
    end
end

describe Puppet::Node::Facts::Facter do
    before :each do
        @facter = Puppet::Node::Facts::Facter.new
        Facter.stubs(:to_hash).returns({})
        @name = "me"
        @request = stub 'request', :key => @name
    end

    describe Puppet::Node::Facts::Facter, " when finding facts" do

        it "should return a Facts instance" do
            @facter.find(@request).should be_instance_of(Puppet::Node::Facts)
        end

        it "should return a Facts instance with the provided key as the name" do
            @facter.find(@request).name.should == @name
        end

        it "should return the Facter facts as the values in the Facts instance" do
            Facter.expects(:to_hash).returns("one" => "two")
            facts = @facter.find(@request)
            facts.values["one"].should == "two"
        end
    end

    describe Puppet::Node::Facts::Facter, " when saving facts" do

        it "should fail" do
            proc { @facter.save(@facts) }.should raise_error(Puppet::DevError)
        end
    end

    describe Puppet::Node::Facts::Facter, " when destroying facts" do

        it "should fail" do
            proc { @facter.destroy(@facts) }.should raise_error(Puppet::DevError)
        end
    end

    describe Puppet::Node::Facts::Facter, "when loading facts from disk" do
        it "should load each directory in the Fact path" do
            Puppet.settings.stubs(:value).returns "foo"
            Puppet.settings.expects(:value).with(:factpath).returns("one%stwo" % File::PATH_SEPARATOR)

            Puppet::Node::Facts::Facter.expects(:loaddir).with("one", "fact")
            Puppet::Node::Facts::Facter.expects(:loaddir).with("two", "fact")

            Puppet::Node::Facts::Facter.loadfacts
        end

        it "should load all facts from the modules" do
            Puppet.settings.stubs(:value).returns "foo"
            Puppet::Node::Facts::Facter.stubs(:loaddir)

            Puppet.settings.expects(:value).with(:modulepath).returns("one%stwo" % File::PATH_SEPARATOR)

            Dir.expects(:glob).with("one/*/plugins/facter").returns %w{oneA oneB}
            Dir.expects(:glob).with("two/*/plugins/facter").returns %w{twoA twoB}

            Puppet::Node::Facts::Facter.expects(:loaddir).with("oneA", "fact")
            Puppet::Node::Facts::Facter.expects(:loaddir).with("oneB", "fact")
            Puppet::Node::Facts::Facter.expects(:loaddir).with("twoA", "fact")
            Puppet::Node::Facts::Facter.expects(:loaddir).with("twoB", "fact")

            Puppet::Node::Facts::Facter.loadfacts
        end
    end
end
