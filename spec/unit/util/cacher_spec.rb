#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/cacher'

class ExpirerTest
  include Puppet::Util::Cacher::Expirer
end

class CacheTest
  @@init_count = 0

  include Puppet::Util::Cacher
  cached_attr(:instance_cache) { Time.now }
end

describe Puppet::Util::Cacher::Expirer do
  before do
    @expirer = ExpirerTest.new
  end

  it "should be able to test whether a timestamp is expired" do
    @expirer.should respond_to(:dependent_data_expired?)
  end

  it "should be able to expire all values" do
    @expirer.should respond_to(:expire)
  end

  it "should consider any value to be valid if it has never been expired" do
    @expirer.should_not be_dependent_data_expired(Time.now)
  end

  it "should consider any value created after expiration to be expired" do
    @expirer.expire
    @expirer.should be_dependent_data_expired(Time.now - 1)
  end
end

describe Puppet::Util::Cacher do
  it "should be extended with the Expirer module" do
    Puppet::Util::Cacher.singleton_class.ancestors.should be_include(Puppet::Util::Cacher::Expirer)
  end

  it "should support defining cached attributes", :'fails_on_ruby_1.9.2' => true do
    CacheTest.methods.should be_include("cached_attr")
  end

  it "should default to the Cacher module as its expirer" do
    CacheTest.new.expirer.should equal(Puppet::Util::Cacher)
  end

  describe "when using cached attributes" do
    before do
      @expirer = ExpirerTest.new
      @object = CacheTest.new

      @object.stubs(:expirer).returns @expirer
    end

    it "should create a getter for the cached attribute" do
      @object.should respond_to(:instance_cache)
    end

    it "should return a value calculated from the provided block" do
      time = Time.now
      Time.stubs(:now).returns time
      @object.instance_cache.should equal(time)
    end

    it "should return the cached value from the getter every time if the value is not expired" do
      @object.instance_cache.should equal(@object.instance_cache)
    end

    it "should regenerate and return a new value using the provided block if the value has been expired" do
      value = @object.instance_cache
      @expirer.expire
      @object.instance_cache.should_not equal(value)
    end

    it "should be able to trigger expiration on its expirer" do
      @expirer.expects(:expire)
      @object.expire
    end

    it "should do nothing when asked to expire when no expirer is available" do
      cacher = CacheTest.new
      class << cacher
        def expirer
          nil
        end
      end
      lambda { cacher.expire }.should_not raise_error
    end

    it "should be able to cache false values" do
      @object.expects(:init_instance_cache).returns false
      @object.instance_cache.should be_false
      @object.instance_cache.should be_false
    end

    it "should cache values again after expiration" do
      @object.instance_cache
      @expirer.expire
      @object.instance_cache.should equal(@object.instance_cache)
    end

    it "should always consider a value expired if it has no expirer" do
      @object.stubs(:expirer).returns nil
      @object.instance_cache.should_not equal(@object.instance_cache)
    end

    it "should allow writing of the attribute" do
      @object.should respond_to(:instance_cache=)
    end

    it "should correctly configure timestamps for expiration when the cached attribute is written to" do
      @object.instance_cache = "foo"
      @expirer.expire
      @object.instance_cache.should_not == "foo"
    end

    it "should allow specification of a ttl for cached attributes" do
      klass = Class.new do
        include Puppet::Util::Cacher
      end

      klass.cached_attr(:myattr, :ttl => 5)  { Time.now }

      klass.attr_ttl(:myattr).should == 5
    end

    it "should allow specification of a ttl as a string" do
      klass = Class.new do
        include Puppet::Util::Cacher
      end

      klass.cached_attr(:myattr, :ttl => "5")  { Time.now }

      klass.attr_ttl(:myattr).should == 5
    end

    it "should fail helpfully if the ttl cannot be converted to an integer" do
      klass = Class.new do
        include Puppet::Util::Cacher
      end

      lambda { klass.cached_attr(:myattr, :ttl => "yep")  { Time.now } }.should raise_error(ArgumentError)
    end

    it "should not check for a ttl expiration if the class does not support that method" do
      klass = Class.new do
        extend Puppet::Util::Cacher
      end

      klass.singleton_class.cached_attr(:myattr) { "eh" }
      klass.myattr
    end

    it "should automatically expire cached attributes whose ttl has expired, even if no expirer is present" do
      klass = Class.new do
        def self.to_s
          "CacheTestClass"
        end
        include Puppet::Util::Cacher
        attr_accessor :value
      end

      klass.cached_attr(:myattr, :ttl => 5)  { self.value += 1; self.value }

      now = Time.now
      later = Time.now + 15

      instance = klass.new
      instance.value = 0
      instance.myattr.should == 1

      Time.expects(:now).returns later

      # This call should get the new Time value, which should expire the old value
      instance.myattr.should == 2
    end
  end
end
