#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector'

describe Puppet::Indirector::Indirection do
    before do
        @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
        @terminus = stub 'terminus', :fresh? => false
        @indirection.stubs(:terminus).returns(@terminus)
        @instance = stub 'instance', :version => nil, :version= => nil, :name => "whatever"
        @name = :mything
    end
  
    it "should not attempt to set a timestamp if the terminus cannot find the instance" do
        @terminus.expects(:find).with(@name).returns(nil)
        proc { @indirection.find(@name) }.should_not raise_error
    end
  
    it "should handle lookups of a model instance by letting the appropriate terminus perform the lookup" do
        @terminus.expects(:find).with(@name).returns(@instance)
        @indirection.find(@name).should == @instance
    end

    it "should handle removing model instances from a terminus letting the appropriate terminus remove the instance" do
        @terminus.expects(:destroy).with(@name).returns(@instance)
        @indirection.destroy(@name).should == @instance
    end
  
    it "should handle searching for model instances by letting the appropriate terminus find the matching instances" do
        @terminus.expects(:search).with(@name).returns(@instance)
        @indirection.search(@name).should == @instance
    end
  
    it "should handle storing a model instance by letting the appropriate terminus store the instance" do
        @terminus.expects(:save).with(@instance).returns(@instance)
        @indirection.save(@instance).should == @instance
    end

    it "should add versions to found instances that do not already have them" do
        @terminus.expects(:find).with(@name).returns(@instance)
        time = mock 'time'
        time.expects(:utc).returns(:mystamp)
        Time.expects(:now).returns(time)
        @instance.expects(:version=).with(:mystamp)
        @indirection.find(@name)
    end

    it "should add versions to saved instances that do not already have them" do
        time = mock 'time'
        time.expects(:utc).returns(:mystamp)
        Time.expects(:now).returns(time)
        @instance.expects(:version=).with(:mystamp)
        @terminus.stubs(:save)
        @indirection.save(@instance)
    end

    # We've already tested this, basically, but...
    it "should use the current time in UTC for versions" do
        @instance.expects(:version=).with do |time|
            time.utc?
        end
        @terminus.stubs(:save)
        @indirection.save(@instance)
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

describe Puppet::Indirector::Indirection, " when specifying terminus types" do
    before do
        @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
        @terminus = mock 'terminus'
        @terminus_class = stub 'terminus class', :new => @terminus
    end

    it "should allow specification of a terminus type" do
        @indirection.should respond_to(:terminus_class=)
    end

    it "should fail to redirect if no terminus type has been specified" do
        proc { @indirection.find("blah") }.should raise_error(Puppet::DevError)
    end

    it "should fail when the terminus class name is an empty string" do
        proc { @indirection.terminus_class = "" }.should raise_error(ArgumentError)
    end

    it "should fail when the terminus class name is nil" do
        proc { @indirection.terminus_class = nil }.should raise_error(ArgumentError)
    end

    it "should fail when the specified terminus class cannot be found" do
        Puppet::Indirector::Terminus.expects(:terminus_class).with(:foo, :test).returns(nil)
        proc { @indirection.terminus_class = :foo }.should raise_error(ArgumentError)
    end

    it "should select the specified terminus class if a terminus class name is provided" do
        Puppet::Indirector::Terminus.expects(:terminus_class).with(:foo, :test).returns(@terminus_class)
        @indirection.terminus(:foo).should equal(@terminus)
    end

    it "should use the configured terminus class if no terminus name is specified" do
        Puppet::Indirector::Terminus.stubs(:terminus_class).with(:foo, :test).returns(@terminus_class)
        @indirection.terminus_class = :foo
        @indirection.terminus().should equal(@terminus)
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
        @terminus_class = mock 'terminus class'
        @terminus_class.stubs(:new).returns(@terminus)
        Puppet::Indirector::Terminus.stubs(:terminus_class).with(:foo, :test).returns(@terminus_class)
        @indirection.terminus_class = :foo
    end

    it "should provide a method for setting the cache terminus class" do
        @indirection.should respond_to(:cache_class=)
    end

    it "should fail to cache if no cache type has been specified" do
        proc { @indirection.cache }.should raise_error(Puppet::DevError)
    end

    it "should fail to set the cache class when the cache class name is an empty string" do
        proc { @indirection.cache_class = "" }.should raise_error(ArgumentError)
    end

    it "should fail to set the cache class when the cache class name is nil" do
        proc { @indirection.cache_class = nil }.should raise_error(ArgumentError)
    end

    it "should fail to set the cache class when the specified cache class cannot be found" do
        Puppet::Indirector::Terminus.expects(:terminus_class).with(:foo, :test).returns(nil)
        proc { @indirection.cache_class = :foo }.should raise_error(ArgumentError)
    end

    after do
        @indirection.delete
        Puppet::Indirector::Indirection.clear_cache
    end
