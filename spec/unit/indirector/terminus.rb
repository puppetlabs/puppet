require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/defaults'
require 'puppet/indirector'

describe Puppet::Indirector::Terminus do
    before do
        @terminus = Class.new(Puppet::Indirector::Terminus)
    end

    it "should support the documentation methods" do
        @terminus.should respond_to(:desc)
    end

    # LAK:FIXME I don't really know the best way to test this kind of
    # requirement.
    it "should support a class-level name attribute" do
        @terminus.should respond_to(:name)
        @terminus.should respond_to(:name=)
    end

    it "should support a class-level indirection attribute" do
        @terminus.should respond_to(:indirection)
        @terminus.should respond_to(:indirection=)
    end

    it "should accept indirection instances as its indirection" do
        indirection = stub 'indirection', :is_a? => true
        proc { @terminus.indirection = indirection }.should_not raise_error
        @terminus.indirection.should equal(indirection)
    end

    it "should look up indirection instances when only a name has been provided" do
        indirection = mock 'indirection'
        Puppet::Indirector::Indirection.expects(:instance).with(:myind).returns(indirection)
        @terminus.indirection = :myind
        @terminus.indirection.should equal(indirection)
    end

    it "should fail when provided a name that does not resolve to an indirection" do
        Puppet::Indirector::Indirection.expects(:instance).with(:myind).returns(nil)
        proc { @terminus.indirection = :myind }.should raise_error(ArgumentError)
        @terminus.indirection.should be_nil
    end
end

describe Puppet::Indirector::Terminus, " when a terminus instance" do
    before do
        @indirection = stub 'indirection', :name => :myyaml
        @terminus_class = Class.new(Puppet::Indirector::Terminus)
        @terminus_class.name = :test
        @terminus_class.stubs(:indirection).returns(@indirection)
        @terminus = @terminus_class.new
    end

    it "should return the class's name as its name" do
        @terminus.name.should == :test
    end

    it "should return the class's indirection as its indirection" do
        @terminus.indirection.should equal(@indirection)
    end

    it "should require an associated indirection" do
        @terminus_class.expects(:indirection).returns(nil)
        proc { @terminus_class.new }.should raise_error(Puppet::DevError)
    end
end
