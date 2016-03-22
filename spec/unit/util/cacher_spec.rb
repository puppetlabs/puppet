#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/cacher'

class CacheTest
  @@count = 0

  def self.count
    @@count
  end

  include Puppet::Util::Cacher

  cached_attr(:instance_cache, 10) do
    @@count += 1
    {:number => @@count}
  end
end

describe Puppet::Util::Cacher do
  before :each do
    CacheTest.set_attr_ttl(:instance_cache, 10)
    @object = CacheTest.new
  end

  it "should return a value calculated from the provided block" do
    @object.instance_cache.should == {:number => CacheTest.count}
  end

  it "should return the cached value from the getter every time if the value is not expired" do
    @object.instance_cache.should equal(@object.instance_cache)
  end

  it "should regenerate and return a new value using the provided block if the value has expired" do
    initial = @object.instance_cache

    # Ensure the value is expired immediately
    CacheTest.set_attr_ttl(:instance_cache, -10)
    @object.send(:set_expiration, :instance_cache)

    @object.instance_cache.should_not equal(initial)
  end

  it "should be able to cache false values" do
    @object.expects(:init_instance_cache).once.returns false
    @object.instance_cache.should be_false
    @object.instance_cache.should be_false
  end

  it "should cache values again after expiration" do
    initial = @object.instance_cache

    # Ensure the value is expired immediately
    CacheTest.set_attr_ttl(:instance_cache, -10)
    @object.send(:set_expiration, :instance_cache)

    # Reset ttl so this new value doesn't get expired
    CacheTest.set_attr_ttl(:instance_cache, 10)
    after_expiration = @object.instance_cache

    after_expiration.should_not == initial
    @object.instance_cache.should == after_expiration
  end

  it "should allow writing of the attribute" do
    initial = @object.instance_cache

    @object.instance_cache = "another value"
    @object.instance_cache.should == "another value"
  end

  it "should update the expiration when the cached attribute is set manually" do
    # Freeze time
    now = Time.now
    Time.stubs(:now).returns now

    @object.instance_cache

    # Set expiration to something far in the future
    CacheTest.set_attr_ttl(:instance_cache, 60)
    @object.send(:set_expiration, :instance_cache)

    CacheTest.set_attr_ttl(:instance_cache, 10)

    @object.instance_cache = "foo"
    @object.instance_variable_get(:@attr_expirations)[:instance_cache].should == now + 10
  end

  it "should allow specification of a ttl as a string" do
    klass = Class.new do
      include Puppet::Util::Cacher
    end

    klass.cached_attr(:myattr, "5")  { 10 }

    klass.attr_ttl(:myattr).should == 5
  end

  it "should fail helpfully if the ttl cannot be converted to an integer" do
    klass = Class.new do
      include Puppet::Util::Cacher
    end

    lambda { klass.cached_attr(:myattr, "yep") { 10 } }.should raise_error(ArgumentError)
  end
end
