#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/util/cacher'

class CacheClassTest
    include Puppet::Util::Cacher

    cached_attr(:testing) { Time.now }

    def sa_cache
        attr_cache(:ca_cache) { Time.now }
    end
end

class CacheInstanceTest
    extend Puppet::Util::Cacher

    def self.sa_cache
        attr_cache(:ca_cache) { Time.now }
    end
end

describe "a cacher user using cached values", :shared => true do
    it "should use the block to generate a new value if none is present" do
        now = Time.now
        Time.stubs(:now).returns now
        @object.sa_cache.should equal(now)
    end

    it "should not test for validity if it is creating the value" do
        # This is only necessary in the class, since it has this value kicking
        # around.
        @object.instance_variable_set("@cacher_caches", nil)
        Puppet::Util::Cacher.expects(:valid?).never
        @object.sa_cache
    end

    it "should not consider cached false values to be missing values" do
        Puppet::Util::Cacher.stubs(:valid?).returns true

        # This is only necessary in the class, since it has this value kicking
        # around.
        @object.instance_variable_set("@cacher_caches", nil)
        Time.stubs(:now).returns false
        @object.sa_cache
        @object.sa_cache.should be_false
    end

    it "should return cached values if they are still valid" do
        Puppet::Util::Cacher.stubs(:valid?).returns true

        @object.sa_cache.should equal(@object.sa_cache)
    end

    it "should use the block to generate new values if the cached values are invalid" do
        Puppet::Util::Cacher.stubs(:valid?).returns false

        @object.sa_cache.should_not equal(@object.sa_cache)
    end

    it "should still cache values after an invalidation" do
        # Load the cache
        @object.sa_cache

        Puppet::Util::Cacher.invalidate
        @object.sa_cache.should equal(@object.sa_cache)
    end
end

describe Puppet::Util::Cacher do
    before do
        Puppet::Util::Cacher.invalidate
    end
    after do
        Puppet::Util::Cacher.invalidate
    end

    it "should have a method for invalidating caches" do
        Puppet::Util::Cacher.should respond_to(:invalidate)
    end

    it "should have a method for determining whether a cached value is valid" do
        Puppet::Util::Cacher.should respond_to(:valid?)
    end

    it "should consider cached values valid if the cached value was created and there was never an invalidation" do
        Puppet::Util::Cacher.instance_variable_set("@timestamp", nil)

        Puppet::Util::Cacher.should be_valid(Time.now)
    end

    it "should consider cached values valid if the cached value was created since the last invalidation" do
        Puppet::Util::Cacher.invalidate

        Puppet::Util::Cacher.should be_valid(Time.now + 1)
    end

    it "should consider cached values invalid if the cache was invalidated after the cached value was created" do 
        Puppet::Util::Cacher.invalidate

        Puppet::Util::Cacher.should_not be_valid(Time.now - 1)
    end

    describe "when used to extend a class" do
        before do
            @object = CacheClassTest.new
        end

        it_should_behave_like "a cacher user using cached values"

        it "should provide a class method for defining cached attributes" do
            CacheClassTest.private_methods.should be_include("cached_attr")
        end

        describe "and defining cached attributes" do
            it "should create an accessor for the cached attribute" do
                @object.should respond_to(:testing)
            end

            it "should return a value calculated from the provided block" do
                time = Time.now
                Time.stubs(:now).returns time
                @object.testing.should equal(time)
            end

            it "should return the cached value from the getter if the value is still valid" do
                value = @object.testing
                Puppet::Util::Cacher.expects(:valid?).returns true
                @object.testing.should equal(value)
            end

            it "should regenerate and return a new value using the provided block if the value is no longer valid" do
                value = @object.testing
                Puppet::Util::Cacher.expects(:valid?).returns false
                @object.testing.should_not equal(value)
            end
        end

        it "should provide a private instance method for caching values" do
            @object.private_methods.should be_include("attr_cache")
        end

    end

    describe "when included in a class" do
        before do
            @object = CacheInstanceTest
        end

        it "should provide a private instance method for caching values" do
            CacheInstanceTest.private_methods.should be_include("attr_cache")
        end

        it_should_behave_like "a cacher user using cached values"
    end
end
