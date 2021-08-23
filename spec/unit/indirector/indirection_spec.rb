require 'spec_helper'

require 'puppet/indirector/indirection'

shared_examples_for "Indirection Delegator" do
  it "should create a request object with the appropriate method name and all of the passed arguments" do
    request = Puppet::Indirector::Request.new(:indirection, :find, "me", nil)

    expect(@indirection).to receive(:request).with(@method, "mystuff", nil, :one => :two).and_return(request)

    allow(@terminus).to receive(@method)

    @indirection.send(@method, "mystuff", :one => :two)
  end

  it "should choose the terminus returned by the :terminus_class" do
    expect(@indirection).to receive(:terminus_class).and_return(:test_terminus)

    expect(@terminus).to receive(@method)

    @indirection.send(@method, "me")
  end

  it "should let the appropriate terminus perform the lookup" do
    expect(@terminus).to receive(@method).with(be_a(Puppet::Indirector::Request))
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
    expect(@terminus).not_to receive(:authorized?)
    allow(@terminus).to receive(@method)

    # The parenthesis are necessary here, else it looks like a block.
    allow(@request).to receive(:options).and_return({})
    @indirection.send(@method, "/my/key")
  end

  it "should pass the request to the terminus's authorization method" do
    expect(@terminus).to receive(:authorized?).with(be_a(Puppet::Indirector::Request)).and_return(true)
    allow(@terminus).to receive(@method)

    @indirection.send(@method, "/my/key", :node => "mynode")
  end

  it "should fail if authorization returns false" do
    expect(@terminus).to receive(:authorized?).and_return(false)
    allow(@terminus).to receive(@method)
    expect { @indirection.send(@method, "/my/key", :node => "mynode") }.to raise_error(ArgumentError)
  end

  it "should continue if authorization returns true" do
    expect(@terminus).to receive(:authorized?).and_return(true)
    allow(@terminus).to receive(@method)
    @indirection.send(@method, "/my/key", :node => "mynode")
  end
end

shared_examples_for "Request validator" do
  it "asks the terminus to validate the request" do
    expect(@terminus).to receive(:validate).and_raise(Puppet::Indirector::ValidationError, "Invalid")
    expect(@terminus).not_to receive(@method)
    expect {
      @indirection.send(@method, "key")
    }.to raise_error Puppet::Indirector::ValidationError
  end
end

