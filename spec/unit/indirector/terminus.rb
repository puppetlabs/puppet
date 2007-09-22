require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/defaults'
require 'puppet/indirector'

describe Puppet::Indirector::Terminus do
    before do
        Puppet::Indirector::Terminus.stubs(:register_terminus_class)

        @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil
        Puppet::Indirector::Indirection.stubs(:instance).with(:mystuff).returns(@indirection)
        @abstract_terminus = Class.new(Puppet::Indirector::Terminus) do
            def self.to_s
                "Abstract"
            end
        end
        @terminus = Class.new(@abstract_terminus) do
            def self.to_s
                "Terminus::Type::MyStuff"
            end
        end
    end

    it "should provide a method for setting terminus class documentation" do
        @terminus.should respond_to(:desc)
    end

    it "should support a class-level name attribute" do
        @terminus.should respond_to(:name)
    end

    it "should support a class-level indirection attribute" do
        @terminus.should respond_to(:indirection)
    end

    it "should support a class-level terminus-type attribute" do
        @terminus.should respond_to(:terminus_type)
    end

    it "should accept indirection instances as its indirection" do
        indirection = stub 'indirection', :is_a? => true, :register_terminus_type => nil
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

# LAK: This could reasonably be in the Indirection instances, too.  It doesn't make
# a whole heckuva lot of difference, except that with the instance loading in
# the Terminus base class, we have to have a check to see if we're already
# instance-loading a given terminus class type.
describe Puppet::Indirector::Terminus, " when managing terminus classes" do
    it "should provide a method for registering terminus classes" do
        Puppet::Indirector::Terminus.should respond_to(:register_terminus_class)
    end

    it "should provide a method for returning terminus classes by name and type" do
        terminus = stub 'terminus_type', :terminus_type => :abstract, :name => :whatever
        Puppet::Indirector::Terminus.register_terminus_class(terminus)
        Puppet::Indirector::Terminus.terminus_class(:abstract, :whatever).should equal(terminus)
    end

    it "should set up autoloading for any terminus class types requested" do
        Puppet::Indirector::Terminus.expects(:instance_load).with(:test2, "puppet/indirector/test2")
        Puppet::Indirector::Terminus.terminus_class(:test2, :whatever)
    end

    it "should load terminus classes that are not found" do
        # Set up instance loading; it would normally happen automatically
        Puppet::Indirector::Terminus.instance_load :test1, "puppet/indirector/test1"
        Puppet::Indirector::Terminus.instance_loader(:test1).expects(:load).with(:yay)
        Puppet::Indirector::Terminus.terminus_class(:test1, :yay)
    end

    it "should fail when no indirection can be found" do
        Puppet::Indirector::Indirection.expects(:instance).with(:myindirection).returns(nil)

        @abstract_terminus = Class.new(Puppet::Indirector::Terminus) do
            def self.to_s
                "Abstract"
            end
        end
        proc {
            @terminus = Class.new(@abstract_terminus) do
                def self.to_s
                    "MyIndirection"
                end
            end
        }.should raise_error(ArgumentError)
    end

    it "should register the terminus class with the terminus base class" do
        Puppet::Indirector::Terminus.expects(:register_terminus_class).with do |type|
            type.terminus_type == :abstract and type.name == :myindirection
        end
        @indirection = stub 'indirection', :name => :myind, :register_terminus_type => nil
        Puppet::Indirector::Indirection.expects(:instance).with(:myindirection).returns(@indirection)

        @abstract_terminus = Class.new(Puppet::Indirector::Terminus) do
            def self.to_s
                "Abstract"
            end
        end

        @terminus = Class.new(@abstract_terminus) do
            def self.to_s
                "MyIndirection"
            end
        end
    end
end

describe Puppet::Indirector::Terminus, " when creating terminus class types" do
    before do
        Puppet::Indirector::Terminus.stubs(:register_terminus_class)
        @subclass = Class.new(Puppet::Indirector::Terminus) do
            def self.to_s
                "Puppet::Indirector::Terminus::MyTermType"
            end
        end
    end

    it "should set the name of the abstract subclass to be its class constant" do
        @subclass.name.should equal(:mytermtype)
    end

    it "should mark abstract terminus types as such" do
        @subclass.should be_abstract_terminus
    end

    it "should not allow instances of abstract subclasses to be created" do
        proc { @subclass.new }.should raise_error(Puppet::DevError)
    end
end

describe Puppet::Indirector::Terminus, " when creating terminus classes" do
    before do
        Puppet::Indirector::Terminus.stubs(:register_terminus_class)

        @indirection = stub 'indirection', :name => :myind, :register_terminus_type => nil
        Puppet::Indirector::Indirection.expects(:instance).with(:myindirection).returns(@indirection)

        @abstract_terminus = Class.new(Puppet::Indirector::Terminus) do
            def self.to_s
                "Abstract"
            end
        end
        @terminus = Class.new(@abstract_terminus) do
            def self.to_s
                "MyIndirection"
            end
        end
    end

    it "should associate the subclass with an indirection based on the subclass constant" do
        @terminus.indirection.should equal(@indirection)
    end

    it "should set the subclass's type to the abstract terminus name" do
        @terminus.terminus_type.should == :abstract
    end

    it "should set the subclass's name to the indirection name" do
        @terminus.name.should == :myindirection
    end
end

describe Puppet::Indirector::Terminus, " when a terminus instance" do
    before do
        Puppet::Indirector::Terminus.stubs(:register_terminus_class)
        @indirection = stub 'indirection', :name => :myyaml, :register_terminus_type => nil
        Puppet::Indirector::Indirection.stubs(:instance).with(:mystuff).returns(@indirection)
        @abstract_terminus = Class.new(Puppet::Indirector::Terminus) do
            def self.to_s
                "Abstract"
            end
        end
        @terminus_class = Class.new(@abstract_terminus) do
            def self.to_s
                "MyStuff"
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

    it "should set the instances's type to the abstract terminus type's name" do
        @terminus.terminus_type.should == :abstract
    end
end
