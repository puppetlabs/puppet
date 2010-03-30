#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/defaults'
require 'puppet/indirector'

describe Puppet::Indirector, " when available to a model" do
    before do
        @thingie = Class.new do
            extend Puppet::Indirector
        end
    end

    it "should provide a way for the model to register an indirection under a name" do
        @thingie.should respond_to(:indirects)
    end
end

describe Puppet::Indirector, "when registering an indirection" do
    before do
        @thingie = Class.new do
            extend Puppet::Indirector
            attr_reader :name
            def initialize(name)
                @name = name
            end
        end
    end

    it "should require a name when registering a model" do
        Proc.new {@thingie.send(:indirects) }.should raise_error(ArgumentError)
    end

    it "should create an indirection instance to manage each indirecting model" do
        @indirection = @thingie.indirects(:test)
        @indirection.should be_instance_of(Puppet::Indirector::Indirection)
    end

    it "should not allow a model to register under multiple names" do
        # Keep track of the indirection instance so we can delete it on cleanup
        @indirection = @thingie.indirects :first
        Proc.new { @thingie.indirects :second }.should raise_error(ArgumentError)
    end

    it "should make the indirection available via an accessor" do
        @indirection = @thingie.indirects :first
        @thingie.indirection.should equal(@indirection)
    end

    it "should pass any provided options to the indirection during initialization" do
        klass = mock 'terminus class'
        Puppet::Indirector::Indirection.expects(:new).with(@thingie, :first, {:some => :options})
        @indirection = @thingie.indirects :first, :some => :options
    end

    it "should extend the class with the Format Handler" do
        @indirection = @thingie.indirects :first
        @thingie.metaclass.ancestors.should be_include(Puppet::Network::FormatHandler)
    end

    after do
        @indirection.delete if @indirection
    end
end

describe "Delegated Indirection Method", :shared => true do
    it "should delegate to the indirection" do
        @indirection.expects(@method)
        @thingie.send(@method, "me")
    end

    it "should pass all of the passed arguments directly to the indirection instance" do
        @indirection.expects(@method).with("me", :one => :two)
        @thingie.send(@method, "me", :one => :two)
    end

    it "should return the results of the delegation as its result" do
        request = mock 'request'
        @indirection.expects(@method).returns "yay"
        @thingie.send(@method, "me").should == "yay"
    end
end

describe Puppet::Indirector, "when redirecting a model" do
    before do
        @thingie = Class.new do
            extend Puppet::Indirector
            attr_reader :name
            def initialize(name)
                @name = name
            end
        end
        @indirection = @thingie.send(:indirects, :test)
    end

    it "should include the Envelope module in the model" do
        @thingie.ancestors.should be_include(Puppet::Indirector::Envelope)
    end

    describe "when finding instances via the model" do
        before { @method = :find }
        it_should_behave_like "Delegated Indirection Method"
    end

    describe "when destroying instances via the model" do
        before { @method = :destroy }
        it_should_behave_like "Delegated Indirection Method"
    end

    describe "when searching for instances via the model" do
        before { @method = :search }
        it_should_behave_like "Delegated Indirection Method"
    end

    describe "when expiring instances via the model" do
        before { @method = :expire }
        it_should_behave_like "Delegated Indirection Method"
    end

    # This is an instance method, so it behaves a bit differently.
    describe "when saving instances via the model" do
        before do
            @instance = @thingie.new("me")
        end

        it "should delegate to the indirection" do
            @indirection.expects(:save)
            @instance.save
        end

        it "should pass the instance and an optional key to the indirection's :save method" do
            @indirection.expects(:save).with("key", @instance)
            @instance.save "key"
        end

        it "should return the results of the delegation as its result" do
            request = mock 'request'
            @indirection.expects(:save).returns "yay"
            @instance.save.should == "yay"
        end
    end

    it "should give the model the ability to set the indirection terminus class" do
        @indirection.expects(:terminus_class=).with(:myterm)
        @thingie.terminus_class = :myterm
    end

    it "should give the model the ability to set the indirection cache class" do
        @indirection.expects(:cache_class=).with(:mycache)
        @thingie.cache_class = :mycache
    end

    after do
        @indirection.delete
    end
end
