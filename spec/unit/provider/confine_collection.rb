#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/provider/confine_collection'

describe Puppet::Provider::ConfineCollection do
    it "should be able to add confines" do
        Puppet::Provider::ConfineCollection.new.should respond_to(:confine)
    end

    describe "when creating confine instances" do
        it "should create an instance of the named test with the provided values" do
            test_class = mock 'test_class'
            test_class.expects(:new).with(%w{my values})
            Puppet::Provider::Confine.expects(:test).with(:foo).returns test_class

            Puppet::Provider::ConfineCollection.new.confine :foo => %w{my values}
        end

        describe "and the test cannot be found" do
            before do
                @variable = mock 'variable_test'

                Puppet::Provider::Confine.expects(:test).with(:foo).returns nil
                Puppet::Provider::Confine.expects(:test).with(:variable).returns @variable
            end

            it "should create a Facter test with the provided values and set the name to the test name" do
                confine = mock 'confine'
                confine.expects(:name=).with(:foo)
                @variable.expects(:new).with(%w{my values}).returns confine
                Puppet::Provider::ConfineCollection.new.confine :foo => %w{my values}
            end
        end

        describe "and the 'for_binary' option was provided" do
            it "should mark the test as a binary confine" do
                confine = mock 'confine'
                confine.expects(:for_binary=).with true
                Puppet::Provider::Confine.test(:exists).expects(:new).with(:bar).returns confine
                Puppet::Provider::ConfineCollection.new.confine :exists => :bar, :for_binary => true
            end
        end
    end

    it "should be valid if no confines are present" do
        Puppet::Provider::ConfineCollection.new.should be_valid
    end

    it "should be valid if all confines pass" do
        c1 = mock 'c1', :valid? => true
        c2 = mock 'c2', :valid? => true

        Puppet::Provider::Confine.test(:true).expects(:new).returns(c1)
        Puppet::Provider::Confine.test(:false).expects(:new).returns(c2)

        confiner = Puppet::Provider::ConfineCollection.new
        confiner.confine :true => :bar, :false => :bee

        confiner.should be_valid
    end

    it "should not be valid if any confines fail" do
        c1 = stub 'c1', :valid? => true
        c2 = stub 'c2', :valid? => false

        Puppet::Provider::Confine.test(:true).expects(:new).returns(c1)
        Puppet::Provider::Confine.test(:false).expects(:new).returns(c2)

        confiner = Puppet::Provider::ConfineCollection.new
        confiner.confine :true => :bar, :false => :bee

        confiner.should_not be_valid
    end

    describe "when providing a summary" do
        before do
            @confiner = Puppet::Provider::ConfineCollection.new
        end

        it "should return a hash" do
            @confiner.summary.should be_instance_of(Hash)
        end

        it "should return an empty hash if the confiner is valid" do
            @confiner.summary.should == {}
        end

        it "should add each test type's summary to the hash" do
            @confiner.confine :true => :bar, :false => :bee
            Puppet::Provider::Confine.test(:true).expects(:summarize).returns :tsumm
            Puppet::Provider::Confine.test(:false).expects(:summarize).returns :fsumm

            @confiner.summary.should == {:true => :tsumm, :false => :fsumm}
        end

        it "should not include tests that return 0" do
            @confiner.confine :true => :bar, :false => :bee
            Puppet::Provider::Confine.test(:true).expects(:summarize).returns 0
            Puppet::Provider::Confine.test(:false).expects(:summarize).returns :fsumm

            @confiner.summary.should == {:false => :fsumm}
        end

        it "should not include tests that return empty arrays" do
            @confiner.confine :true => :bar, :false => :bee
            Puppet::Provider::Confine.test(:true).expects(:summarize).returns []
            Puppet::Provider::Confine.test(:false).expects(:summarize).returns :fsumm

            @confiner.summary.should == {:false => :fsumm}
        end

        it "should not include tests that return empty hashes" do
            @confiner.confine :true => :bar, :false => :bee
            Puppet::Provider::Confine.test(:true).expects(:summarize).returns({})
            Puppet::Provider::Confine.test(:false).expects(:summarize).returns :fsumm

            @confiner.summary.should == {:false => :fsumm}
        end
    end
end
