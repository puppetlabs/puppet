#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/transaction/resource_harness'

describe Puppet::Transaction::ResourceHarness do
  include PuppetSpec::Files

  before do
    @mode_750 = Puppet.features.microsoft_windows? ? '644' : '750'
    @mode_755 = Puppet.features.microsoft_windows? ? '644' : '755'
    path = make_absolute("/my/file")

    @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new)
    @resource = Puppet::Type.type(:file).new :path => path
    @harness = Puppet::Transaction::ResourceHarness.new(@transaction)
    @current_state = Puppet::Resource.new(:file, path)
    @resource.stubs(:retrieve).returns @current_state
    @status = Puppet::Resource::Status.new(@resource)
    Puppet::Resource::Status.stubs(:new).returns @status
  end

  it "should accept a transaction at initialization" do
    harness = Puppet::Transaction::ResourceHarness.new(@transaction)
    harness.transaction.should equal(@transaction)
  end

  it "should delegate to the transaction for its relationship graph" do
    @transaction.expects(:relationship_graph).returns "relgraph"
    Puppet::Transaction::ResourceHarness.new(@transaction).relationship_graph.should == "relgraph"
  end

  describe "when evaluating a resource" do
    it "should create and return a resource status instance for the resource" do
      @harness.evaluate(@resource).should be_instance_of(Puppet::Resource::Status)
    end

    it "should fail if no status can be created" do
      Puppet::Resource::Status.expects(:new).raises ArgumentError

      lambda { @harness.evaluate(@resource) }.should raise_error
    end

    it "should retrieve the current state of the resource" do
      @resource.expects(:retrieve).returns @current_state
      @harness.evaluate(@resource)
    end

    it "should mark the resource as failed and return if the current state cannot be retrieved" do
      @resource.expects(:retrieve).raises ArgumentError
      @harness.evaluate(@resource).should be_failed
    end

    it "should store the resource's evaluation time in the resource status" do
      @harness.evaluate(@resource).evaluation_time.should be_instance_of(Float)
    end
  end

  def events_to_hash(events)
    events.map do |event|
      hash = {}
      event.instance_variables.each do |varname|
        hash[varname] = event.instance_variable_get(varname.to_sym)
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
    end
    stubProvider
  end

  describe "when an error occurs" do
    before :each do
      stub_provider = make_stub_provider
      resource = stub_provider.new :name => 'name', :foo => 1, :bar => 2
      resource.expects(:err).never
      @status = @harness.evaluate(resource)
    end

    it "should record previous successful events" do
      @status.events[0].property.should == 'foo'
      @status.events[0].status.should == 'success'
    end

    it "should record a failure event" do
      @status.events[1].property.should == 'bar'
      @status.events[1].status.should == 'failure'
    end
  end

  describe "when auditing" do
    it "should not call insync? on parameters that are merely audited" do
      stub_provider = make_stub_provider
      resource = stub_provider.new :name => 'name', :audit => ['foo']
      resource.property(:foo).expects(:insync?).never
      status = @harness.evaluate(resource)
      status.events.each do |event|
        event.status.should != 'failure'
      end
    end

    it "should be able to audit a file's group" do # see bug #5710
      test_file = tmpfile('foo')
      File.open(test_file, 'w').close
      resource = Puppet::Type.type(:file).new :path => test_file, :audit => ['group'], :backup => false
      resource.expects(:err).never # make sure no exceptions get swallowed
      status = @harness.evaluate(resource)
      status.events.each do |event|
        event.status.should != 'failure'
      end
    end
  end

  describe "when applying changes" do
    [false, true].each do |noop_mode|; describe (noop_mode ? "in noop mode" : "in normal mode") do
      [nil, @mode_750].each do |machine_state|; describe (machine_state ? "with a file initially present" : "with no file initially present") do
        [nil, @mode_750, @mode_755].each do |yaml_mode|
          [nil, :file, :absent].each do |yaml_ensure|; describe "with mode=#{yaml_mode.inspect} and ensure=#{yaml_ensure.inspect} stored in state.yml" do
            [false, true].each do |auditing_ensure|
              [false, true].each do |auditing_mode|
                auditing = []
                auditing.push(:mode) if auditing_mode
                auditing.push(:ensure) if auditing_ensure
                [nil, :file, :absent].each do |ensure_property| # what we set "ensure" to in the manifest
                  [nil, @mode_750, @mode_755].each do |mode_property| # what we set "mode" to in the manifest
                    manifest_settings = {}
                    manifest_settings[:audit] = auditing if !auditing.empty?
                    manifest_settings[:ensure] = ensure_property if ensure_property
                    manifest_settings[:mode] = mode_property if mode_property
                    describe "with manifest settings #{manifest_settings.inspect}" do; it "should behave properly" do
                      # Set up preconditions
                      test_file = tmpfile('foo')
                      if machine_state
                        File.open(test_file, 'w', machine_state.to_i(8)).close
                      end

                      Puppet[:noop] = noop_mode
                      params = { :path => test_file, :backup => false }
                      params.merge!(manifest_settings)
                      resource = Puppet::Type.type(:file).new params

                      @harness.cache(resource, :mode, yaml_mode) if yaml_mode
                      @harness.cache(resource, :ensure, yaml_ensure) if yaml_ensure

                      fake_time = Time.utc(2011, 'jan', 3, 12, 24, 0)
                      Time.stubs(:now).returns(fake_time) # So that Puppet::Resource::Status objects will compare properly

                      resource.expects(:err).never # make sure no exceptions get swallowed
                      status = @harness.evaluate(resource) # do the thing

                      # check that the state of the machine has been properly updated
                      expected_logs = []
                      expected_status_events = []
                      if auditing_mode
                        @harness.cached(resource, :mode).should == (machine_state || :absent)
                      else
                        @harness.cached(resource, :mode).should == yaml_mode
                      end
                      if auditing_ensure
                        @harness.cached(resource, :ensure).should == (machine_state ? :file : :absent)
                      else
                        @harness.cached(resource, :ensure).should == yaml_ensure
                      end
                      if ensure_property == :file
                        file_would_be_there_if_not_noop = true
                      elsif ensure_property == nil
                        file_would_be_there_if_not_noop = machine_state != nil
                      else # ensure_property == :absent
                        file_would_be_there_if_not_noop = false
                      end
                      file_should_be_there = noop_mode ? machine_state != nil : file_would_be_there_if_not_noop
                      File.exists?(test_file).should == file_should_be_there
                      if file_should_be_there
                        if noop_mode
                          expected_file_mode = machine_state
                        else
                          expected_file_mode = mode_property || machine_state
                        end
                        if !expected_file_mode
                          # we didn't specify a mode and the file was created, so mode comes from umode
                        else
                          file_mode = File.stat(test_file).mode & 0777
                          file_mode.should == expected_file_mode.to_i(8)
                        end
                      end

                      # Test log output for the "mode" parameter
                      previously_recorded_mode_already_logged = false
                      mode_status_msg = nil
                      if machine_state && file_would_be_there_if_not_noop && mode_property && machine_state != mode_property
                        if noop_mode
                          what_happened = "current_value #{machine_state}, should be #{mode_property} (noop)"
                          expected_status = 'noop'
                        else
                          what_happened = "mode changed '#{machine_state}' to '#{mode_property}'"
                          expected_status = 'success'
                        end
                        if auditing_mode && yaml_mode && yaml_mode != machine_state
                          previously_recorded_mode_already_logged = true
                          mode_status_msg = "#{what_happened} (previously recorded value was #{yaml_mode})"
                        else
                          mode_status_msg = what_happened
                        end
                        expected_logs << "notice: /#{resource}/mode: #{mode_status_msg}"
                      end
                      if @harness.cached(resource, :mode) && @harness.cached(resource, :mode) != yaml_mode
                        if yaml_mode
                          unless previously_recorded_mode_already_logged
                            mode_status_msg = "audit change: previously recorded value #{yaml_mode} has been changed to #{@harness.cached(resource, :mode)}"
                            expected_logs << "notice: /#{resource}/mode: #{mode_status_msg}"
                            expected_status = 'audit'
                          end
                        else
                          expected_logs << "notice: /#{resource}/mode: audit change: newly-recorded value #{@harness.cached(resource, :mode)}"
                        end
                      end
                      if mode_status_msg
                        expected_status_events << Puppet::Transaction::Event.new(
                            :source_description => "/#{resource}/mode", :resource => resource, :file => nil,
                            :line => nil, :tags => %w{file}, :desired_value => mode_property,
                            :historical_value => yaml_mode, :message => mode_status_msg, :name => :mode_changed,
                            :previous_value => machine_state || :absent, :property => :mode, :status => expected_status,
                            :audited => auditing_mode)
                      end

                      # Test log output for the "ensure" parameter
                      previously_recorded_ensure_already_logged = false
                      ensure_status_msg = nil
                      if file_would_be_there_if_not_noop != (machine_state != nil)
                        if noop_mode
                          what_happened = "current_value #{machine_state ? 'file' : 'absent'}, should be #{file_would_be_there_if_not_noop ? 'file' : 'absent'} (noop)"
                          expected_status = 'noop'
                        else
                          what_happened = file_would_be_there_if_not_noop ? 'created' : 'removed'
                          expected_status = 'success'
                        end
                        if auditing_ensure && yaml_ensure && yaml_ensure != (machine_state ? :file : :absent)
                          previously_recorded_ensure_already_logged = true
                          ensure_status_msg = "#{what_happened} (previously recorded value was #{yaml_ensure})"
                        else
                          ensure_status_msg = "#{what_happened}"
                        end
                        expected_logs << "notice: /#{resource}/ensure: #{ensure_status_msg}"
                      end
                      if @harness.cached(resource, :ensure) && @harness.cached(resource, :ensure) != yaml_ensure
                        if yaml_ensure
                          unless previously_recorded_ensure_already_logged
                            ensure_status_msg = "audit change: previously recorded value #{yaml_ensure} has been changed to #{@harness.cached(resource, :ensure)}"
                            expected_logs << "notice: /#{resource}/ensure: #{ensure_status_msg}"
                            expected_status = 'audit'
                          end
                        else
                          expected_logs << "notice: /#{resource}/ensure: audit change: newly-recorded value #{@harness.cached(resource, :ensure)}"
                        end
                      end
                      if ensure_status_msg
                        if ensure_property == :file
                          ensure_event_name = :file_created
                        elsif ensure_property == nil
                          ensure_event_name = :file_changed
                        else # ensure_property == :absent
                          ensure_event_name = :file_removed
                        end
                        expected_status_events << Puppet::Transaction::Event.new(
                            :source_description => "/#{resource}/ensure", :resource => resource, :file => nil,
                            :line => nil, :tags => %w{file}, :desired_value => ensure_property,
                            :historical_value => yaml_ensure, :message => ensure_status_msg, :name => ensure_event_name,
                            :previous_value => machine_state ? :file : :absent, :property => :ensure,
                            :status => expected_status, :audited => auditing_ensure)
                      end

                      # Actually check the logs.
                      @logs.map {|l| "#{l.level}: #{l.source}: #{l.message}"}.should =~ expected_logs

                      # All the log messages should show up as events except the "newly-recorded" ones.
                      expected_event_logs = @logs.reject {|l| l.message =~ /newly-recorded/ }
                      status.events.map {|e| e.message}.should =~ expected_event_logs.map {|l| l.message }
                      events_to_hash(status.events).should =~ events_to_hash(expected_status_events)

                      # Check change count - this is the number of changes that actually occurred.
                      expected_change_count = 0
                      if (machine_state != nil) != file_should_be_there
                        expected_change_count = 1
                      elsif machine_state != nil
                        if expected_file_mode != machine_state
                          expected_change_count = 1
                        end
                      end
                      status.change_count.should == expected_change_count

                      # Check out of sync count - this is the number
                      # of changes that would have occurred in
                      # non-noop mode.
                      expected_out_of_sync_count = 0
                      if (machine_state != nil) != file_would_be_there_if_not_noop
                        expected_out_of_sync_count = 1
                      elsif machine_state != nil
                        if mode_property != nil && mode_property != machine_state
                          expected_out_of_sync_count = 1
                        end
                      end
                      if !noop_mode
                        expected_out_of_sync_count.should == expected_change_count
                      end
                      status.out_of_sync_count.should == expected_out_of_sync_count

                      # Check legacy summary fields
                      status.changed.should == (expected_change_count != 0)
                      status.out_of_sync.should == (expected_out_of_sync_count != 0)

                      # Check the :synced field on state.yml
                      synced_should_be_set = !noop_mode && status.changed
                      (@harness.cached(resource, :synced) != nil).should == synced_should_be_set
                    end; end
                  end
                end
              end
            end
          end; end
        end
      end; end
    end; end

    it "should not apply changes if allow_changes?() returns false" do
      test_file = tmpfile('foo')
      resource = Puppet::Type.type(:file).new :path => test_file, :backup => false, :ensure => :file
      resource.expects(:err).never # make sure no exceptions get swallowed
      @harness.expects(:allow_changes?).with(resource).returns false
      status = @harness.evaluate(resource)
      File.exists?(test_file).should == false
    end
  end

  describe "when determining whether the resource can be changed" do
    before do
      @resource.stubs(:purging?).returns true
      @resource.stubs(:deleting?).returns true
    end

    it "should be true if the resource is not being purged" do
      @resource.expects(:purging?).returns false
      @harness.should be_allow_changes(@resource)
    end

    it "should be true if the resource is not being deleted" do
      @resource.expects(:deleting?).returns false
      @harness.should be_allow_changes(@resource)
    end

    it "should be true if the resource has no dependents" do
      @harness.relationship_graph.expects(:dependents).with(@resource).returns []
      @harness.should be_allow_changes(@resource)
    end

    it "should be true if all dependents are being deleted" do
      dep = stub 'dependent', :deleting? => true
      @harness.relationship_graph.expects(:dependents).with(@resource).returns [dep]
      @resource.expects(:purging?).returns true
      @harness.should be_allow_changes(@resource)
    end

    it "should be false if the resource's dependents are not being deleted" do
      dep = stub 'dependent', :deleting? => false, :ref => "myres"
      @resource.expects(:warning)
      @harness.relationship_graph.expects(:dependents).with(@resource).returns [dep]
      @harness.should_not be_allow_changes(@resource)
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

      @harness.schedule(@resource).should be_nil
    end

    it "should return nil if the resource specifies no schedule" do
      @harness.schedule(@resource).should be_nil
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
      @harness.schedule(@resource).to_s.should == sched.to_s
    end
  end

  describe "when determining if a resource is scheduled" do
    before do
      @catalog = Puppet::Resource::Catalog.new
      @resource.catalog = @catalog
      @status = Puppet::Resource::Status.new(@resource)
    end

    it "should return true if 'ignoreschedules' is set" do
      Puppet[:ignoreschedules] = true
      @resource[:schedule] = "meh"
      @harness.should be_scheduled(@status, @resource)
    end

    it "should return true if the resource has no schedule set" do
      @harness.should be_scheduled(@status, @resource)
    end

    it "should return the result of matching the schedule with the cached 'checked' time if a schedule is set" do
      t = Time.now
      @harness.expects(:cached).with(@resource, :checked).returns(t)

      sched = Puppet::Type.type(:schedule).new(:name => "sched")
      @catalog.add_resource(sched)
      @resource[:schedule] = "sched"

      sched.expects(:match?).with(t.to_i).returns "feh"

      @harness.scheduled?(@status, @resource).should == "feh"
    end
  end

  it "should be able to cache data in the Storage module" do
    data = {}
    Puppet::Util::Storage.expects(:cache).with(@resource).returns data
    @harness.cache(@resource, :foo, "something")

    data[:foo].should == "something"
  end

  it "should be able to retrieve data from the cache" do
    data = {:foo => "other"}
    Puppet::Util::Storage.expects(:cache).with(@resource).returns data
    @harness.cached(@resource, :foo).should == "other"
  end
end
