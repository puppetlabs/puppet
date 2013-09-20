#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/indirection'

shared_examples_for "Indirection Delegator" do
  it "should create a request object with the appropriate method name and all of the passed arguments" do
    request = Puppet::Indirector::Request.new(:indirection, :find, "me", nil)

    @indirection.expects(:request).with(@method, "mystuff", nil, :one => :two).returns request

    @terminus.stubs(@method)

    @indirection.send(@method, "mystuff", :one => :two)
  end

  it "should let the :select_terminus method choose the terminus using the created request if the :select_terminus method is available" do
    # Define the method, so our respond_to? hook matches.
    class << @indirection
      def select_terminus(request)
      end
    end

    request = Puppet::Indirector::Request.new(:indirection, :find, "me", nil)

    @indirection.stubs(:request).returns request

    @indirection.expects(:select_terminus).with(request).returns :test_terminus

    @indirection.stubs(:check_authorization)
    @terminus.expects(@method)

    @indirection.send(@method, "me")
  end

  it "should fail if the :select_terminus hook does not return a terminus name" do
    # Define the method, so our respond_to? hook matches.
    class << @indirection
      def select_terminus(request)
      end
    end

    request = Puppet::Indirector::Request.new(:indirection, :find, "me", nil)

    @indirection.stubs(:request).returns request

    @indirection.expects(:select_terminus).with(request).returns nil

    lambda { @indirection.send(@method, "me") }.should raise_error(ArgumentError)
  end

  it "should choose the terminus returned by the :terminus_class method if no :select_terminus method is available" do
    @indirection.expects(:terminus_class).returns :test_terminus

    @terminus.expects(@method)

    @indirection.send(@method, "me")
  end

  it "should let the appropriate terminus perform the lookup" do
    @terminus.expects(@method).with { |r| r.is_a?(Puppet::Indirector::Request) }
    @indirection.send(@method, "me")
  end
end

shared_examples_for "Delegation Authorizer" do
  before do
    # So the :respond_to? turns out correctly.
    class << @terminus
      def authorized?
      end
    end
  end

  it "should not check authorization if a node name is not provided" do
    @terminus.expects(:authorized?).never
    @terminus.stubs(@method)

    # The quotes are necessary here, else it looks like a block.
    @request.stubs(:options).returns({})
    @indirection.send(@method, "/my/key")
  end

  it "should pass the request to the terminus's authorization method" do
    @terminus.expects(:authorized?).with { |r| r.is_a?(Puppet::Indirector::Request) }.returns(true)
    @terminus.stubs(@method)

    @indirection.send(@method, "/my/key", :node => "mynode")
  end

  it "should fail if authorization returns false" do
    @terminus.expects(:authorized?).returns(false)
    @terminus.stubs(@method)
    proc { @indirection.send(@method, "/my/key", :node => "mynode") }.should raise_error(ArgumentError)
  end

  it "should continue if authorization returns true" do
    @terminus.expects(:authorized?).returns(true)
    @terminus.stubs(@method)
    @indirection.send(@method, "/my/key", :node => "mynode")
  end
end

shared_examples_for "Request validator" do
  it "asks the terminus to validate the request" do
    @terminus.expects(:validate).raises(Puppet::Indirector::ValidationError, "Invalid")
    @terminus.expects(@method).never
    expect {
      @indirection.send(@method, "key")
    }.to raise_error Puppet::Indirector::ValidationError
  end
end

