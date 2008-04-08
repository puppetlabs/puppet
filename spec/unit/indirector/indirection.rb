#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector/indirection'

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
            @indirection.metaclass.included_modules.should include(mod)
        end

        after do
            @indirection.delete if defined? @indirection
        end
    end

    describe "when an instance" do
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

            @instance = stub 'instance', :expiration => nil, :expiration= => nil, :name => "whatever"
            @name = :mything
        end

        it "should allow setting the ttl" do
            @indirection.ttl = 300
            @indirection.ttl.should == 300
        end

        it "should default to the :runinterval setting, converted to an integer, for its ttl" do
            Puppet.settings.expects(:value).returns "1800"
            @indirection.ttl.should == 1800
        end

        it "should calculate the current expiration by adding the TTL to the current time" do
            @indirection.stubs(:ttl).returns(100)
            now = Time.now
            Time.stubs(:now).returns now
            @indirection.expiration.should == (Time.now + 100)
        end
      
        describe "and looking for a model instance" do
            it "should create a request with the indirection name, the sought-after name, the :find method, and any passed arguments" do
                request = mock 'request'
                Puppet::Indirector::Request.expects(:new).with(@indirection.name, @name, :find, {:one => :two}).returns request

                @indirection.stubs(:check_authorization)
                @terminus.stubs(:find)

                @indirection.find(@name, :one => :two)
            end

            it "should let the :select_terminus method choose the terminus if the method is defined" do
                request = mock 'request'
                Puppet::Indirector::Request.expects(:new).returns request

                # Define the method, so our respond_to? hook matches.
                class << @indirection
                    def select_terminus(request)
                    end
                end

                @indirection.expects(:select_terminus).with(request).returns :test_terminus

                @indirection.stubs(:check_authorization)
                @terminus.expects(:find)

                @indirection.find(@name)

            end

            it "should let the appropriate terminus perform the lookup" do
                @terminus.expects(:find).with(@name).returns(@instance)
                @indirection.find(@name).should == @instance
            end

            it "should return nil if nothing is returned by the terminus" do
                @terminus.expects(:find).with(@name).returns(nil)
                @indirection.find(@name).should be_nil
            end

            it "should extend any found instance with the Envelope module" do
                @terminus.stubs(:find).returns(@instance)

                @instance.expects(:extend).with(Puppet::Indirector::Envelope)
                @indirection.find(@name)
            end

            it "should set the expiration date on any instances without one set" do
                # Otherwise, our stub method doesn't get used, so the tests fail.
                @instance.stubs(:extend)
                @terminus.stubs(:find).returns(@instance)

                @indirection.expects(:expiration).returns :yay

                @instance.expects(:expiration).returns(nil)
                @instance.expects(:expiration=).with(:yay)

                @indirection.find(@name)
            end

            it "should not override an already-set expiration date on returned instances" do
                # Otherwise, our stub method doesn't get used, so the tests fail.
                @instance.stubs(:extend)
                @terminus.stubs(:find).returns(@instance)

                @indirection.expects(:expiration).never

                @instance.expects(:expiration).returns(:yay)
                @instance.expects(:expiration=).never

                @indirection.find(@name)
            end

            describe "when caching is enabled" do
                before do
                    @indirection.cache_class = :cache_terminus
                    @cache_class.expects(:new).returns(@cache)

                    @instance.stubs(:expired?).returns false
                end

                it "should first look in the cache for an instance" do
                    @terminus.expects(:find).never
                    @cache.expects(:find).with(@name).returns @instance

                    @indirection.find(@name)
                end

                it "should return the cached object if it is not expired" do
                    @instance.stubs(:expired?).returns false

                    @cache.stubs(:find).returns @instance
                    @indirection.find(@name).should equal(@instance)
                end

                it "should send a debug log if it is using the cached object" do
                    Puppet.expects(:debug)
                    @cache.stubs(:find).returns @instance

                    @indirection.find(@name)
                end

                it "should not return the cached object if it is expired" do
                    @instance.stubs(:expired?).returns true

                    @cache.stubs(:find).returns @instance
                    @terminus.stubs(:find).returns nil
                    @indirection.find(@name).should be_nil
                end

                it "should send an info log if it is using the cached object" do
                    Puppet.expects(:info)
                    @instance.stubs(:expired?).returns true

                    @cache.stubs(:find).returns @instance
                    @terminus.stubs(:find).returns nil
                    @indirection.find(@name)
                end

                it "should cache any objects not retrieved from the cache" do
                    @cache.expects(:find).with(@name).returns nil

                    @terminus.expects(:find).with(@name).returns(@instance)
                    @cache.expects(:save).with(@instance)

                    @indirection.find(@name)
                end

                it "should send an info log that the object is being cached" do
                    @cache.stubs(:find).returns nil

                    @terminus.stubs(:find).returns(@instance)
                    @cache.stubs(:save)

                    Puppet.expects(:info)

                    @indirection.find(@name)
                end
            end
        end

        describe "and storing a model instance" do
            it "should create a request with the indirection name, the instance's name, the :save method, and any passed arguments" do
                request = mock 'request'
                Puppet::Indirector::Request.expects(:new).with(@indirection.name, @instance.name, :save, {:one => :two}).returns request

                @indirection.stubs(:check_authorization)
                @terminus.stubs(:save)

                @indirection.save(@instance, :one => :two)
            end

            it "should let the :select_terminus method choose the terminus if the method is defined" do
                request = mock 'request'
                Puppet::Indirector::Request.expects(:new).returns request

                # Define the method, so our respond_to? hook matches.
                class << @indirection
                    def select_terminus(request)
                    end
                end

                @indirection.expects(:select_terminus).with(request).returns :test_terminus

                @indirection.stubs(:check_authorization)
                @terminus.expects(:save)

                @indirection.save(@instance)
            end

            it "should let the appropriate terminus store the instance" do
                @terminus.expects(:save).with(@instance).returns(@instance)
                @indirection.save(@instance).should == @instance
            end

            describe "when caching is enabled" do
                before do
                    @indirection.cache_class = :cache_terminus
                    @cache_class.expects(:new).returns(@cache)

                    @instance.stubs(:expired?).returns false
                end

                it "should save the object to the cache" do
                    @cache.expects(:save).with(@instance)
                    @terminus.stubs(:save)
                    @indirection.save(@instance)
                end
            end
        end
        
        describe "and removing a model instance" do
            it "should create a request with the indirection name, the name of the instance being destroyed, the :destroy method, and any passed arguments" do
                request = mock 'request'
                Puppet::Indirector::Request.expects(:new).with(@indirection.name, "me", :destroy, {:one => :two}).returns request

                @indirection.stubs(:check_authorization)
                @terminus.stubs(:destroy)

                @indirection.destroy("me", :one => :two)
            end

            it "should let the :select_terminus method choose the terminus if the method is defined" do
                request = mock 'request'
                Puppet::Indirector::Request.expects(:new).returns request

                # Define the method, so our respond_to? hook matches.
                class << @indirection
                    def select_terminus(request)
                    end
                end

                @indirection.expects(:select_terminus).with(request).returns :test_terminus

                @indirection.stubs(:check_authorization)
                @terminus.expects(:destroy)

                @indirection.destroy(@name)
            end

            it "should delegate the instance removal to the appropriate terminus" do
                @terminus.expects(:destroy).with(@name)
                @indirection.destroy(@name)
            end

            it "should return nil" do
                @terminus.stubs(:destroy)
                @indirection.destroy(@name).should be_nil
            end

            describe "when caching is enabled" do
                before do
                    @indirection.cache_class = :cache_terminus
                    @cache_class.expects(:new).returns(@cache)

                    @instance.stubs(:expired?).returns false
                end

                it "should destroy any found object in the cache" do
                    cached = mock 'cache'
                    @cache.expects(:find).with(@name).returns cached
                    @cache.expects(:destroy).with(@name)
                    @terminus.stubs(:destroy)

                    @indirection.destroy(@name)
                end
            end
        end

        describe "and searching for multiple model instances" do
            it "should create a request with the indirection name, the search key, the :search method, and any passed arguments" do
                request = mock 'request'
                Puppet::Indirector::Request.expects(:new).with(@indirection.name, "me", :search, {:one => :two}).returns request

                @indirection.stubs(:check_authorization)
                @terminus.stubs(:search)

                @indirection.search("me", :one => :two)
            end

            it "should let the :select_terminus method choose the terminus if the method is defined" do
                request = mock 'request'
                Puppet::Indirector::Request.expects(:new).returns request

                # Define the method, so our respond_to? hook matches.
                class << @indirection
                    def select_terminus(request)
                    end
                end

                @indirection.expects(:select_terminus).with(request).returns :test_terminus

                @indirection.stubs(:check_authorization)
                @terminus.expects(:search)

                @indirection.search("me")
            end

            it "should let the appropriate terminus find the matching instances" do
                @terminus.expects(:search).with(@name).returns(@instance)
                @indirection.search(@name).should == @instance
            end
        end

        describe "and an authorization hook is present" do
            before do
                # So the :respond_to? turns out correctly.
                class << @terminus
                    def authorized?
                    end
                end
            end

            it "should not check authorization if a node name is not provided" do
                @terminus.expects(:authorized?).never
                @terminus.stubs(:find)
                @indirection.find("/my/key")
            end

            it "should pass the request to the terminus's authorization method" do
                request = stub 'request', :options => {:node => "yayhost"}
                Puppet::Indirector::Request.expects(:new).returns(request)
                @terminus.expects(:authorized?).with(request).returns(true)
                @terminus.stubs(:find)

                @indirection.find("/my/key", :node => "mynode")
            end

            it "should fail while finding instances if authorization returns false" do
                @terminus.expects(:authorized?).returns(false)
                @terminus.stubs(:find)
                proc { @indirection.find("/my/key", :node => "mynode") }.should raise_error(ArgumentError)
            end

            it "should continue finding instances if authorization returns true" do
                @terminus.expects(:authorized?).returns(true)
                @terminus.stubs(:find)
                @indirection.find("/my/key", :node => "mynode")
            end

            it "should fail while saving instances if authorization returns false" do
                @terminus.expects(:authorized?).returns(false)
                @terminus.stubs(:save)
                proc { @indirection.save(@instance, :node => "mynode") }.should raise_error(ArgumentError)
            end

            it "should continue saving instances if authorization returns true" do
                @terminus.expects(:authorized?).returns(true)
                @terminus.stubs(:save)
                @indirection.save(@instance, :node => "mynode")
            end

            it "should fail while destroying instances if authorization returns false" do
                @terminus.expects(:authorized?).returns(false)
                @terminus.stubs(:destroy)
                proc { @indirection.destroy("/my/key", :node => "mynode") }.should raise_error(ArgumentError)
            end

            it "should continue destroying instances if authorization returns true" do
                @terminus.expects(:authorized?).returns(true)
                @terminus.stubs(:destroy)
                @indirection.destroy(@instance, :node => "mynode")
            end

            it "should fail while searching for instances if authorization returns false" do
                @terminus.expects(:authorized?).returns(false)
                @terminus.stubs(:search)
                proc { @indirection.search("/my/key", :node => "mynode") }.should raise_error(ArgumentError)
            end

            it "should continue searching for instances if authorization returns true" do
                @terminus.expects(:authorized?).returns(true)
                @terminus.stubs(:search)
                @indirection.search("/my/key", :node => "mynode")
            end
        end

        after :each do
            @indirection.delete
            Puppet::Indirector::Indirection.clear_cache
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
            @indirection.delete if defined? @indirection
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
            Puppet.settings.expects(:value).with(:my_setting).returns("my_terminus")
            @indirection.terminus_setting = :my_setting
            @indirection.terminus_class.should equal(:my_terminus)
        end

        it "should fail if the provided terminus class is not valid" do
            Puppet::Indirector::Terminus.stubs(:terminus_class).with(:test, :nosuchclass).returns(nil)
            proc { @indirection.terminus_class = :nosuchclass }.should raise_error(ArgumentError)
        end

        after do
            @indirection.delete if defined? @indirection
        end
    end

    describe "when specifying the terminus class to use" do
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
            @indirection.terminus().should equal(@terminus)
        end

        after do
            @indirection.delete if defined? @indirection
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

        it "should fail to set the cache class when the cache class name is nil" do
            proc { @indirection.cache_class = nil }.should raise_error(ArgumentError)
        end

        it "should fail to set the cache class when the specified cache class cannot be found" do
            Puppet::Indirector::Terminus.expects(:terminus_class).with(:test, :foo).returns(nil)
            proc { @indirection.cache_class = :foo }.should raise_error(ArgumentError)
        end

        after do
            @indirection.delete
            Puppet::Indirector::Indirection.clear_cache
        end
    end

    describe "when using a cache" do
        before :each do
            Puppet.settings.stubs(:value).with("test_terminus").returns("test_terminus")
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

        describe "and saving" do
        end
        
        describe "and finding" do
        end
        
        after :each do
            @indirection.delete
            Puppet::Indirector::Indirection.clear_cache
        end
    end
end
