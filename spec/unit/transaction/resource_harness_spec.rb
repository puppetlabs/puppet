#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/transaction/resource_harness'

describe Puppet::Transaction::ResourceHarness do
  include PuppetSpec::Files

  before do
    @mode_750 = Puppet.features.microsoft_windows? ? '644' : '750'
    @mode_755 = Puppet.features.microsoft_windows? ? '644' : '755'
    path = make_absolute("/my/file")

    @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new, nil, nil)
    @resource = Puppet::Type.type(:file).new :path => path
    @harness = Puppet::Transaction::ResourceHarness.new(@transaction)
    @current_state = Puppet::Resource.new(:file, path)
    @resource.stubs(:retrieve).returns @current_state
  end

  it "should accept a transaction at initialization" do
    harness = Puppet::Transaction::ResourceHarness.new(@transaction)
    expect(harness.transaction).to equal(@transaction)
  end

  it "should delegate to the transaction for its relationship graph" do
    @transaction.expects(:relationship_graph).returns "relgraph"
    expect(Puppet::Transaction::ResourceHarness.new(@transaction).relationship_graph).to eq("relgraph")
  end

  describe "when evaluating a resource" do
    it "produces a resource state that describes what happened with the resource" do
      status = @harness.evaluate(@resource)

      expect(status.resource).to eq(@resource.ref)
      expect(status).not_to be_failed
      expect(status.events).to be_empty
    end

    it "retrieves the current state of the resource" do
      @resource.expects(:retrieve).returns @current_state

      @harness.evaluate(@resource)
    end

    it "produces a failure status for the resource when an error occurs" do
      the_message = "retrieve failed in testing"
      @resource.expects(:retrieve).raises(ArgumentError.new(the_message))

      status = @harness.evaluate(@resource)

      expect(status).to be_failed
      expect(events_to_hash(status.events).collect do |event|
        { :@status => event[:@status], :@message => event[:@message] }
      end).to eq([{ :@status => "failure", :@message => the_message }])
    end

    it "records the time it took to evaluate the resource" do
      before = Time.now
      status = @harness.evaluate(@resource)
      after = Time.now

      expect(status.evaluation_time).to be <= after - before
    end
  end

  def events_to_hash(events)
    events.map do |event|
      hash = {}
      event.instance_variables.each do |varname|
        hash[varname.to_sym] = event.instance_variable_get(varname)
      end
      hash
    end
  end

  def make_stub_provider
    stubProvider = Class.new(Puppet::Type)
    stubProvider.instance_eval do
      initvars

      newparam(:name) do
        desc "The name var"
        isnamevar
      end

      newproperty(:foo) do
        desc "A property that can be changed successfully"
        def sync
        end

        def retrieve
          :absent
        end

        def insync?(reference_value)
          false
        end
      end

      newproperty(:bar) do
        desc "A property that raises an exception when you try to change it"
        def sync
          raise ZeroDivisionError.new('bar')
        end

        def retrieve
          :absent
        end

        def insync?(reference_value)
          false
        end
      end

      newproperty(:baz) do
        desc "A property that raises an Exception (not StandardError) when you try to change it"
        def sync
          raise Exception.new('baz')
        end

        def retrieve
          :absent
        end

        def insync?(reference_value)
          false
        end
      end

      newproperty(:brillig) do
        desc "A property that raises a StandardError exception when you test if it's insync?"
        def sync
        end

        def retrieve
          :absent
        end

        def insync?(reference_value)
          raise ZeroDivisionError.new('brillig')
        end
      end

      newproperty(:slithy) do
        desc "A property that raises an Exception when you test if it's insync?"
        def sync
        end

        def retrieve
          :absent
        end

        def insync?(reference_value)
          raise Exception.new('slithy')
        end
      end
    end
    stubProvider
  end


  context "interaction of ensure with other properties" do
    def an_ensurable_resource_reacting_as(behaviors)
      stub_type = Class.new(Puppet::Type)
      stub_type.class_eval do
        initvars
        ensurable do
          def sync
            (@resource.behaviors[:on_ensure] || proc {}).call
          end

          def insync?(value)
            @resource.behaviors[:ensure_insync?]
          end
        end

        newparam(:name) do
          desc "The name var"
          isnamevar
        end

        newproperty(:prop) do
          newvalue("new") do
            #noop
          end

          def retrieve
            "old"
          end
        end

        attr_reader :behaviors

        def initialize(options)
          @behaviors = options.delete(:behaviors)
          super
        end

        def exists?
          @behaviors[:present?]
        end

        def present?(resource)
          @behaviors[:present?]
        end

        def self.name
          "Testing"
        end
      end
      stub_type.new(:behaviors => behaviors,
                    :ensure => :present,
                    :name => "testing",
                    :prop => "new")
    end

    it "ensure errors means that the rest doesn't happen" do
      resource = an_ensurable_resource_reacting_as(:ensure_insync? => false, :on_ensure => proc { raise StandardError }, :present? => true)

      status = @harness.evaluate(resource)

      expect(status.events.length).to eq(1)
      expect(status.events[0].property).to eq('ensure')
      expect(status.events[0].name.to_s).to eq('Testing_created')
      expect(status.events[0].status).to eq('failure')
    end

    it "ensure fails completely means that the rest doesn't happen" do
      resource = an_ensurable_resource_reacting_as(:ensure_insync? => false, :on_ensure => proc { raise Exception }, :present? => false)

      expect do
        @harness.evaluate(resource)
      end.to raise_error(Exception)

      expect(@logs.first.message).to eq("change from absent to present failed: Exception")
      expect(@logs.first.level).to eq(:err)
    end

    it "ensure succeeds means that the rest doesn't happen" do
      resource = an_ensurable_resource_reacting_as(:ensure_insync? => false, :on_ensure => proc { }, :present? => true)

      status = @harness.evaluate(resource)

      expect(status.events.length).to eq(1)
      expect(status.events[0].property).to eq('ensure')
      expect(status.events[0].name.to_s).to eq('Testing_created')
      expect(status.events[0].status).to eq('success')
    end

    it "ensure is in sync means that the rest *does* happen" do
      resource = an_ensurable_resource_reacting_as(:ensure_insync? => true, :present? => true)

      status = @harness.evaluate(resource)

      expect(status.events.length).to eq(1)
      expect(status.events[0].property).to eq('prop')
      expect(status.events[0].name.to_s).to eq('prop_changed')
      expect(status.events[0].status).to eq('success')
    end

    it "ensure is in sync but resource not present, means that the rest doesn't happen" do
      resource = an_ensurable_resource_reacting_as(:ensure_insync? => true, :present? => false)

      status = @harness.evaluate(resource)

      expect(status.events).to be_empty
    end
  end

  describe "when a caught error occurs" do
    before :each do
      stub_provider = make_stub_provider
      resource = stub_provider.new :name => 'name', :foo => 1, :bar => 2
      resource.expects(:err).never
      @status = @harness.evaluate(resource)
    end

    it "should record previous successful events" do
      expect(@status.events[0].property).to eq('foo')
      expect(@status.events[0].status).to eq('success')
    end

    it "should record a failure event" do
      expect(@status.events[1].property).to eq('bar')
      expect(@status.events[1].status).to eq('failure')
    end
  end

  describe "when an Exception occurs during sync" do
    before :each do
      stub_provider = make_stub_provider
      @resource = stub_provider.new :name => 'name', :baz => 1
      @resource.expects(:err).never
    end

    it "should log and pass the exception through" do
      expect { @harness.evaluate(@resource) }.to raise_error(Exception, /baz/)
      expect(@logs.first.message).to eq("change from absent to 1 failed: baz")
      expect(@logs.first.level).to eq(:err)
    end
  end

  describe "when a StandardError exception occurs during insync?" do
    before :each do
      stub_provider = make_stub_provider
      @resource = stub_provider.new :name => 'name', :brillig => 1
      @resource.expects(:err).never
    end

    it "should record a failure event" do
      @status = @harness.evaluate(@resource)
      expect(@status.events[0].name.to_s).to eq('brillig_changed')
      expect(@status.events[0].property).to eq('brillig')
      expect(@status.events[0].status).to eq('failure')
    end
  end

  describe "when an Exception occurs during insync?" do
    before :each do
      stub_provider = make_stub_provider
      @resource = stub_provider.new :name => 'name', :slithy => 1
      @resource.expects(:err).never
    end

    it "should log and pass the exception through" do
      expect { @harness.evaluate(@resource) }.to raise_error(Exception, /slithy/)
      expect(@logs.first.message).to eq("change from absent to 1 failed: slithy")
      expect(@logs.first.level).to eq(:err)
    end
  end

  describe "when auditing" do
    it "should not call insync? on parameters that are merely audited" do
      stub_provider = make_stub_provider
      resource = stub_provider.new :name => 'name', :audit => ['foo']
      resource.property(:foo).expects(:insync?).never
      status = @harness.evaluate(resource)

      expect(status.events).to be_empty
    end

    it "should be able to audit a file's group" do # see bug #5710
      test_file = tmpfile('foo')
      File.open(test_file, 'w').close
      resource = Puppet::Type.type(:file).new :path => test_file, :audit => ['group'], :backup => false
      resource.expects(:err).never # make sure no exceptions get swallowed

      status = @harness.evaluate(resource)

      status.events.each do |event|
        expect(event.status).to != 'failure'
      end
    end

    it "should not ignore microseconds when auditing a file's mtime" do
      test_file = tmpfile('foo')
      File.open(test_file, 'w').close
      resource = Puppet::Type.type(:file).new :path => test_file, :audit => ['mtime'], :backup => false

      # construct a property hash with nanosecond resolution as would be
      # found on an ext4 file system
      time_with_nsec_resolution = Time.at(1000, 123456.999)
      current_from_filesystem    = {:mtime => time_with_nsec_resolution}

      # construct a property hash with a 1 microsecond difference from above
      time_with_usec_resolution = Time.at(1000, 123457.000)
      historical_from_state_yaml = {:mtime => time_with_usec_resolution}

      # set up the sequence of stubs; yeah, this is pretty
      # brittle, so this might need to be adjusted if the
      # resource_harness logic changes
      resource.expects(:retrieve).returns(current_from_filesystem)
      Puppet::Util::Storage.stubs(:cache).with(resource).
        returns(historical_from_state_yaml).then.
        returns(current_from_filesystem).then.
        returns(current_from_filesystem)

      # there should be an audit change recorded, since the two
      # timestamps differ by at least 1 microsecond
      status = @harness.evaluate(resource)
      expect(status.events).not_to be_empty
      status.events.each do |event|
        expect(event.message).to match(/audit change: previously recorded/)
      end
    end

    it "should ignore nanoseconds when auditing a file's mtime" do
      test_file = tmpfile('foo')
      File.open(test_file, 'w').close
      resource = Puppet::Type.type(:file).new :path => test_file, :audit => ['mtime'], :backup => false

      # construct a property hash with nanosecond resolution as would be
      # found on an ext4 file system
      time_with_nsec_resolution = Time.at(1000, 123456.789)
      current_from_filesystem    = {:mtime => time_with_nsec_resolution}

      # construct a property hash with the same timestamp as above,
      # truncated to microseconds, as would be read back from state.yaml
      time_with_usec_resolution = Time.at(1000, 123456.000)
      historical_from_state_yaml = {:mtime => time_with_usec_resolution}

      # set up the sequence of stubs; yeah, this is pretty
      # brittle, so this might need to be adjusted if the
      # resource_harness logic changes
      resource.expects(:retrieve).returns(current_from_filesystem)
      Puppet::Util::Storage.stubs(:cache).with(resource).
        returns(historical_from_state_yaml).then.
        returns(current_from_filesystem).then.
        returns(current_from_filesystem)

      # there should be no audit change recorded, despite the
      # slight difference in the two timestamps
      status = @harness.evaluate(resource)
      status.events.each do |event|
        expect(event.message).not_to match(/audit change: previously recorded/)
      end
    end
  end

  describe "when finding the schedule" do
    before do
      @catalog = Puppet::Resource::Catalog.new
      @resource.catalog = @catalog
    end

    it "should warn and return nil if the resource has no catalog" do
      @resource.catalog = nil
      @resource.expects(:warning)

      expect(@harness.schedule(@resource)).to be_nil
    end

    it "should return nil if the resource specifies no schedule" do
      expect(@harness.schedule(@resource)).to be_nil
    end

    it "should fail if the named schedule cannot be found" do
      @resource[:schedule] = "whatever"
      @resource.expects(:fail)
      @harness.schedule(@resource)
    end

    it "should return the named schedule if it exists" do
      sched = Puppet::Type.type(:schedule).new(:name => "sched")
      @catalog.add_resource(sched)
      @resource[:schedule] = "sched"
      expect(@harness.schedule(@resource).to_s).to eq(sched.to_s)
    end
  end

  describe "when determining if a resource is scheduled" do
    before do
      @catalog = Puppet::Resource::Catalog.new
      @resource.catalog = @catalog
    end

    it "should return true if 'ignoreschedules' is set" do
      Puppet[:ignoreschedules] = true
      @resource[:schedule] = "meh"
      expect(@harness).to be_scheduled(@resource)
    end

    it "should return true if the resource has no schedule set" do
      expect(@harness).to be_scheduled(@resource)
    end

    it "should return the result of matching the schedule with the cached 'checked' time if a schedule is set" do
      t = Time.now
      @harness.expects(:cached).with(@resource, :checked).returns(t)

      sched = Puppet::Type.type(:schedule).new(:name => "sched")
      @catalog.add_resource(sched)
      @resource[:schedule] = "sched"

      sched.expects(:match?).with(t.to_i).returns "feh"

      expect(@harness.scheduled?(@resource)).to eq("feh")
    end
  end

  it "should be able to cache data in the Storage module" do
    data = {}
    Puppet::Util::Storage.expects(:cache).with(@resource).returns data
    @harness.cache(@resource, :foo, "something")

    expect(data[:foo]).to eq("something")
  end

  it "should be able to retrieve data from the cache" do
    data = {:foo => "other"}
    Puppet::Util::Storage.expects(:cache).with(@resource).returns data
    expect(@harness.cached(@resource, :foo)).to eq("other")
  end
end
