require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/defaults'
require 'puppet/indirector'

describe Puppet::Indirector::Terminus do
    before do
        @indirection = stub 'indirection', :name => :mystuff
        Puppet::Indirector::Indirection.stubs(:instance).with(:mystuff).returns(@indirection)
        @terminus = Class.new(Puppet::Indirector::Terminus) do
            def self.to_s
                "Terminus::Type::MyStuff"
            end
        end
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

        # It shouldn't overwrite our existing one (or, more normally, it shouldn't set
        # anything).
        @terminus.indirection.should equal(@indirection)
    end
end

describe Puppet::Indirector::Terminus, " when being subclassed" do
    it "should associate the subclass with an indirection based on the subclass constant" do
        indirection = mock 'indirection'
        Puppet::Indirector::Indirection.expects(:instance).with(:myindirection).returns(indirection)

        klass = Class.new(Puppet::Indirector::Terminus) do
            def self.to_s
                "Puppet::Indirector::Terminus::MyIndirection"
            end
        end

        klass.indirection.should equal(indirection)
    end

    it "should fail when the terminus subclass does not include its parent class in the constant path" do
        indirection = mock 'indirection'
        Puppet::Indirector::Indirection.expects(:instance).with(:myindirection).returns(indirection)

        proc {
            klass = Class.new(Puppet::Indirector::Terminus) do
                def self.to_s
                    "MyIndirection"
                end
            end
        }.should raise_error(ArgumentError)
    end

    it "should set the subclass's name to the terminus type" do
        indirection = mock 'indirection'
        Puppet::Indirector::Indirection.expects(:instance).with(:myindirection).returns(indirection)

        klass = Class.new(Puppet::Indirector::Terminus) do
            def self.to_s
                "Puppet::Indirector::Terminus::Yaml::MyIndirection"
            end
        end

        klass.name.should == :yaml
    end
end

describe Puppet::Indirector::Terminus, " when a terminus instance" do
    before do
        @indirection = stub 'indirection', :name => :myyaml
        Puppet::Indirector::Indirection.stubs(:instance).with(:mystuff).returns(@indirection)
        @terminus_class = Class.new(Puppet::Indirector::Terminus) do
            def self.to_s
                "Terminus::Type::MyStuff"
            end
        end
        @terminus_class.name = :test
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
