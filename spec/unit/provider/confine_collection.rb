#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/provider/confine_collection'

describe Puppet::Provider::ConfineCollection do
    it "should be able to add confines" do
        Puppet::Provider::ConfineCollection.new.should respond_to(:confine)
    end

    it "should create a Confine instance for every confine call" do
        Puppet::Provider::Confine.expects(:new).with(:foo, :bar).returns "eh"
        Puppet::Provider::Confine.expects(:new).with(:baz, :bee).returns "eh"
        Puppet::Provider::ConfineCollection.new.confine :foo => :bar, :baz => :bee
    end

    it "should mark each confine as a binary confine if :for_binary => true is included" do
        confine = mock 'confine'
        confine.expects(:for_binary=).with true
        Puppet::Provider::Confine.expects(:new).with(:foo, :bar).returns confine
        Puppet::Provider::ConfineCollection.new.confine :foo => :bar, :for_binary => true
    end

    it "should be valid if no confines are present" do
        Puppet::Provider::ConfineCollection.new.should be_valid
    end

    it "should be valid if all confines are valid" do
        c1 = mock 'c1', :valid? => true
        c2 = mock 'c2', :valid? => true

        Puppet::Provider::Confine.expects(:new).times(2).returns(c1).then.returns(c2)

        confiner = Puppet::Provider::ConfineCollection.new
        confiner.confine :foo => :bar, :baz => :bee

        confiner.should be_valid
    end

    it "should not be valid if any confines are valid" do
        c1 = mock 'c1', :valid? => true
        c2 = mock 'c2', :valid? => false

        Puppet::Provider::Confine.expects(:new).times(2).returns(c1).then.returns(c2)

        confiner = Puppet::Provider::ConfineCollection.new
        confiner.confine :foo => :bar, :baz => :bee

        confiner.should_not be_valid
    end

    describe "when providing a complete result" do
        before do
            @confiner = Puppet::Provider::ConfineCollection.new
        end

        it "should return a hash" do
            @confiner.result.should be_instance_of(Hash)
        end

        it "should return an empty hash if the confiner is valid" do
            @confiner.result.should == {}
        end

        it "should contain the number of incorrectly false values" do
            c1 = stub 'c1', :result => [true, false, true], :test => :true
            c2 = stub 'c2', :result => [false, true, false], :test => :true

            Puppet::Provider::Confine.expects(:new).times(2).returns(c1).then.returns(c2)

            confiner = Puppet::Provider::ConfineCollection.new
            confiner.confine :foo => :bar, :baz => :bee

            confiner.result[:true].should == 3
        end

        it "should contain the number of incorrectly true values" do
            c1 = stub 'c1', :result => [true, false, true], :test => :false
            c2 = stub 'c2', :result => [false, true, false], :test => :false

            Puppet::Provider::Confine.expects(:new).times(2).returns(c1).then.returns(c2)

            confiner = Puppet::Provider::ConfineCollection.new
            confiner.confine :foo => :bar, :baz => :bee

            confiner.result[:false].should == 3
        end

        it "should contain the missing files" do
            FileTest.stubs(:exist?).returns true
            FileTest.expects(:exist?).with("/two").returns false
            FileTest.expects(:exist?).with("/four").returns false

            confiner = Puppet::Provider::ConfineCollection.new
            confiner.confine :exists => %w{/one /two}
            confiner.confine :exists => %w{/three /four}

            confiner.result[:exists].should == %w{/two /four}
        end

        it "should contain a hash of facts and the allowed values" do
            Facter.expects(:value).with(:foo).returns "yay"
            Facter.expects(:value).with(:bar).returns "boo"
            confiner = Puppet::Provider::ConfineCollection.new
            confiner.confine :foo => "yes", :bar => "boo"

            result = confiner.result
            result[:facter][:foo].should == %w{yes}
            result[:facter][:bar].should be_nil
        end
    end
end
