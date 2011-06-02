#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/defaults'
require 'puppet/indirector'
require 'puppet/indirector/file'

describe Puppet::Indirector::Terminus, :'fails_on_ruby_1.9.2' => true do
  before :each do
    Puppet::Indirector::Terminus.stubs(:register_terminus_class)
    @indirection = stub 'indirection', :name => :my_stuff, :register_terminus_type => nil
    Puppet::Indirector::Indirection.stubs(:instance).with(:my_stuff).returns(@indirection)
    @abstract_terminus = Class.new(Puppet::Indirector::Terminus) do
      def self.to_s
        "Testing::Abstract"
      end
    end
    @terminus_class = Class.new(@abstract_terminus) do
      def self.to_s
        "MyStuff::TermType"
      end
    end
    @terminus = @terminus_class.new
  end

  describe Puppet::Indirector::Terminus do

    it "should provide a method for setting terminus class documentation" do
      @terminus_class.should respond_to(:desc)
    end

    it "should support a class-level name attribute" do
      @terminus_class.should respond_to(:name)
    end

    it "should support a class-level indirection attribute" do
      @terminus_class.should respond_to(:indirection)
    end

    it "should support a class-level terminus-type attribute" do
      @terminus_class.should respond_to(:terminus_type)
    end

    it "should support a class-level model attribute" do
      @terminus_class.should respond_to(:model)
    end

    it "should accept indirection instances as its indirection" do
      indirection = stub 'indirection', :is_a? => true, :register_terminus_type => nil
      proc { @terminus_class.indirection = indirection }.should_not raise_error
      @terminus_class.indirection.should equal(indirection)
    end

    it "should look up indirection instances when only a name has been provided" do
      indirection = mock 'indirection'
      Puppet::Indirector::Indirection.expects(:instance).with(:myind).returns(indirection)
      @terminus_class.indirection = :myind
      @terminus_class.indirection.should equal(indirection)
    end

    it "should fail when provided a name that does not resolve to an indirection" do
      Puppet::Indirector::Indirection.expects(:instance).with(:myind).returns(nil)
      proc { @terminus_class.indirection = :myind }.should raise_error(ArgumentError)

      # It shouldn't overwrite our existing one (or, more normally, it shouldn't set
      # anything).
      @terminus_class.indirection.should equal(@indirection)
    end
  end

  describe Puppet::Indirector::Terminus, " when creating terminus classes" do
    it "should associate the subclass with an indirection based on the subclass constant" do
      @terminus.indirection.should equal(@indirection)
    end

    it "should set the subclass's type to the abstract terminus name" do
      @terminus.terminus_type.should == :abstract
    end

    it "should set the subclass's name to the indirection name" do
      @terminus.name.should == :term_type
    end

    it "should set the subclass's model to the indirection model" do
      @indirection.expects(:model).returns :yay
      @terminus.model.should == :yay
    end
  end

  describe Puppet::Indirector::Terminus, " when a terminus instance" do

    it "should return the class's name as its name" do
      @terminus.name.should == :term_type
    end

    it "should return the class's indirection as its indirection" do
      @terminus.indirection.should equal(@indirection)
    end

    it "should set the instances's type to the abstract terminus type's name" do
      @terminus.terminus_type.should == :abstract
    end

    it "should set the instances's model to the indirection's model" do
      @indirection.expects(:model).returns :yay
      @terminus.model.should == :yay
    end
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
    terminus = stub 'terminus_type', :name => :abstract, :indirection_name => :whatever
    Puppet::Indirector::Terminus.register_terminus_class(terminus)
    Puppet::Indirector::Terminus.terminus_class(:whatever, :abstract).should equal(terminus)
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

  it "should fail when no indirection can be found", :'fails_on_ruby_1.9.2' => true do
    Puppet::Indirector::Indirection.expects(:instance).with(:my_indirection).returns(nil)

    @abstract_terminus = Class.new(Puppet::Indirector::Terminus) do
      def self.to_s
        "Abstract"
      end
    end
    proc {
      @terminus = Class.new(@abstract_terminus) do
        def self.to_s
          "MyIndirection::TestType"
        end
      end
    }.should raise_error(ArgumentError)
  end

  it "should register the terminus class with the terminus base class", :'fails_on_ruby_1.9.2' => true do
    Puppet::Indirector::Terminus.expects(:register_terminus_class).with do |type|
      type.indirection_name == :my_indirection and type.name == :test_terminus
    end
    @indirection = stub 'indirection', :name => :my_indirection, :register_terminus_type => nil
    Puppet::Indirector::Indirection.expects(:instance).with(:my_indirection).returns(@indirection)

    @abstract_terminus = Class.new(Puppet::Indirector::Terminus) do
      def self.to_s
        "Abstract"
      end
    end

    @terminus = Class.new(@abstract_terminus) do
      def self.to_s
        "MyIndirection::TestTerminus"
      end
    end
  end
