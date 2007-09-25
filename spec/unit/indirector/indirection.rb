#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector'

describe Puppet::Indirector::Indirection do
    before do
        @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
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

describe Puppet::Indirector::Indirection, " when initializing" do
    it "should keep a reference to the indirecting model" do
        model = mock 'model'
        @indirection = Puppet::Indirector::Indirection.new(model, :myind)
        @indirection.model.should equal(model)
    end

    it "should set the name" do
        @indirection = Puppet::Indirector::Indirection.new(mock('model'), :myind)
        @indirection.name.should == :myind
    end

    it "should require indirections to have unique names" do
        @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
        proc { Puppet::Indirector::Indirection.new(:test) }.should raise_error(ArgumentError)
    end

    after do
        @indirection.delete if defined? @indirection
    end
end

describe Puppet::Indirector::Indirection, " when managing indirection instances" do
    it "should allow an indirection to be retrieved by name" do
        @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
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
        @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
        @terminus = mock 'terminus'
        @terminus_class = stub 'terminus class', :new => @terminus
    end

    it "should follow a convention on using per-model configuration parameters to determine the terminus class" do
        Puppet.settings.expects(:valid?).with('test_terminus').returns(true)
        Puppet.settings.expects(:value).with('test_terminus').returns(:foo)
        Puppet::Indirector::Terminus.expects(:terminus_class).with(:foo, :test).returns(@terminus_class)
        @indirection.terminus.should equal(@terminus)
    end

    it "should use a default system-wide configuration parameter parameter to determine the terminus class when no
    per-model configuration parameter is available" do
        Puppet.settings.expects(:valid?).with('test_terminus').returns(false)
        Puppet.settings.expects(:value).with(:default_terminus).returns(:foo)
        Puppet::Indirector::Terminus.expects(:terminus_class).with(:foo, :test).returns(@terminus_class)
        @indirection.terminus.should equal(@terminus)
    end

    it "should select the specified terminus class if a name is provided" do
        Puppet::Indirector::Terminus.expects(:terminus_class).with(:foo, :test).returns(@terminus_class)
        @indirection.terminus(:foo).should equal(@terminus)
    end

    it "should fail when the terminus class name is an empty string" do
        proc { @indirection.terminus("") }.should raise_error(ArgumentError)
    end

    it "should fail when the terminus class name is nil" do
        proc { @indirection.terminus(nil) }.should raise_error(ArgumentError)
    end

    it "should fail when the specified terminus class cannot be found" do
        Puppet::Indirector::Terminus.expects(:terminus_class).with(:foo, :test).returns(nil)
        proc { @indirection.terminus(:foo) }.should raise_error(ArgumentError)
    end

    after do
        @indirection.delete if defined? @indirection
    end
end

describe Puppet::Indirector::Indirection, " when managing terminus instances" do
    before do
        @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
        @terminus = mock 'terminus'
        @terminus_class = mock 'terminus class'
        Puppet::Indirector::Terminus.stubs(:terminus_class).with(:foo, :test).returns(@terminus_class)
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
        indirection = Puppet::Indirector::Indirection.new(mock('model'), :lazytest)
    end

    after do
        @indirection.delete
        Puppet::Indirector::Indirection.clear_cache
    end
end

describe Puppet::Indirector::Indirection, " when deciding whether to cache" do
    before do
        @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
        @terminus = mock 'terminus'
        @indirection.stubs(:terminus).returns(@terminus)
    end

    it "should not use a cache if there no cache setting" do
        Puppet.settings.expects(:valid?).with("test_cache").returns(false)
        @indirection.expects(:cache).never
        @terminus.stubs(:save)
        @indirection.save(:whev)
    end

    it "should not use a cache if the cache setting is set to 'none'" do
        Puppet.settings.expects(:valid?).with("test_cache").returns(true)
        Puppet.settings.expects(:value).with("test_cache").returns("none")
        @indirection.expects(:cache).never
        @terminus.stubs(:save)
        @indirection.save(:whev)
    end

    it "should use a cache if there is a related cache setting and it is not set to 'none'" do
        Puppet.settings.expects(:valid?).with("test_cache").returns(true)
        Puppet.settings.expects(:value).with("test_cache").returns("something")
        cache = mock 'cache'
        cache.expects(:save).with(:whev)
        @indirection.expects(:cache).returns(cache)
        @terminus.stubs(:save)
        @indirection.save(:whev)
    end

    after do
        @indirection.delete
        Puppet::Indirector::Indirection.clear_cache
    end
end

describe Puppet::Indirector::Indirection, " when using a cache" do
    before do
        Puppet.settings.stubs(:valid?).returns(true)
        Puppet.settings.stubs(:value).with("test_terminus").returns("test_terminus")
        @terminus_class = mock 'terminus_class'
        @terminus = mock 'terminus'
        @terminus_class.stubs(:new).returns(@terminus)
        @cache = mock 'cache'
        @cache_class = mock 'cache_class'
        Puppet::Indirector::Terminus.stubs(:terminus_class).with(:cache_terminus, :test).returns(@cache_class)
        Puppet::Indirector::Terminus.stubs(:terminus_class).with(:test_terminus, :test).returns(@terminus_class)
        @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
    end

    it "should copy all writing indirection calls to the cache terminus" do
        @cache_class.expects(:new).returns(@cache)
        Puppet.settings.stubs(:value).with("test_cache").returns("cache_terminus")
        @cache.expects(:save).with(:whev)
        @terminus.stubs(:save)
        @indirection.save(:whev)
    end

    it "should not create a cache terminus at initialization" do
        # This is weird, because all of the code is in the setup.  If we got
        # new() called on the cache class, we'd get an exception here.
    end

    it "should reuse the cache terminus" do
        @cache_class.expects(:new).returns(@cache)
        Puppet.settings.stubs(:value).with("test_cache").returns("cache_terminus")
        @indirection.cache.should equal(@cache)
        @indirection.cache.should equal(@cache)
    end

    it "should remove the cache terminus when all other terminus instances are cleared" do
        cache2 = mock 'cache2'
        @cache_class.stubs(:new).returns(@cache, cache2)
        Puppet.settings.stubs(:value).with("test_cache").returns("cache_terminus")
        @indirection.cache.should equal(@cache)
        @indirection.clear_cache
        @indirection.cache.should equal(cache2)
    end

    it "should look up the cache name when recreating the cache terminus after terminus instances have been cleared" do
        cache_class2 = mock 'cache_class2'
        cache2 = mock 'cache2'
        cache_class2.expects(:new).returns(cache2)
        @cache_class.expects(:new).returns(@cache)
        Puppet::Indirector::Terminus.stubs(:terminus_class).with(:other_cache, :test).returns(cache_class2)
        Puppet.settings.stubs(:value).with("test_cache").returns("cache_terminus", "other_cache")
        @indirection.cache.should equal(@cache)
        @indirection.clear_cache
        @indirection.cache.should equal(cache2)
    end

    after do
        @indirection.delete
        Puppet::Indirector::Indirection.clear_cache
    end
end
