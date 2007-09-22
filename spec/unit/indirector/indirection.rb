#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector'

describe Puppet::Indirector::Indirection, " when initializing" do
    it "should set the name" do
        @indirection = Puppet::Indirector::Indirection.new(:myind)
        @indirection.name.should == :myind
    end

    it "should require indirections to have unique names" do
        @indirection = Puppet::Indirector::Indirection.new(:test)
        proc { Puppet::Indirector::Indirection.new(:test) }.should raise_error(ArgumentError)
    end

    after do
        @indirection.delete if defined? @indirection
    end
end

describe Puppet::Indirector::Indirection, " when managing indirection instances" do
    it "should allow an indirection to be retrieved by name" do
        @indirection = Puppet::Indirector::Indirection.new(:test)
        Puppet::Indirector::Indirection.instance(:test).should equal(@indirection)
    end

    it "should return nil when the named indirection has not been created" do
        Puppet::Indirector::Indirection.instance(:test).should be_nil
    end

    after do
        @indirection.delete if defined? @indirection
    end
end

describe Puppet::Indirector::Indirection, " when choosing terminus types" do
    before do
        @indirection = Puppet::Indirector::Indirection.new(:test)
        @terminus = mock 'terminus'
        @terminus_class = stub 'terminus class', :new => @terminus
    end

    it "should follow a convention on using per-model configuration parameters to determine the terminus class" do
        Puppet.config.expects(:valid?).with('test_terminus').returns(true)
        Puppet.config.expects(:value).with('test_terminus').returns(:foo)
        Puppet::Indirector::Terminus.expects(:terminus_class).with(:test, :foo).returns(@terminus_class)
        @indirection.terminus.should equal(@terminus)
    end

    it "should use a default system-wide configuration parameter parameter to determine the terminus class when no
    per-model configuration parameter is available" do
        Puppet.config.expects(:valid?).with('test_terminus').returns(false)
        Puppet.config.expects(:value).with(:default_terminus).returns(:foo)
        Puppet::Indirector::Terminus.expects(:terminus_class).with(:test, :foo).returns(@terminus_class)
        @indirection.terminus.should equal(@terminus)
    end

    it "should select the specified terminus class if a name is provided" do
        Puppet::Indirector::Terminus.expects(:terminus_class).with(:test, :foo).returns(@terminus_class)
        @indirection.terminus(:foo).should equal(@terminus)
    end

    it "should fail when the terminus class name is an empty string" do
        proc { @indirection.terminus("") }.should raise_error(ArgumentError)
    end

    it "should fail when the terminus class name is nil" do
        proc { @indirection.terminus(nil) }.should raise_error(ArgumentError)
    end

    it "should fail when the specified terminus class cannot be found" do
        Puppet::Indirector::Terminus.expects(:terminus_class).with(:test, :foo).returns(nil)
        proc { @indirection.terminus(:foo) }.should raise_error(ArgumentError)
    end

    after do
        @indirection.delete if defined? @indirection
    end
end

describe Puppet::Indirector::Indirection, " when managing terminus instances" do
    before do
        @indirection = Puppet::Indirector::Indirection.new(:test)
        @terminus = mock 'terminus'
        @terminus_class = mock 'terminus class'
        Puppet::Indirector::Terminus.stubs(:terminus_class).with(:test, :foo).returns(@terminus_class)
    end

    it "should create an instance of the chosen terminus class" do
        @terminus_class.stubs(:new).returns(@terminus)
        @indirection.terminus(:foo).should equal(@terminus)
    end

    it "should allow the clearance of cached terminus instances" do
        terminus1 = mock 'terminus1'
        terminus2 = mock 'terminus2'
        @terminus_class.stubs(:new).returns(terminus1, terminus2, ArgumentError)
        @indirection.terminus(:foo).should equal(terminus1)
        @indirection.class.clear_cache
        @indirection.terminus(:foo).should equal(terminus2)
    end

    # Make sure it caches the terminus.
    it "should return the same terminus instance each time for a given name" do
        @terminus_class.stubs(:new).returns(@terminus)
        @indirection.terminus(:foo).should equal(@terminus)
        @indirection.terminus(:foo).should equal(@terminus)
    end

    it "should not create a terminus instance until one is actually needed" do
        Puppet::Indirector.expects(:terminus).never
        indirection = Puppet::Indirector::Indirection.new(:lazytest)
    end

    after do
        @indirection.delete
        Puppet::Indirector::Indirection.clear_cache
    end
end

describe Puppet::Indirector::Indirection do
  before do
        @indirection = Puppet::Indirector::Indirection.new(:test)
        @terminus = mock 'terminus'
        @indirection.stubs(:terminus).returns(@terminus)
  end
  
  it "should handle lookups of a model instance by letting the appropriate terminus perform the lookup" do
      @terminus.expects(:find).with(:mything).returns(:whev)
      @indirection.find(:mything).should == :whev
  end

  it "should handle removing model instances from a terminus letting the appropriate terminus remove the instance" do
      @terminus.expects(:destroy).with(:mything).returns(:whev)
      @indirection.destroy(:mything).should == :whev
  end
  
  it "should handle searching for model instances by letting the appropriate terminus find the matching instances" do
      @terminus.expects(:search).with(:mything).returns(:whev)
      @indirection.search(:mything).should == :whev
  end
  
  it "should handle storing a model instance by letting the appropriate terminus store the instance" do
      @terminus.expects(:save).with(:mything).returns(:whev)
      @indirection.save(:mything).should == :whev
  end

    after do
        @indirection.delete
        Puppet::Indirector::Indirection.clear_cache
    end
end