describe Puppet::Indirector::Indirection do
  describe "when initializing" do
    it "should keep a reference to the indirecting model" do
      model = double('model')
      @indirection = Puppet::Indirector::Indirection.new(model, :myind)
      expect(@indirection.model).to equal(model)
    end

    it "should set the name" do
      @indirection = Puppet::Indirector::Indirection.new(double('model'), :myind)
      expect(@indirection.name).to eq(:myind)
    end

    it "should require indirections to have unique names" do
      @indirection = Puppet::Indirector::Indirection.new(double('model'), :test)
      expect { Puppet::Indirector::Indirection.new(:test) }.to raise_error(ArgumentError)
    end

    it "should extend itself with any specified module" do
      mod = Module.new
      @indirection = Puppet::Indirector::Indirection.new(double('model'), :test, :extend => mod)
      expect(@indirection.singleton_class.included_modules).to include(mod)
    end

    after do
      @indirection.delete if defined?(@indirection)
    end
  end

  describe "when an instance" do
    before :each do
      @terminus_class = double('terminus_class')
      @terminus = double('terminus')
      allow(@terminus).to receive(:validate)
      allow(@terminus_class).to receive(:new).and_return(@terminus)
      @cache = double('cache', :name => "mycache")
      @cache_class = double('cache_class')
      allow(Puppet::Indirector::Terminus).to receive(:terminus_class).with(:test, :cache_terminus).and_return(@cache_class)
      allow(Puppet::Indirector::Terminus).to receive(:terminus_class).with(:test, :test_terminus).and_return(@terminus_class)

      @indirection = Puppet::Indirector::Indirection.new(double('model'), :test)
      @indirection.terminus_class = :test_terminus

      @instance = double('instance', :expiration => nil, :expiration= => nil, :name => "whatever")
      @name = :mything

      @request = double('instance')
    end

    describe 'ensure that indirection settings are threadsafe' do
      before :each do
        @alt_term = double('alternate_terminus')
        expect(Puppet::Indirector::Terminus).to receive(:terminus_class).with(:test, :alternate_terminus).and_return(@alt_term)
        @alt_cache= double('alternate_cache')
        expect(Puppet::Indirector::Terminus).to receive(:terminus_class).with(:test, :alternate_cache).and_return(@alt_cache)
      end

      it 'does not change the original value when modified in new thread' do
        Thread.new do
          @indirection.terminus_class = :alternate_terminus
          @indirection.terminus_setting = :alternate_terminus_setting
          @indirection.cache_class = :alternate_cache
        end.join
        expect(@indirection.terminus_class).to eq(:test_terminus)
        expect(@indirection.terminus_setting).to eq(nil)
        expect(@indirection.cache_class).to eq(nil)
      end

      it 'can modify indirection settings globally for all threads using the global setter' do
        Thread.new do
          @indirection.set_global_setting(:terminus_class, :alternate_terminus)
          @indirection.set_global_setting(:terminus_setting, :alternate_terminus_setting)
          @indirection.set_global_setting(:cache_class, :alternate_cache)
        end.join
        expect(@indirection.terminus_class).to eq(:alternate_terminus)
        expect(@indirection.terminus_setting).to eq(:alternate_terminus_setting)
        expect(@indirection.cache_class).to eq(:alternate_cache)
      end
    end

    it "should allow setting the ttl" do
      @indirection.ttl = 300
      expect(@indirection.ttl).to eq(300)
    end

    it "should default to the :runinterval setting, converted to an integer, for its ttl" do
      Puppet[:runinterval] = 1800
      expect(@indirection.ttl).to eq(1800)
    end

    it "should calculate the current expiration by adding the TTL to the current time" do
      allow(@indirection).to receive(:ttl).and_return(100)
      now = Time.now
      allow(Time).to receive(:now).and_return(now)
      expect(@indirection.expiration).to eq(Time.now + 100)
    end

    it "should have a method for creating an indirection request instance" do
      expect(@indirection).to respond_to(:request)
    end

    describe "creates a request" do
      it "should create it with its name as the request's indirection name" do
        expect(@indirection.request(:funtest, "yayness", nil).indirection_name).to eq(@indirection.name)
      end

      it "should require a method and key" do
        request = @indirection.request(:funtest, "yayness", nil)
        expect(request.method).to eq(:funtest)
        expect(request.key).to eq("yayness")
      end

      it "should support optional arguments" do
        expect(@indirection.request(:funtest, "yayness", nil, :one => :two).options).to eq(:one => :two)
      end

      it "should not pass options if none are supplied" do
        expect(@indirection.request(:funtest, "yayness", nil).options).to eq({})
      end

      it "should return the request" do
        expect(@indirection.request(:funtest, "yayness", nil)).to be_a(Puppet::Indirector::Request)
      end
    end

    describe "and looking for a model instance" do
      before { @method = :find }

      it_should_behave_like "Indirection Delegator"
      it_should_behave_like "Delegation Authorizer"
      it_should_behave_like "Request validator"

      it "should return the results of the delegation" do
        expect(@terminus).to receive(:find).and_return(@instance)
        expect(@indirection.find("me")).to equal(@instance)
      end

      it "should return false if the instance is false" do
        expect(@terminus).to receive(:find).and_return(false)
        expect(@indirection.find("me")).to equal(false)
      end

      it "should set the expiration date on any instances without one set" do
        allow(@terminus).to receive(:find).and_return(@instance)

        expect(@indirection).to receive(:expiration).and_return(:yay)

        expect(@instance).to receive(:expiration).and_return(nil)
        expect(@instance).to receive(:expiration=).with(:yay)

        @indirection.find("/my/key")
      end

      it "should not override an already-set expiration date on returned instances" do
        allow(@terminus).to receive(:find).and_return(@instance)

        expect(@indirection).not_to receive(:expiration)

        expect(@instance).to receive(:expiration).and_return(:yay)
        expect(@instance).not_to receive(:expiration=)

        @indirection.find("/my/key")
      end

      it "should filter the result instance if the terminus supports it" do
        allow(@terminus).to receive(:find).and_return(@instance)
        allow(@terminus).to receive(:respond_to?).with(:filter).and_return(true)

        expect(@terminus).to receive(:filter).with(@instance)

        @indirection.find("/my/key")
      end

      describe "when caching is enabled" do
        before do
          @indirection.cache_class = :cache_terminus
          allow(@cache_class).to receive(:new).and_return(@cache)

          allow(@instance).to receive(:expired?).and_return(false)
        end

        it "should first look in the cache for an instance" do
          expect(@terminus).not_to receive(:find)
          expect(@cache).to receive(:find).and_return(@instance)

          @indirection.find("/my/key")
        end

        it "should not look in the cache if the request specifies not to use the cache" do
          expect(@terminus).to receive(:find).and_return(@instance)
          expect(@cache).not_to receive(:find)
          allow(@cache).to receive(:save)

          @indirection.find("/my/key", :ignore_cache => true)
        end

        it "should still save to the cache even if the cache is being ignored during readin" do
          expect(@terminus).to receive(:find).and_return(@instance)
          expect(@cache).to receive(:save)

          @indirection.find("/my/key", :ignore_cache => true)
        end

        it "should not save to the cache if told to skip updating the cache" do
          expect(@terminus).to receive(:find).and_return(@instance)
          expect(@cache).to receive(:find).and_return(nil)
          expect(@cache).not_to receive(:save)

          @indirection.find("/my/key", :ignore_cache_save => true)
        end

        it "should only look in the cache if the request specifies not to use the terminus" do
          expect(@terminus).not_to receive(:find)
          expect(@cache).to receive(:find)

          @indirection.find("/my/key", :ignore_terminus => true)
        end

        it "should use a request to look in the cache for cached objects" do
          expect(@cache).to receive(:find) do |r|
            expect(r.method).to eq(:find)
            expect(r.key).to eq("/my/key")

            @instance
          end

          allow(@cache).to receive(:save)

          @indirection.find("/my/key")
        end

        it "should return the cached object if it is not expired" do
          allow(@instance).to receive(:expired?).and_return(false)

          allow(@cache).to receive(:find).and_return(@instance)
          expect(@indirection.find("/my/key")).to equal(@instance)
        end

        it "should not fail if the cache fails" do
          allow(@terminus).to receive(:find).and_return(@instance)

          expect(@cache).to receive(:find).and_raise(ArgumentError)
          allow(@cache).to receive(:save)
          expect { @indirection.find("/my/key") }.not_to raise_error
        end

        it "should look in the main terminus if the cache fails" do
          expect(@terminus).to receive(:find).and_return(@instance)
          expect(@cache).to receive(:find).and_raise(ArgumentError)
          allow(@cache).to receive(:save)
          expect(@indirection.find("/my/key")).to equal(@instance)
        end

        it "should send a debug log if it is using the cached object" do
          expect(Puppet).to receive(:debug)
          allow(@cache).to receive(:find).and_return(@instance)

          @indirection.find("/my/key")
        end

        it "should not return the cached object if it is expired" do
          allow(@instance).to receive(:expired?).and_return(true)

          allow(@cache).to receive(:find).and_return(@instance)
          allow(@terminus).to receive(:find).and_return(nil)
          expect(@indirection.find("/my/key")).to be_nil
        end

        it "should send an info log if it is using the cached object" do
          expect(Puppet).to receive(:info)
          allow(@instance).to receive(:expired?).and_return(true)

          allow(@cache).to receive(:find).and_return(@instance)
          allow(@terminus).to receive(:find).and_return(nil)
          @indirection.find("/my/key")
        end

        it "should cache any objects not retrieved from the cache" do
          expect(@cache).to receive(:find).and_return(nil)

          expect(@terminus).to receive(:find).and_return(@instance)
          expect(@cache).to receive(:save)

          @indirection.find("/my/key")
        end

        it "should use a request to look in the cache for cached objects" do
          expect(@cache).to receive(:find) do |r|
            expect(r.method).to eq(:find)
            expect(r.key).to eq("/my/key")

            nil
          end

          allow(@terminus).to receive(:find).and_return(@instance)
          allow(@cache).to receive(:save)

          @indirection.find("/my/key")
        end

        it "should cache the instance using a request with the instance set to the cached object" do
          allow(@cache).to receive(:find).and_return(nil)

          allow(@terminus).to receive(:find).and_return(@instance)

          expect(@cache).to receive(:save) do |r|
            expect(r.method).to eq(:save)
            expect(r.instance).to eq(@instance)
          end

          @indirection.find("/my/key")
        end

        it "should send an info log that the object is being cached" do
          allow(@cache).to receive(:find).and_return(nil)

          allow(@terminus).to receive(:find).and_return(@instance)
          allow(@cache).to receive(:save)

          expect(Puppet).to receive(:info)

          @indirection.find("/my/key")
        end

        it "should fail if saving to the cache fails but log the exception" do
          allow(@cache).to receive(:find).and_return(nil)

          allow(@terminus).to receive(:find).and_return(@instance)
          allow(@cache).to receive(:save).and_raise(RuntimeError)

          expect(Puppet).to receive(:log_exception)

          expect { @indirection.find("/my/key") }.to raise_error RuntimeError
        end
      end
    end

    describe "and doing a head operation" do
      before { @method = :head }

      it_should_behave_like "Indirection Delegator"
      it_should_behave_like "Delegation Authorizer"
      it_should_behave_like "Request validator"

      it "should return true if the head method returned true" do
        expect(@terminus).to receive(:head).and_return(true)
        expect(@indirection.head("me")).to eq(true)
      end

      it "should return false if the head method returned false" do
        expect(@terminus).to receive(:head).and_return(false)
        expect(@indirection.head("me")).to eq(false)
      end

      describe "when caching is enabled" do
        before do
          @indirection.cache_class = :cache_terminus
          allow(@cache_class).to receive(:new).and_return(@cache)

          allow(@instance).to receive(:expired?).and_return(false)
        end

        it "should first look in the cache for an instance" do
          expect(@terminus).not_to receive(:find)
          expect(@terminus).not_to receive(:head)
          expect(@cache).to receive(:find).and_return(@instance)

          expect(@indirection.head("/my/key")).to eq(true)
        end

        it "should not save to the cache" do
          expect(@cache).to receive(:find).and_return(nil)
          expect(@cache).not_to receive(:save)
          expect(@terminus).to receive(:head).and_return(true)
          expect(@indirection.head("/my/key")).to eq(true)
        end

        it "should not fail if the cache fails" do
          allow(@terminus).to receive(:head).and_return(true)

          expect(@cache).to receive(:find).and_raise(ArgumentError)
          expect { @indirection.head("/my/key") }.not_to raise_error
        end

        it "should look in the main terminus if the cache fails" do
          expect(@terminus).to receive(:head).and_return(true)
          expect(@cache).to receive(:find).and_raise(ArgumentError)
          expect(@indirection.head("/my/key")).to eq(true)
        end

        it "should send a debug log if it is using the cached object" do
          expect(Puppet).to receive(:debug)
          allow(@cache).to receive(:find).and_return(@instance)

          @indirection.head("/my/key")
        end

        it "should not accept the cached object if it is expired" do
          allow(@instance).to receive(:expired?).and_return(true)

          allow(@cache).to receive(:find).and_return(@instance)
          allow(@terminus).to receive(:head).and_return(false)
          expect(@indirection.head("/my/key")).to eq(false)
        end
      end
    end

    describe "and storing a model instance" do
      before { @method = :save }

      it "should return the result of the save" do
        allow(@terminus).to receive(:save).and_return("foo")
        expect(@indirection.save(@instance)).to eq("foo")
      end

      describe "when caching is enabled" do
        before do
          @indirection.cache_class = :cache_terminus
          allow(@cache_class).to receive(:new).and_return(@cache)

          allow(@instance).to receive(:expired?).and_return(false)
        end

        it "should return the result of saving to the terminus" do
          request = double('request', :instance => @instance, :node => nil, :ignore_cache_save? => false, :ignore_terminus? => false)

          expect(@indirection).to receive(:request).and_return(request)

          allow(@cache).to receive(:save)
          allow(@terminus).to receive(:save).and_return(@instance)
          expect(@indirection.save(@instance)).to equal(@instance)
        end

        it "should use a request to save the object to the cache" do
          request = double('request', :instance => @instance, :node => nil, :ignore_cache_save? => false, :ignore_terminus? => false)

          expect(@indirection).to receive(:request).and_return(request)

          expect(@cache).to receive(:save).with(request)
          allow(@terminus).to receive(:save)
          @indirection.save(@instance)
        end

        it "should not save to the cache if the normal save fails" do
          request = double('request', :instance => @instance, :node => nil, :ignore_terminus? => false)

          expect(@indirection).to receive(:request).and_return(request)

          expect(@cache).not_to receive(:save)
          expect(@terminus).to receive(:save).and_raise("eh")
          expect { @indirection.save(@instance) }.to raise_error(RuntimeError, /eh/)
        end

        it "should not save to the cache if told to ignore saving to the cache" do
          expect(@terminus).to receive(:save)
          expect(@cache).not_to receive(:save)

          @indirection.save(@instance, '/my/key', :ignore_cache_save => true)
        end

        it "should only save to the cache if the request specifies not to use the terminus" do
          expect(@terminus).not_to receive(:save)
          expect(@cache).to receive(:save)

          @indirection.save(@instance, "/my/key", :ignore_terminus => true)
        end
      end
    end

    describe "and removing a model instance" do
      before { @method = :destroy }

      it_should_behave_like "Indirection Delegator"
      it_should_behave_like "Delegation Authorizer"
      it_should_behave_like "Request validator"

      it "should return the result of removing the instance" do
        allow(@terminus).to receive(:destroy).and_return("yayness")
        expect(@indirection.destroy("/my/key")).to eq("yayness")
      end

      describe "when caching is enabled" do
        before do
          @indirection.cache_class = :cache_terminus
          expect(@cache_class).to receive(:new).and_return(@cache)

          allow(@instance).to receive(:expired?).and_return(false)
        end

        it "should use a request instance to search in and remove objects from the cache" do
          destroy = double('destroy_request', :key => "/my/key", :node => nil)
          find = double('destroy_request', :key => "/my/key", :node => nil)

          expect(@indirection).to receive(:request).with(:destroy, "/my/key", nil, be_a(Hash).or(be_nil)).and_return(destroy)
          expect(@indirection).to receive(:request).with(:find, "/my/key", nil, be_a(Hash).or(be_nil)).and_return(find)

          cached = double('cache')

          expect(@cache).to receive(:find).with(find).and_return(cached)
          expect(@cache).to receive(:destroy).with(destroy)

          allow(@terminus).to receive(:destroy)

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
        allow(@terminus).to receive(:search).and_return([@instance])

        expect(@indirection).to receive(:expiration).and_return(:yay)

        expect(@instance).to receive(:expiration).and_return(nil)
        expect(@instance).to receive(:expiration=).with(:yay)

        @indirection.search("/my/key")
      end

      it "should not override an already-set expiration date on returned instances" do
        allow(@terminus).to receive(:search).and_return([@instance])

        expect(@indirection).not_to receive(:expiration)

        expect(@instance).to receive(:expiration).and_return(:yay)
        expect(@instance).not_to receive(:expiration=)

        @indirection.search("/my/key")
      end

      it "should return the results of searching in the terminus" do
        expect(@terminus).to receive(:search).and_return([@instance])
        expect(@indirection.search("/my/key")).to eq([@instance])
      end
    end

    describe "and expiring a model instance" do
      describe "when caching is not enabled" do
        it "should do nothing" do
          expect(@cache_class).not_to receive(:new)

          @indirection.expire("/my/key")
        end
      end

      describe "when caching is enabled" do
        before do
          @indirection.cache_class = :cache_terminus
          expect(@cache_class).to receive(:new).and_return(@cache)

          allow(@instance).to receive(:expired?).and_return(false)

          @cached = double('cached', :expiration= => nil, :name => "/my/key")
        end

        it "should use a request to find within the cache" do
          expect(@cache).to receive(:find) do |r|
            expect(r).to be_a(Puppet::Indirector::Request)
            expect(r.method).to eq(:find)
            nil
          end
          @indirection.expire("/my/key")
        end

        it "should do nothing if no such instance is cached" do
          expect(@cache).to receive(:find).and_return(nil)

          @indirection.expire("/my/key")
        end

        it "should log when expiring a found instance" do
          expect(@cache).to receive(:find).and_return(@cached)
          allow(@cache).to receive(:save)

          expect(Puppet).to receive(:info)

          @indirection.expire("/my/key")
        end

        it "should set the cached instance's expiration to a time in the past" do
          expect(@cache).to receive(:find).and_return(@cached)
          allow(@cache).to receive(:save)

          expect(@cached).to receive(:expiration=).with(be < Time.now)

          @indirection.expire("/my/key")
        end

        it "should save the now expired instance back into the cache" do
          expect(@cache).to receive(:find).and_return(@cached)

          expect(@cached).to receive(:expiration=).with(be < Time.now)

          expect(@cache).to receive(:save)

          @indirection.expire("/my/key")
        end

        it "does not expire an instance if told to skip cache saving" do
          expect(@indirection.cache).not_to receive(:find)
          expect(@indirection.cache).not_to receive(:save)

          @indirection.expire("/my/key", :ignore_cache_save => true)
        end

        it "should use a request to save the expired resource to the cache" do
          expect(@cache).to receive(:find).and_return(@cached)

          expect(@cached).to receive(:expiration=).with(be < Time.now)

          expect(@cache).to receive(:save) do |r|
            expect(r).to be_a(Puppet::Indirector::Request)
            expect(r.instance).to eq(@cached)
            expect(r.method).to eq(:save)

            @cached
          end

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
      @indirection = Puppet::Indirector::Indirection.new(double('model'), :test)
      expect(Puppet::Indirector::Indirection.instance(:test)).to equal(@indirection)
    end

    it "should return nil when the named indirection has not been created" do
      expect(Puppet::Indirector::Indirection.instance(:test)).to be_nil
    end

    it "should allow an indirection's model to be retrieved by name" do
      mock_model = double('model')
      @indirection = Puppet::Indirector::Indirection.new(mock_model, :test)
      expect(Puppet::Indirector::Indirection.model(:test)).to equal(mock_model)
    end

    it "should return nil when no model matches the requested name" do
      expect(Puppet::Indirector::Indirection.model(:test)).to be_nil
    end

    after do
      @indirection.delete if defined?(@indirection)
    end
  end

  describe "when routing to the correct the terminus class" do
    before do
      @indirection = Puppet::Indirector::Indirection.new(double('model'), :test)
      @terminus = double('terminus')
      @terminus_class = double('terminus class', :new => @terminus)
      allow(Puppet::Indirector::Terminus).to receive(:terminus_class).with(:test, :default).and_return(@terminus_class)
    end

    it "should fail if no terminus class can be picked" do
      expect { @indirection.terminus_class }.to raise_error(Puppet::DevError)
    end

    it "should choose the default terminus class if one is specified" do
      @indirection.terminus_class = :default
      expect(@indirection.terminus_class).to equal(:default)
    end

    it "should use the provided Puppet setting if told to do so" do
      allow(Puppet::Indirector::Terminus).to receive(:terminus_class).with(:test, :my_terminus).and_return(double("terminus_class2"))
      Puppet[:node_terminus] = :my_terminus
      @indirection.terminus_setting = :node_terminus
      expect(@indirection.terminus_class).to equal(:my_terminus)
    end

    it "should fail if the provided terminus class is not valid" do
      allow(Puppet::Indirector::Terminus).to receive(:terminus_class).with(:test, :nosuchclass).and_return(nil)
      expect { @indirection.terminus_class = :nosuchclass }.to raise_error(ArgumentError)
    end

    after do
      @indirection.delete if defined?(@indirection)
    end
  end

  describe "when specifying the terminus class to use" do
    before do
      @indirection = Puppet::Indirector::Indirection.new(double('model'), :test)
      @terminus = double('terminus')
      allow(@terminus).to receive(:validate)
      @terminus_class = double('terminus class', :new => @terminus)
    end

    it "should allow specification of a terminus type" do
      expect(@indirection).to respond_to(:terminus_class=)
    end

    it "should fail to redirect if no terminus type has been specified" do
      expect { @indirection.find("blah") }.to raise_error(Puppet::DevError)
    end

    it "should fail when the terminus class name is an empty string" do
      expect { @indirection.terminus_class = "" }.to raise_error(ArgumentError)
    end

    it "should fail when the terminus class name is nil" do
      expect { @indirection.terminus_class = nil }.to raise_error(ArgumentError)
    end

    it "should fail when the specified terminus class cannot be found" do
      expect(Puppet::Indirector::Terminus).to receive(:terminus_class).with(:test, :foo).and_return(nil)
      expect { @indirection.terminus_class = :foo }.to raise_error(ArgumentError)
    end

    it "should select the specified terminus class if a terminus class name is provided" do
      expect(Puppet::Indirector::Terminus).to receive(:terminus_class).with(:test, :foo).and_return(@terminus_class)
      expect(@indirection.terminus(:foo)).to equal(@terminus)
    end

    it "should use the configured terminus class if no terminus name is specified" do
      allow(Puppet::Indirector::Terminus).to receive(:terminus_class).with(:test, :foo).and_return(@terminus_class)
      @indirection.terminus_class = :foo
      expect(@indirection.terminus).to equal(@terminus)
    end

    after do
      @indirection.delete if defined?(@indirection)
    end
  end

  describe "when managing terminus instances" do
    before do
      @indirection = Puppet::Indirector::Indirection.new(double('model'), :test)
      @terminus = double('terminus')
      @terminus_class = double('terminus class')
      allow(Puppet::Indirector::Terminus).to receive(:terminus_class).with(:test, :foo).and_return(@terminus_class)
    end

    it "should create an instance of the chosen terminus class" do
      allow(@terminus_class).to receive(:new).and_return(@terminus)
      expect(@indirection.terminus(:foo)).to equal(@terminus)
    end

    # Make sure it caches the terminus.
    it "should return the same terminus instance each time for a given name" do
      allow(@terminus_class).to receive(:new).and_return(@terminus)
      expect(@indirection.terminus(:foo)).to equal(@terminus)
      expect(@indirection.terminus(:foo)).to equal(@terminus)
    end

    it "should not create a terminus instance until one is actually needed" do
      expect(@indirection).not_to receive(:terminus)
      Puppet::Indirector::Indirection.new(double('model'), :lazytest)
    end

    after do
      @indirection.delete
    end
  end

  describe "when deciding whether to cache" do
    before do
      @indirection = Puppet::Indirector::Indirection.new(double('model'), :test)
      @terminus = double('terminus')
      @terminus_class = double('terminus class')
      allow(@terminus_class).to receive(:new).and_return(@terminus)
      allow(Puppet::Indirector::Terminus).to receive(:terminus_class).with(:test, :foo).and_return(@terminus_class)
      @indirection.terminus_class = :foo
    end

    it "should provide a method for setting the cache terminus class" do
      expect(@indirection).to respond_to(:cache_class=)
    end

    it "should fail to cache if no cache type has been specified" do
      expect { @indirection.cache }.to raise_error(Puppet::DevError)
    end

    it "should fail to set the cache class when the cache class name is an empty string" do
      expect { @indirection.cache_class = "" }.to raise_error(ArgumentError)
    end

    it "should allow resetting the cache_class to nil" do
      @indirection.cache_class = nil
      expect(@indirection.cache_class).to be_nil
    end

    it "should fail to set the cache class when the specified cache class cannot be found" do
      expect(Puppet::Indirector::Terminus).to receive(:terminus_class).with(:test, :foo).and_return(nil)
      expect { @indirection.cache_class = :foo }.to raise_error(ArgumentError)
    end

    after do
      @indirection.delete
    end
  end

  describe "when using a cache" do
    before :each do
      @terminus_class = double('terminus_class')
      @terminus = double('terminus')
      allow(@terminus_class).to receive(:new).and_return(@terminus)
      @cache = double('cache')
      @cache_class = double('cache_class')
      allow(Puppet::Indirector::Terminus).to receive(:terminus_class).with(:test, :cache_terminus).and_return(@cache_class)
      allow(Puppet::Indirector::Terminus).to receive(:terminus_class).with(:test, :test_terminus).and_return(@terminus_class)
      @indirection = Puppet::Indirector::Indirection.new(double('model'), :test)
      @indirection.terminus_class = :test_terminus
    end

    describe "and managing the cache terminus" do
      it "should not create a cache terminus at initialization" do
        # This is weird, because all of the code is in the setup.  If we got
        # new called on the cache class, we'd get an exception here.
      end

      it "should reuse the cache terminus" do
        expect(@cache_class).to receive(:new).and_return(@cache)
        @indirection.cache_class = :cache_terminus
        expect(@indirection.cache).to equal(@cache)
        expect(@indirection.cache).to equal(@cache)
      end
    end

    after :each do
      @indirection.delete
    end
  end
end