describe Puppet::Indirector::Indirection do
  describe "when initializing" do
    # (LAK) I've no idea how to test this, really.
    it "should store a reference to itself before it consumes its options" do
      proc { @indirection = Puppet::Indirector::Indirection.new(Object.new, :testingness, :not_valid_option) }.should raise_error
      Puppet::Indirector::Indirection.instance(:testingness).should be_instance_of(Puppet::Indirector::Indirection)
      Puppet::Indirector::Indirection.instance(:testingness).delete
    end

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

    it "should extend itself with any specified module" do
      mod = Module.new
      @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test, :extend => mod)
      @indirection.singleton_class.included_modules.should include(mod)
    end

    after do
      @indirection.delete if defined?(@indirection)
    end
  end

  describe "when an instance" do
    before :each do
      @terminus_class = mock 'terminus_class'
      @terminus = mock 'terminus'
      @terminus.stubs(:validate)
      @terminus_class.stubs(:new).returns(@terminus)
      @cache = stub 'cache', :name => "mycache"
      @cache_class = mock 'cache_class'
      Puppet::Indirector::Terminus.stubs(:terminus_class).with(:test, :cache_terminus).returns(@cache_class)
      Puppet::Indirector::Terminus.stubs(:terminus_class).with(:test, :test_terminus).returns(@terminus_class)

      @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
      @indirection.terminus_class = :test_terminus

      @instance = stub 'instance', :expiration => nil, :expiration= => nil, :name => "whatever"
      @name = :mything

      #@request = stub 'instance', :key => "/my/key", :instance => @instance, :options => {}
      @request = mock 'instance'
    end

    it "should allow setting the ttl" do
      @indirection.ttl = 300
      @indirection.ttl.should == 300
    end

    it "should default to the :runinterval setting, converted to an integer, for its ttl" do
      Puppet[:runinterval] = 1800
      @indirection.ttl.should == 1800
    end

    it "should calculate the current expiration by adding the TTL to the current time" do
      @indirection.stubs(:ttl).returns(100)
      now = Time.now
      Time.stubs(:now).returns now
      @indirection.expiration.should == (Time.now + 100)
    end

    it "should have a method for creating an indirection request instance" do
      @indirection.should respond_to(:request)
    end

    describe "creates a request" do
      it "should create it with its name as the request's indirection name" do
        Puppet::Indirector::Request.expects(:new).with { |name, *other| @indirection.name == name }
        @indirection.request(:funtest, "yayness")
      end

      it "should require a method and key" do
        Puppet::Indirector::Request.expects(:new).with { |name, method, key, *other| method == :funtest and key == "yayness" }
        @indirection.request(:funtest, "yayness")
      end

      it "should support optional arguments" do
        Puppet::Indirector::Request.expects(:new).with { |name, method, key, other| other == {:one => :two} }
        @indirection.request(:funtest, "yayness", :one => :two)
      end

      it "should not pass options if none are supplied" do
        Puppet::Indirector::Request.expects(:new).with { |*args| args.length < 4 }
        @indirection.request(:funtest, "yayness")
      end

      it "should return the request" do
        request = mock 'request'
        Puppet::Indirector::Request.expects(:new).returns request
        @indirection.request(:funtest, "yayness").should equal(request)
      end
    end

    describe "and looking for a model instance" do
      before { @method = :find }

      it_should_behave_like "Indirection Delegator"
      it_should_behave_like "Delegation Authorizer"
      it_should_behave_like "Request validator"

      it "should return the results of the delegation" do
        @terminus.expects(:find).returns(@instance)
        @indirection.find("me").should equal(@instance)
      end

      it "should return false if the instance is false" do
        @terminus.expects(:find).returns(false)
        @indirection.find("me").should equal(false)
      end

      it "should set the expiration date on any instances without one set" do
        @terminus.stubs(:find).returns(@instance)

        @indirection.expects(:expiration).returns :yay

        @instance.expects(:expiration).returns(nil)
        @instance.expects(:expiration=).with(:yay)

        @indirection.find("/my/key")
      end

      it "should not override an already-set expiration date on returned instances" do
        @terminus.stubs(:find).returns(@instance)

        @indirection.expects(:expiration).never

        @instance.expects(:expiration).returns(:yay)
        @instance.expects(:expiration=).never

        @indirection.find("/my/key")
      end

      it "should filter the result instance if the terminus supports it" do
        @terminus.stubs(:find).returns(@instance)
        @terminus.stubs(:respond_to?).with(:filter).returns(true)

        @terminus.expects(:filter).with(@instance)

        @indirection.find("/my/key")
      end
      describe "when caching is enabled" do
        before do
          @indirection.cache_class = :cache_terminus
          @cache_class.stubs(:new).returns(@cache)

          @instance.stubs(:expired?).returns false
        end

        it "should first look in the cache for an instance" do
          @terminus.stubs(:find).never
          @cache.expects(:find).returns @instance

          @indirection.find("/my/key")
        end

        it "should not look in the cache if the request specifies not to use the cache" do
          @terminus.expects(:find).returns @instance
          @cache.expects(:find).never
          @cache.stubs(:save)

          @indirection.find("/my/key", :ignore_cache => true)
        end

        it "should still save to the cache even if the cache is being ignored during readin" do
          @terminus.expects(:find).returns @instance
          @cache.expects(:save)

          @indirection.find("/my/key", :ignore_cache => true)
        end

        it "should only look in the cache if the request specifies not to use the terminus" do
          @terminus.expects(:find).never
          @cache.expects(:find)

          @indirection.find("/my/key", :ignore_terminus => true)
        end

        it "should use a request to look in the cache for cached objects" do
          @cache.expects(:find).with { |r| r.method == :find and r.key == "/my/key" }.returns @instance

          @cache.stubs(:save)

          @indirection.find("/my/key")
        end

        it "should return the cached object if it is not expired" do
          @instance.stubs(:expired?).returns false

          @cache.stubs(:find).returns @instance
          @indirection.find("/my/key").should equal(@instance)
        end

        it "should not fail if the cache fails" do
          @terminus.stubs(:find).returns @instance

          @cache.expects(:find).raises ArgumentError
          @cache.stubs(:save)
          lambda { @indirection.find("/my/key") }.should_not raise_error
        end

        it "should look in the main terminus if the cache fails" do
          @terminus.expects(:find).returns @instance
          @cache.expects(:find).raises ArgumentError
          @cache.stubs(:save)
          @indirection.find("/my/key").should equal(@instance)
        end

        it "should send a debug log if it is using the cached object" do
          Puppet.expects(:debug)
          @cache.stubs(:find).returns @instance

          @indirection.find("/my/key")
        end

        it "should not return the cached object if it is expired" do
          @instance.stubs(:expired?).returns true

          @cache.stubs(:find).returns @instance
          @terminus.stubs(:find).returns nil
          @indirection.find("/my/key").should be_nil
        end

        it "should send an info log if it is using the cached object" do
          Puppet.expects(:info)
          @instance.stubs(:expired?).returns true

          @cache.stubs(:find).returns @instance
          @terminus.stubs(:find).returns nil
          @indirection.find("/my/key")
        end

        it "should cache any objects not retrieved from the cache" do
          @cache.expects(:find).returns nil

          @terminus.expects(:find).returns(@instance)
          @cache.expects(:save)

          @indirection.find("/my/key")
        end

        it "should use a request to look in the cache for cached objects" do
          @cache.expects(:find).with { |r| r.method == :find and r.key == "/my/key" }.returns nil

          @terminus.stubs(:find).returns(@instance)
          @cache.stubs(:save)

          @indirection.find("/my/key")
        end

        it "should cache the instance using a request with the instance set to the cached object" do
          @cache.stubs(:find).returns nil

          @terminus.stubs(:find).returns(@instance)

          @cache.expects(:save).with { |r| r.method == :save and r.instance == @instance }

          @indirection.find("/my/key")
        end

        it "should send an info log that the object is being cached" do
          @cache.stubs(:find).returns nil

          @terminus.stubs(:find).returns(@instance)
          @cache.stubs(:save)

          Puppet.expects(:info)

          @indirection.find("/my/key")
        end
      end
    end

    describe "and doing a head operation" do
      before { @method = :head }

      it_should_behave_like "Indirection Delegator"
      it_should_behave_like "Delegation Authorizer"
      it_should_behave_like "Request validator"

      it "should return true if the head method returned true" do
        @terminus.expects(:head).returns(true)
        @indirection.head("me").should == true
      end

      it "should return false if the head method returned false" do
        @terminus.expects(:head).returns(false)
        @indirection.head("me").should == false
      end

      describe "when caching is enabled" do
        before do
          @indirection.cache_class = :cache_terminus
          @cache_class.stubs(:new).returns(@cache)

          @instance.stubs(:expired?).returns false
        end

        it "should first look in the cache for an instance" do
          @terminus.stubs(:find).never
          @terminus.stubs(:head).never
          @cache.expects(:find).returns @instance

          @indirection.head("/my/key").should == true
        end

        it "should not save to the cache" do
          @cache.expects(:find).returns nil
          @cache.expects(:save).never
          @terminus.expects(:head).returns true
          @indirection.head("/my/key").should == true
        end

        it "should not fail if the cache fails" do
          @terminus.stubs(:head).returns true

          @cache.expects(:find).raises ArgumentError
          lambda { @indirection.head("/my/key") }.should_not raise_error
        end

        it "should look in the main terminus if the cache fails" do
          @terminus.expects(:head).returns true
          @cache.expects(:find).raises ArgumentError
          @indirection.head("/my/key").should == true
        end

        it "should send a debug log if it is using the cached object" do
          Puppet.expects(:debug)
          @cache.stubs(:find).returns @instance

          @indirection.head("/my/key")
        end

        it "should not accept the cached object if it is expired" do
          @instance.stubs(:expired?).returns true

          @cache.stubs(:find).returns @instance
          @terminus.stubs(:head).returns false
          @indirection.head("/my/key").should == false
        end
      end
    end

    describe "and storing a model instance" do
      before { @method = :save }

      it "should return the result of the save" do
        @terminus.stubs(:save).returns "foo"
        @indirection.save(@instance).should == "foo"
      end

      describe "when caching is enabled" do
        before do
          @indirection.cache_class = :cache_terminus
          @cache_class.stubs(:new).returns(@cache)

          @instance.stubs(:expired?).returns false
        end

        it "should return the result of saving to the terminus" do
          request = stub 'request', :instance => @instance, :node => nil

          @indirection.expects(:request).returns request

          @cache.stubs(:save)
          @terminus.stubs(:save).returns @instance
          @indirection.save(@instance).should equal(@instance)
        end

        it "should use a request to save the object to the cache" do
          request = stub 'request', :instance => @instance, :node => nil

          @indirection.expects(:request).returns request

          @cache.expects(:save).with(request)
          @terminus.stubs(:save)
          @indirection.save(@instance)
        end

        it "should not save to the cache if the normal save fails" do
          request = stub 'request', :instance => @instance, :node => nil

          @indirection.expects(:request).returns request

          @cache.expects(:save).never
          @terminus.expects(:save).raises "eh"
          lambda { @indirection.save(@instance) }.should raise_error
        end
      end
    end

    describe "and removing a model instance" do
      before { @method = :destroy }

      it_should_behave_like "Indirection Delegator"
      it_should_behave_like "Delegation Authorizer"
      it_should_behave_like "Request validator"

      it "should return the result of removing the instance" do
        @terminus.stubs(:destroy).returns "yayness"
        @indirection.destroy("/my/key").should == "yayness"
      end

      describe "when caching is enabled" do
        before do
          @indirection.cache_class = :cache_terminus
          @cache_class.expects(:new).returns(@cache)

          @instance.stubs(:expired?).returns false
        end

        it "should use a request instance to search in and remove objects from the cache" do
          destroy = stub 'destroy_request', :key => "/my/key", :node => nil
          find = stub 'destroy_request', :key => "/my/key", :node => nil

          @indirection.expects(:request).with(:destroy, "/my/key", nil, optionally(instance_of(Hash))).returns destroy
          @indirection.expects(:request).with(:find, "/my/key", nil, optionally(instance_of(Hash))).returns find

          cached = mock 'cache'

          @cache.expects(:find).with(find).returns cached
          @cache.expects(:destroy).with(destroy)

          @terminus.stubs(:destroy)

          @indirection.destroy("/my/key")
        end
      end
    end

    describe "and searching for multiple model instances" do
      before { @method = :search }

      it_should_behave_like "Indirection Delegator"
      it_should_behave_like "Delegation Authorizer"
      it_should_behave_like "Request validator"

      it "should set the expiration date on any instances without one set" do
        @terminus.stubs(:search).returns([@instance])

        @indirection.expects(:expiration).returns :yay

        @instance.expects(:expiration).returns(nil)
        @instance.expects(:expiration=).with(:yay)

        @indirection.search("/my/key")
      end

      it "should not override an already-set expiration date on returned instances" do
        @terminus.stubs(:search).returns([@instance])

        @indirection.expects(:expiration).never

        @instance.expects(:expiration).returns(:yay)
        @instance.expects(:expiration=).never

        @indirection.search("/my/key")
      end

      it "should return the results of searching in the terminus" do
        @terminus.expects(:search).returns([@instance])
        @indirection.search("/my/key").should == [@instance]
      end
    end

    describe "and expiring a model instance" do
      describe "when caching is not enabled" do
        it "should do nothing" do
          @cache_class.expects(:new).never

          @indirection.expire("/my/key")
        end
      end

      describe "when caching is enabled" do
        before do
          @indirection.cache_class = :cache_terminus
          @cache_class.expects(:new).returns(@cache)

          @instance.stubs(:expired?).returns false

          @cached = stub 'cached', :expiration= => nil, :name => "/my/key"
        end

        it "should use a request to find within the cache" do
          @cache.expects(:find).with { |r| r.is_a?(Puppet::Indirector::Request) and r.method == :find }
          @indirection.expire("/my/key")
        end

        it "should do nothing if no such instance is cached" do
          @cache.expects(:find).returns nil

          @indirection.expire("/my/key")
        end

        it "should log when expiring a found instance" do
          @cache.expects(:find).returns @cached
          @cache.stubs(:save)

          Puppet.expects(:info)

          @indirection.expire("/my/key")
        end

        it "should set the cached instance's expiration to a time in the past" do
          @cache.expects(:find).returns @cached
          @cache.stubs(:save)

          @cached.expects(:expiration=).with { |t| t < Time.now }

          @indirection.expire("/my/key")
        end

        it "should save the now expired instance back into the cache" do
          @cache.expects(:find).returns @cached

          @cached.expects(:expiration=).with { |t| t < Time.now }

          @cache.expects(:save)

          @indirection.expire("/my/key")
        end

        it "should use a request to save the expired resource to the cache" do
          @cache.expects(:find).returns @cached

          @cached.expects(:expiration=).with { |t| t < Time.now }

          @cache.expects(:save).with { |r| r.is_a?(Puppet::Indirector::Request) and r.instance == @cached and r.method == :save }.returns(@cached)

          @indirection.expire("/my/key")
        end
      end
    end

    after :each do
      @indirection.delete
    end
  end


  describe "when managing indirection instances" do
    it "should allow an indirection to be retrieved by name" do
      @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
      Puppet::Indirector::Indirection.instance(:test).should equal(@indirection)
    end

    it "should return nil when the named indirection has not been created" do
      Puppet::Indirector::Indirection.instance(:test).should be_nil
    end

    it "should allow an indirection's model to be retrieved by name" do
      mock_model = mock('model')
      @indirection = Puppet::Indirector::Indirection.new(mock_model, :test)
      Puppet::Indirector::Indirection.model(:test).should equal(mock_model)
    end

    it "should return nil when no model matches the requested name" do
      Puppet::Indirector::Indirection.model(:test).should be_nil
    end

    after do
      @indirection.delete if defined?(@indirection)
    end
  end

  describe "when routing to the correct the terminus class" do
    before do
      @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
      @terminus = mock 'terminus'
      @terminus_class = stub 'terminus class', :new => @terminus
      Puppet::Indirector::Terminus.stubs(:terminus_class).with(:test, :default).returns(@terminus_class)
    end

    it "should fail if no terminus class can be picked" do
      proc { @indirection.terminus_class }.should raise_error(Puppet::DevError)
    end

    it "should choose the default terminus class if one is specified" do
      @indirection.terminus_class = :default
      @indirection.terminus_class.should equal(:default)
    end

    it "should use the provided Puppet setting if told to do so" do
      Puppet::Indirector::Terminus.stubs(:terminus_class).with(:test, :my_terminus).returns(mock("terminus_class2"))
      Puppet[:node_terminus] = :my_terminus
      @indirection.terminus_setting = :node_terminus
      @indirection.terminus_class.should equal(:my_terminus)
    end

    it "should fail if the provided terminus class is not valid" do
      Puppet::Indirector::Terminus.stubs(:terminus_class).with(:test, :nosuchclass).returns(nil)
      proc { @indirection.terminus_class = :nosuchclass }.should raise_error(ArgumentError)
    end

    after do
      @indirection.delete if defined?(@indirection)
    end
  end

  describe "when specifying the terminus class to use" do
    before do
      @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
      @terminus = mock 'terminus'
      @terminus.stubs(:validate)
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
      Puppet::Indirector::Terminus.expects(:terminus_class).with(:test, :foo).returns(nil)
      proc { @indirection.terminus_class = :foo }.should raise_error(ArgumentError)
    end

    it "should select the specified terminus class if a terminus class name is provided" do
      Puppet::Indirector::Terminus.expects(:terminus_class).with(:test, :foo).returns(@terminus_class)
      @indirection.terminus(:foo).should equal(@terminus)
    end

    it "should use the configured terminus class if no terminus name is specified" do
      Puppet::Indirector::Terminus.stubs(:terminus_class).with(:test, :foo).returns(@terminus_class)
      @indirection.terminus_class = :foo
      @indirection.terminus.should equal(@terminus)
    end

    after do
      @indirection.delete if defined?(@indirection)
    end
  end

  describe "when managing terminus instances" do
    before do
      @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
      @terminus = mock 'terminus'
      @terminus_class = mock 'terminus class'
      Puppet::Indirector::Terminus.stubs(:terminus_class).with(:test, :foo).returns(@terminus_class)
    end

    it "should create an instance of the chosen terminus class" do
      @terminus_class.stubs(:new).returns(@terminus)
      @indirection.terminus(:foo).should equal(@terminus)
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
    end
  end

  describe "when deciding whether to cache" do
    before do
      @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
      @terminus = mock 'terminus'
      @terminus_class = mock 'terminus class'
      @terminus_class.stubs(:new).returns(@terminus)
      Puppet::Indirector::Terminus.stubs(:terminus_class).with(:test, :foo).returns(@terminus_class)
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

    it "should allow resetting the cache_class to nil" do
      @indirection.cache_class = nil
      @indirection.cache_class.should be_nil
    end

    it "should fail to set the cache class when the specified cache class cannot be found" do
      Puppet::Indirector::Terminus.expects(:terminus_class).with(:test, :foo).returns(nil)
      proc { @indirection.cache_class = :foo }.should raise_error(ArgumentError)
    end

    after do
      @indirection.delete
    end
  end

  describe "when using a cache" do
    before :each do
      @terminus_class = mock 'terminus_class'
      @terminus = mock 'terminus'
      @terminus_class.stubs(:new).returns(@terminus)
      @cache = mock 'cache'
      @cache_class = mock 'cache_class'
      Puppet::Indirector::Terminus.stubs(:terminus_class).with(:test, :cache_terminus).returns(@cache_class)
      Puppet::Indirector::Terminus.stubs(:terminus_class).with(:test, :test_terminus).returns(@terminus_class)
      @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
      @indirection.terminus_class = :test_terminus
    end

    describe "and managing the cache terminus" do
      it "should not create a cache terminus at initialization" do
        # This is weird, because all of the code is in the setup.  If we got
        # new called on the cache class, we'd get an exception here.
      end

      it "should reuse the cache terminus" do
        @cache_class.expects(:new).returns(@cache)
        @indirection.cache_class = :cache_terminus
        @indirection.cache.should equal(@cache)
        @indirection.cache.should equal(@cache)
      end
    end

    describe "and saving" do
    end

    describe "and finding" do
    end

    after :each do
      @indirection.delete
    end
  end
end