end

describe Puppet::Indirector::Terminus, " when parsing class constants for indirection and terminus names" do
  before do
    @subclass = mock 'subclass'
    @subclass.stubs(:to_s).returns("TestInd::OneTwo")
    @subclass.stubs(:mark_as_abstract_terminus)
    Puppet::Indirector::Terminus.stubs(:register_terminus_class)
  end

  it "should fail when anonymous classes are used" do
    proc { Puppet::Indirector::Terminus.inherited(Class.new) }.should raise_error(Puppet::DevError)
  end

  it "should use the last term in the constant for the terminus class name" do
    @subclass.expects(:name=).with(:one_two)
    @subclass.stubs(:indirection=)
    Puppet::Indirector::Terminus.inherited(@subclass)
  end

  it "should convert the terminus name to a downcased symbol" do
    @subclass.expects(:name=).with(:one_two)
    @subclass.stubs(:indirection=)
    Puppet::Indirector::Terminus.inherited(@subclass)
  end

  it "should use the second to last term in the constant for the indirection name" do
    @subclass.expects(:indirection=).with(:test_ind)
    @subclass.stubs(:name=)
    @subclass.stubs(:terminus_type=)
    Puppet::Indirector::File.inherited(@subclass)
  end

  it "should convert the indirection name to a downcased symbol" do
    @subclass.expects(:indirection=).with(:test_ind)
    @subclass.stubs(:name=)
    @subclass.stubs(:terminus_type=)
    Puppet::Indirector::File.inherited(@subclass)
  end

  it "should convert camel case to lower case with underscores as word separators" do
    @subclass.expects(:name=).with(:one_two)
    @subclass.stubs(:indirection=)

    Puppet::Indirector::Terminus.inherited(@subclass)
  end
end

describe Puppet::Indirector::Terminus, " when creating terminus class types", :'fails_on_ruby_1.9.2' => true do
  before do
    Puppet::Indirector::Terminus.stubs(:register_terminus_class)
    @subclass = Class.new(Puppet::Indirector::Terminus) do
      def self.to_s
        "Puppet::Indirector::Terminus::MyTermType"
      end
    end
  end

  it "should set the name of the abstract subclass to be its class constant" do
    @subclass.name.should equal(:my_term_type)
  end

  it "should mark abstract terminus types as such" do
    @subclass.should be_abstract_terminus
  end

  it "should not allow instances of abstract subclasses to be created" do
    proc { @subclass.new }.should raise_error(Puppet::DevError)
  end
end

describe Puppet::Indirector::Terminus, " when listing terminus classes" do
  it "should list the terminus files available to load" do
    Puppet::Util::Autoload.any_instance.stubs(:files_to_load).returns ["/foo/bar/baz", "/max/runs/marathon"]
    Puppet::Indirector::Terminus.terminus_classes('my_stuff').should == [:baz, :marathon]
  end
end
