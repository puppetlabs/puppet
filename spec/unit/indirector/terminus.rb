require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/defaults'
require 'puppet/indirector'

describe Puppet::Indirector::Terminus do
    it "should support the documentation methods" do
        Puppet::Indirector::Terminus.should respond_to(:desc)
    end

    # LAK:FIXME I don't really know the best way to test this kind of
    # requirement.
    it "should support a class-level name attribute" do
        Puppet::Indirector::Terminus.should respond_to(:name)
        Puppet::Indirector::Terminus.should respond_to(:name=)
    end

    it "should support a class-level indirection attribute" do
        Puppet::Indirector::Terminus.should respond_to(:indirection)
        Puppet::Indirector::Terminus.should respond_to(:indirection=)
    end
end

describe Puppet::Indirector::Terminus, " when a terminus instance" do
    before do
        @terminus_class = Class.new(Puppet::Indirector::Terminus) do
            @name = :test
            @indirection = :whatever
        end
        @terminus = @terminus_class.new
    end

    it "should return the class's name as its name" do
        @terminus.name.should == :test
    end

    it "should return the class's indirection as its indirection" do
        @terminus.indirection.should == :whatever
    end
end