end

module IndirectionCaching
    def setup
        Puppet.settings.stubs(:value).with("test_terminus").returns("test_terminus")
        @terminus_class = mock 'terminus_class'
        @terminus = mock 'terminus'
        @terminus_class.stubs(:new).returns(@terminus)
        @cache = mock 'cache'
        @cache_class = mock 'cache_class'
        Puppet::Indirector::Terminus.stubs(:terminus_class).with(:cache_terminus, :test).returns(@cache_class)
        Puppet::Indirector::Terminus.stubs(:terminus_class).with(:test_terminus, :test).returns(@terminus_class)
        @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
        @indirection.terminus_class = :test_terminus
    end

    def teardown
        @indirection.delete
        Puppet::Indirector::Indirection.clear_cache
    end
end

describe Puppet::Indirector::Indirection, " when managing the cache terminus" do
    include IndirectionCaching

    it "should not create a cache terminus at initialization" do
        # This is weird, because all of the code is in the setup.  If we got
        # new() called on the cache class, we'd get an exception here.
    end

    it "should reuse the cache terminus" do
        @cache_class.expects(:new).returns(@cache)
        Puppet.settings.stubs(:value).with("test_cache").returns("cache_terminus")
        @indirection.cache_class = :cache_terminus
        @indirection.cache.should equal(@cache)
        @indirection.cache.should equal(@cache)
    end

    it "should remove the cache terminus when all other terminus instances are cleared" do
        cache2 = mock 'cache2'
        @cache_class.stubs(:new).returns(@cache, cache2)
        @indirection.cache_class = :cache_terminus
        @indirection.cache.should equal(@cache)
        @indirection.clear_cache
        @indirection.cache.should equal(cache2)
    end
end

describe Puppet::Indirector::Indirection, " when saving and using a cache" do
    include IndirectionCaching

    before do
        @indirection.cache_class = :cache_terminus
        @cache_class.expects(:new).returns(@cache)
        @name = "testing"
        @instance = stub 'instance', :version => 5, :name => @name
    end

    it "should not update the cache or terminus if the new object is not different" do
        @cache.expects(:fresh?).with(@name, 5).returns(true)
        @indirection.save(@instance)
    end

    it "should update the original and the cache if the cached object is different" do
        @cache.expects(:fresh?).with(@name, 5).returns(false)
        @terminus.expects(:save).with(@instance)
        @cache.expects(:save).with(@instance)
        @indirection.save(@instance)
    end
end

describe Puppet::Indirector::Indirection, " when finding and using a cache" do
    include IndirectionCaching

    before do
        @indirection.cache_class = :cache_terminus
        @cache_class.expects(:new).returns(@cache)
    end

    it "should return the cached object if the cache is up to date" do
        cached = mock 'cached object'

        name = "myobject"

        @cache.expects(:version).with(name).returns(1)
        @terminus.expects(:fresh?).with(name, 1).returns(true)

        @cache.expects(:find).with(name).returns(cached)

        @indirection.find(name).should equal(cached)
    end

    it "should return the original object if the cache is not up to date" do
        real = stub 'real object', :version => 1

        name = "myobject"

        @cache.expects(:version).with(name).returns(1)
        @cache.stubs(:save)
        @terminus.expects(:fresh?).with(name, 1).returns(false)

        @terminus.expects(:find).with(name).returns(real)

        @indirection.find(name).should equal(real)
    end

    it "should cache any newly returned objects" do
        real = stub 'real object', :version => 1

        name = "myobject"

        @cache.expects(:version).with(name).returns(1)
        @terminus.expects(:fresh?).with(name, 1).returns(false)

        @terminus.expects(:find).with(name).returns(real)
        @cache.expects(:save).with(real)

        @indirection.find(name).should equal(real)
    end
end
