#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/provider/confine/exists'

describe Puppet::Provider::Confine::Exists do
    before do
        @confine = Puppet::Provider::Confine::Exists.new("/my/file")
        @confine.label = "eh"
    end

    it "should be named :exists" do
        Puppet::Provider::Confine::Exists.name.should == :exists
    end

    it "should use the 'pass?' method to test validity" do
        @confine.expects(:pass?).with("/my/file")
        @confine.valid?
    end

    it "should return false if the value is false" do
        @confine.pass?(false).should be_false
    end

    it "should return false if the value does not point to a file" do
        FileTest.expects(:exist?).with("/my/file").returns false
        @confine.pass?("/my/file").should be_false
    end

    it "should return true if the value points to a file" do
        FileTest.expects(:exist?).with("/my/file").returns true
        @confine.pass?("/my/file").should be_true
    end

    it "should produce a message saying that a file is missing" do
        @confine.message("/my/file").should be_include("does not exist")
    end

    describe "and the confine is for binaries" do
        before { @confine.stubs(:for_binary).returns true }
        it "should use its 'binary' method to look up the full path of the file" do
            @confine.expects(:binary).returns nil
            @confine.pass?("/my/file")
        end

        it "should return false if no binary can be found" do
            @confine.expects(:binary).with("/my/file").returns nil
            @confine.pass?("/my/file").should be_false
        end

        it "should return true if the binary can be found and the file exists" do
            @confine.expects(:binary).with("/my/file").returns "/my/file"
            FileTest.expects(:exist?).with("/my/file").returns true
            @confine.pass?("/my/file").should be_true
        end

        it "should return false if the binary can be found but the file does not exist" do
            @confine.expects(:binary).with("/my/file").returns "/my/file"
            FileTest.expects(:exist?).with("/my/file").returns true
            @confine.pass?("/my/file").should be_true
        end
    end

    it "should produce a summary containing all missing files" do
        FileTest.stubs(:exist?).returns true
        FileTest.expects(:exist?).with("/two").returns false
        FileTest.expects(:exist?).with("/four").returns false

        confine = Puppet::Provider::Confine::Exists.new %w{/one /two /three /four}
        confine.summary.should == %w{/two /four}
    end

    it "should summarize multiple instances by returning a flattened array of their summaries" do
        c1 = mock '1', :summary => %w{one}
        c2 = mock '2', :summary => %w{two}
        c3 = mock '3', :summary => %w{three}

        Puppet::Provider::Confine::Exists.summarize([c1, c2, c3]).should == %w{one two three}
    end
end
