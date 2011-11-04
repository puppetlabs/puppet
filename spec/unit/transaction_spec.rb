#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/transaction'
require 'fileutils'

def without_warnings
  flag = $VERBOSE
  $VERBOSE = nil
  yield
  $VERBOSE = flag
end

describe Puppet::Transaction do
  include PuppetSpec::Files

  before do
    @basepath = make_absolute("/what/ever")
    @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new)
  end

  it "should delegate its event list to the event manager" do
    @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new)
    @transaction.event_manager.expects(:events).returns %w{my events}
    @transaction.events.should == %w{my events}
  end

  it "should delegate adding times to its report" do
    @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new)
    @transaction.report.expects(:add_times).with(:foo, 10)
    @transaction.report.expects(:add_times).with(:bar, 20)

    @transaction.add_times :foo => 10, :bar => 20
  end

  it "should be able to accept resource status instances" do
    resource = Puppet::Type.type(:notify).new :title => "foobar"
    status = Puppet::Resource::Status.new(resource)
    @transaction.add_resource_status(status)
    @transaction.resource_status(resource).should equal(status)
  end

  it "should be able to look resource status up by resource reference" do
    resource = Puppet::Type.type(:notify).new :title => "foobar"
    status = Puppet::Resource::Status.new(resource)
    @transaction.add_resource_status(status)
    @transaction.resource_status(resource.to_s).should equal(status)
  end

  # This will basically only ever be used during testing.
  it "should automatically create resource statuses if asked for a non-existent status" do
    resource = Puppet::Type.type(:notify).new :title => "foobar"
    @transaction.resource_status(resource).should be_instance_of(Puppet::Resource::Status)
  end

  it "should add provided resource statuses to its report" do
    resource = Puppet::Type.type(:notify).new :title => "foobar"
    status = Puppet::Resource::Status.new(resource)
    @transaction.add_resource_status(status)
    @transaction.report.resource_statuses[resource.to_s].should equal(status)
  end

  it "should consider a resource to be failed if a status instance exists for that resource and indicates it is failed" do
    resource = Puppet::Type.type(:notify).new :name => "yayness"
    status = Puppet::Resource::Status.new(resource)
    status.failed = "some message"
    @transaction.add_resource_status(status)
    @transaction.should be_failed(resource)
  end

  it "should not consider a resource to be failed if a status instance exists for that resource but indicates it is not failed" do
    resource = Puppet::Type.type(:notify).new :name => "yayness"
    status = Puppet::Resource::Status.new(resource)
    @transaction.add_resource_status(status)
    @transaction.should_not be_failed(resource)
  end

  it "should consider there to be failed resources if any statuses are marked failed" do
    resource = Puppet::Type.type(:notify).new :name => "yayness"
    status = Puppet::Resource::Status.new(resource)
    status.failed = "some message"
    @transaction.add_resource_status(status)
    @transaction.should be_any_failed
  end

  it "should not consider there to be failed resources if no statuses are marked failed" do
    resource = Puppet::Type.type(:notify).new :name => "yayness"
    status = Puppet::Resource::Status.new(resource)
    @transaction.add_resource_status(status)
    @transaction.should_not be_any_failed
  end

  it "should use the provided report object" do
    report = Puppet::Transaction::Report.new("apply")
    @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new, report)

    @transaction.report.should == report
  end

  it "should create a report if none is provided" do
    @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new)

    @transaction.report.should be_kind_of Puppet::Transaction::Report
  end

  describe "when initializing" do
    it "should create an event manager" do
      @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new)
      @transaction.event_manager.should be_instance_of(Puppet::Transaction::EventManager)
      @transaction.event_manager.transaction.should equal(@transaction)
    end

    it "should create a resource harness" do
      @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new)
      @transaction.resource_harness.should be_instance_of(Puppet::Transaction::ResourceHarness)
      @transaction.resource_harness.transaction.should equal(@transaction)
    end
  end

  describe "when evaluating a resource" do
    before do
      @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new)
      @transaction.stubs(:skip?).returns false

      @resource = Puppet::Type.type(:file).new :path => @basepath
    end

    it "should check whether the resource should be skipped" do
      @transaction.expects(:skip?).with(@resource).returns false

      @transaction.eval_resource(@resource)
    end

    it "should process events" do
      @transaction.event_manager.expects(:process_events).with(@resource)

      @transaction.eval_resource(@resource)
    end

    describe "and the resource should be skipped" do
      before do
        @transaction.expects(:skip?).with(@resource).returns true
      end

      it "should mark the resource's status as skipped" do
        @transaction.eval_resource(@resource)
        @transaction.resource_status(@resource).should be_skipped
      end
    end
  end

  describe "when applying a resource" do
    before do
      @resource = Puppet::Type.type(:file).new :path => @basepath
      @status = Puppet::Resource::Status.new(@resource)

      @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new)
      @transaction.event_manager.stubs(:queue_events)
      @transaction.resource_harness.stubs(:evaluate).returns(@status)
    end

    it "should use its resource harness to apply the resource" do
      @transaction.resource_harness.expects(:evaluate).with(@resource)
      @transaction.apply(@resource)
    end

    it "should add the resulting resource status to its status list" do
      @transaction.apply(@resource)
      @transaction.resource_status(@resource).should be_instance_of(Puppet::Resource::Status)
    end

    it "should queue any events added to the resource status" do
      @status.expects(:events).returns %w{a b}
      @transaction.event_manager.expects(:queue_events).with(@resource, ["a", "b"])
      @transaction.apply(@resource)
    end

    it "should log and skip any resources that cannot be applied" do
      @transaction.resource_harness.expects(:evaluate).raises ArgumentError
      @resource.expects(:err)
      @transaction.apply(@resource)
      @transaction.report.resource_statuses[@resource.to_s].should be_nil
    end
  end

  describe "#eval_generate" do
    let(:path) { tmpdir('eval_generate') }
    let(:resource) { Puppet::Type.type(:file).new(:path => path, :recurse => true) }
    let(:graph) { @transaction.relationship_graph }

    def find_vertex(type, title)
      graph.vertices.find {|v| v.type == type and v.title == title}
    end

    before :each do
      @filenames = []

      'a'.upto('c') do |x|
        @filenames << File.join(path,x)

        'a'.upto('c') do |y|
          @filenames << File.join(path,x,y)
          FileUtils.mkdir_p(File.join(path,x,y))

          'a'.upto('c') do |z|
            @filenames << File.join(path,x,y,z)
            FileUtils.touch(File.join(path,x,y,z))
          end
        end
      end

      @transaction.catalog.add_resource(resource)
    end

    it "should add the generated resources to the catalog" do
      @transaction.eval_generate(resource)

      @filenames.each do |file|
        @transaction.catalog.resource(:file, file).should be_a(Puppet::Type.type(:file))
      end
    end

    it "should add a sentinel whit for the resource" do
      @transaction.eval_generate(resource)

      find_vertex(:whit, "completed_#{path}").should be_a(Puppet::Type.type(:whit))
    end

    it "should replace dependencies on the resource with dependencies on the sentinel" do
      dependent = Puppet::Type.type(:notify).new(:name => "hello", :require => resource)

      @transaction.catalog.add_resource(dependent)

      res = find_vertex(resource.type, resource.title)
      generated = find_vertex(dependent.type, dependent.title)

      graph.should be_edge(res, generated)

      @transaction.eval_generate(resource)

      sentinel = find_vertex(:whit, "completed_#{path}")

      graph.should be_edge(sentinel, generated)
      graph.should_not be_edge(res, generated)
    end

    it "should add an edge from the nearest ancestor to the generated resource" do
      @transaction.eval_generate(resource)

      @filenames.each do |file|
        v = find_vertex(:file, file)
        p = find_vertex(:file, File.dirname(file))

        graph.should be_edge(p, v)
      end
    end

    it "should add an edge from each generated resource to the sentinel" do
      @transaction.eval_generate(resource)

      sentinel = find_vertex(:whit, "completed_#{path}")
      @filenames.each do |file|
        v = find_vertex(:file, file)

        graph.should be_edge(v, sentinel)
      end
    end

    it "should add an edge from the resource to the sentinel" do
      @transaction.eval_generate(resource)

      res = find_vertex(:file, path)
      sentinel = find_vertex(:whit, "completed_#{path}")

      graph.should be_edge(res, sentinel)
    end

    it "should return false if an error occured when generating resources" do
      resource.stubs(:eval_generate).raises(Puppet::Error)

      @transaction.eval_generate(resource).should == false
    end

    it "should return true if resources were generated" do
      @transaction.eval_generate(resource).should == true
    end

    it "should not add a sentinel if no resources are generated" do
      path2 = tmpfile('empty')
      other_file = Puppet::Type.type(:file).new(:path => path2)

      @transaction.catalog.add_resource(other_file)

      @transaction.eval_generate(other_file).should == false

      find_vertex(:whit, "completed_#{path2}").should be_nil
    end
  end

  describe "#unblock" do
    let(:graph) { @transaction.relationship_graph }
    let(:resource) { Puppet::Type.type(:notify).new(:name => 'foo') }

    it "should calculate the number of blockers if it's not known" do
      graph.add_vertex(resource)
      3.times do |i|
        other = Puppet::Type.type(:notify).new(:name => i.to_s)
        graph.add_vertex(other)
        graph.add_edge(other, resource)
      end

      graph.unblock(resource)

      graph.blockers[resource].should == 2
    end

    it "should decrement the number of blockers if there are any" do
      graph.blockers[resource] = 40

      graph.unblock(resource)

      graph.blockers[resource].should == 39
    end

    it "should warn if there are no blockers" do
      vertex = stub('vertex')
      vertex.expects(:warning).with "appears to have a negative number of dependencies"
      graph.blockers[vertex] = 0

      graph.unblock(vertex)
    end

    it "should return true if the resource is now unblocked" do
      graph.blockers[resource] = 1

      graph.unblock(resource).should == true
    end

    it "should return false if the resource is still blocked" do
      graph.blockers[resource] = 2

      graph.unblock(resource).should == false
    end
  end

  describe "when traversing" do
    let(:graph) { @transaction.relationship_graph }
    let(:path) { tmpdir('eval_generate') }
    let(:resource) { Puppet::Type.type(:file).new(:path => path, :recurse => true) }

    before :each do
      @transaction.catalog.add_resource(resource)
    end

    it "should clear blockers if resources are added" do
      graph.blockers['foo'] = 3
      graph.blockers['bar'] = 4

      graph.ready[graph.unguessable_deterministic_key[resource]] = resource

      @transaction.expects(:eval_generate).with(resource).returns true

      graph.traverse {}

      graph.blockers.should be_empty
    end

    it "should yield the resource even if eval_generate is called" do
      graph.ready[graph.unguessable_deterministic_key[resource]] = resource

      @transaction.expects(:eval_generate).with(resource).returns true

      yielded = false
      graph.traverse do |res|
        yielded = true if res == resource
      end

      yielded.should == true
    end

    it "should not clear blockers if resources aren't added" do
      graph.blockers['foo'] = 3
      graph.blockers['bar'] = 4

      graph.ready[graph.unguessable_deterministic_key[resource]] = resource

      @transaction.expects(:eval_generate).with(resource).returns false

      graph.traverse {}

      graph.blockers.should == {'foo' => 3, 'bar' => 4, resource => 0}
    end

    it "should unblock all dependents of the resource" do
      dependent = Puppet::Type.type(:notify).new(:name => "hello", :require => resource)
      dependent2 = Puppet::Type.type(:notify).new(:name => "goodbye", :require => resource)

      @transaction.catalog.add_resource(dependent, dependent2)

      graph.blockers[dependent].should == 1
      graph.blockers[dependent2].should == 1

      graph.ready[graph.unguessable_deterministic_key[resource]] = resource

      graph.traverse {}

      graph.blockers[dependent].should == 0
      graph.blockers[dependent2].should == 0
    end

    it "should enqueue any unblocked dependents" do
      dependent = Puppet::Type.type(:notify).new(:name => "hello", :require => resource)
      dependent2 = Puppet::Type.type(:notify).new(:name => "goodbye", :require => resource)

      @transaction.catalog.add_resource(dependent, dependent2)

      graph.blockers[dependent].should == 1
      graph.blockers[dependent2].should == 1

      graph.ready[graph.unguessable_deterministic_key[resource]] = resource

      seen = []

      graph.traverse do |res|
        seen << res
      end

      seen.should =~ [resource, dependent, dependent2]
    end

    it "should mark the resource done" do
      graph.ready[graph.unguessable_deterministic_key[resource]] = resource

      graph.traverse {}

      graph.done[resource].should == true
    end
  end

  describe "when generating resources" do
    it "should call 'generate' on all created resources" do
      first = Puppet::Type.type(:notify).new(:name => "first")
      second = Puppet::Type.type(:notify).new(:name => "second")
      third = Puppet::Type.type(:notify).new(:name => "third")

      @catalog = Puppet::Resource::Catalog.new
      @transaction = Puppet::Transaction.new(@catalog)

      first.expects(:generate).returns [second]
      second.expects(:generate).returns [third]
      third.expects(:generate)

      @transaction.generate_additional_resources(first)
    end

    it "should finish all resources" do
      generator = stub 'generator', :depthfirst? => true, :tags => [], :ref => "Some[resource]"
      resource = stub 'resource', :tag => nil

      @catalog = Puppet::Resource::Catalog.new
      @transaction = Puppet::Transaction.new(@catalog)

      generator.expects(:generate).returns [resource]

      @catalog.expects(:add_resource).yields(resource)

      resource.expects(:finish)

      @transaction.generate_additional_resources(generator)
    end

    it "should skip generated resources that conflict with existing resources" do
      generator = mock 'generator', :tags => []
      resource = stub 'resource', :tag => nil

      @catalog = Puppet::Resource::Catalog.new
      @transaction = Puppet::Transaction.new(@catalog)

      generator.expects(:generate).returns [resource]

      @catalog.expects(:add_resource).raises(Puppet::Resource::Catalog::DuplicateResourceError.new("foo"))

      resource.expects(:finish).never
      resource.expects(:info) # log that it's skipped

      @transaction.generate_additional_resources(generator)
    end

    it "should copy all tags to the newly generated resources" do
      child = stub 'child', :ref => "Some[child_resource]"
      generator = stub 'resource', :tags => ["one", "two"], :ref => "Some[resource]"

      @catalog = Puppet::Resource::Catalog.new
      @transaction = Puppet::Transaction.new(@catalog)

      generator.stubs(:generate).returns [child]
      @catalog.stubs(:add_resource)

      child.expects(:tag).with("one", "two")
      child.expects(:finish)
      generator.expects(:depthfirst?)

      @transaction.generate_additional_resources(generator)
    end
  end

  describe "when skipping a resource" do
    before :each do
      @resource = Puppet::Type.type(:notify).new :name => "foo"
      @catalog = Puppet::Resource::Catalog.new
      @resource.catalog = @catalog
      @transaction = Puppet::Transaction.new(@catalog)
    end

    it "should skip resource with missing tags" do
      @transaction.stubs(:missing_tags?).returns(true)
      @transaction.should be_skip(@resource)
    end

    it "should skip unscheduled resources" do
      @transaction.stubs(:scheduled?).returns(false)
      @transaction.should be_skip(@resource)
    end

    it "should skip resources with failed dependencies" do
      @transaction.stubs(:failed_dependencies?).returns(true)
      @transaction.should be_skip(@resource)
    end

    it "should skip virtual resource" do
      @resource.stubs(:virtual?).returns true
      @transaction.should be_skip(@resource)
    end

    it "should skip device only resouce on normal host" do
      @resource.stubs(:appliable_to_device?).returns true
      @transaction.for_network_device = false
      @transaction.should be_skip(@resource)
    end

    it "should not skip device only resouce on remote device" do
      @resource.stubs(:appliable_to_device?).returns true
      @transaction.for_network_device = true
      @transaction.should_not be_skip(@resource)
    end

    it "should skip host resouce on device" do
      @resource.stubs(:appliable_to_device?).returns false
      @transaction.for_network_device = true
      @transaction.should be_skip(@resource)
    end
  end

  describe "when determining if tags are missing" do
    before :each do
      @resource = Puppet::Type.type(:notify).new :name => "foo"
      @catalog = Puppet::Resource::Catalog.new
      @resource.catalog = @catalog
      @transaction = Puppet::Transaction.new(@catalog)

      @transaction.stubs(:ignore_tags?).returns false
    end

    it "should not be missing tags if tags are being ignored" do
      @transaction.expects(:ignore_tags?).returns true

      @resource.expects(:tagged?).never

      @transaction.should_not be_missing_tags(@resource)
    end

    it "should not be missing tags if the transaction tags are empty" do
      @transaction.tags = []
      @resource.expects(:tagged?).never
      @transaction.should_not be_missing_tags(@resource)
    end

    it "should otherwise let the resource determine if it is missing tags" do
      tags = ['one', 'two']
      @transaction.tags = tags
      @resource.expects(:tagged?).with(*tags).returns(false)
      @transaction.should be_missing_tags(@resource)
    end
  end

  describe "when determining if a resource should be scheduled" do
    before :each do
      @resource = Puppet::Type.type(:notify).new :name => "foo"
      @catalog = Puppet::Resource::Catalog.new
      @resource.catalog = @catalog
      @transaction = Puppet::Transaction.new(@catalog)
    end

    it "should always schedule resources if 'ignoreschedules' is set" do
      @transaction.ignoreschedules = true
      @transaction.resource_harness.expects(:scheduled?).never

      @transaction.should be_scheduled(@resource)
    end

    it "should let the resource harness determine whether the resource should be scheduled" do
      @transaction.resource_harness.expects(:scheduled?).with(@transaction.resource_status(@resource), @resource).returns "feh"

      @transaction.scheduled?(@resource).should == "feh"
    end
  end

  describe "when prefetching" do
    it "should match resources by name, not title" do
      @catalog = Puppet::Resource::Catalog.new
      @transaction = Puppet::Transaction.new(@catalog)

      # Have both a title and name
      resource = Puppet::Type.type(:sshkey).create :title => "foo", :name => "bar", :type => :dsa, :key => "eh"
      @catalog.add_resource resource

      resource.provider.class.expects(:prefetch).with("bar" => resource)

      @transaction.prefetch
    end
  end

  it "should return all resources for which the resource status indicates the resource has changed when determinig changed resources" do
    @catalog = Puppet::Resource::Catalog.new
    @transaction = Puppet::Transaction.new(@catalog)
    names = []
    2.times do |i|
      name = File.join(@basepath, "file#{i}")
      resource = Puppet::Type.type(:file).new :path => name
      names << resource.to_s
      @catalog.add_resource resource
      @transaction.add_resource_status Puppet::Resource::Status.new(resource)
    end

    @transaction.resource_status(names[0]).changed = true

    @transaction.changed?.should == [@catalog.resource(names[0])]
  end

  describe 'when checking application run state' do
    before do
      without_warnings { Puppet::Application = Class.new(Puppet::Application) }
      @catalog = Puppet::Resource::Catalog.new
      @transaction = Puppet::Transaction.new(@catalog)
    end

    after do
      without_warnings { Puppet::Application = Puppet::Application.superclass }
    end

    it 'should return true for :stop_processing? if Puppet::Application.stop_requested? is true' do
      Puppet::Application.stubs(:stop_requested?).returns(true)
      @transaction.stop_processing?.should be_true
    end

    it 'should return false for :stop_processing? if Puppet::Application.stop_requested? is false' do
      Puppet::Application.stubs(:stop_requested?).returns(false)
      @transaction.stop_processing?.should be_false
    end

    describe 'within an evaluate call' do
      before do
        @resource = Puppet::Type.type(:notify).new :title => "foobar"
        @catalog.add_resource @resource
        @transaction.stubs(:prepare)
      end

      it 'should stop processing if :stop_processing? is true' do
        @transaction.stubs(:stop_processing?).returns(true)
        @transaction.expects(:eval_resource).never
        @transaction.evaluate
      end

      it 'should continue processing if :stop_processing? is false' do
        @transaction.stubs(:stop_processing?).returns(false)
        @transaction.expects(:eval_resource).returns(nil)
        @transaction.evaluate
      end
    end
  end
end

describe Puppet::Transaction, " when determining tags" do
  before do
    @config = Puppet::Resource::Catalog.new
    @transaction = Puppet::Transaction.new(@config)
  end

  it "should default to the tags specified in the :tags setting" do
    Puppet.expects(:[]).with(:tags).returns("one")
    @transaction.tags.should == %w{one}
  end

  it "should split tags based on ','" do
    Puppet.expects(:[]).with(:tags).returns("one,two")
    @transaction.tags.should == %w{one two}
  end

  it "should use any tags set after creation" do
    Puppet.expects(:[]).with(:tags).never
    @transaction.tags = %w{one two}
    @transaction.tags.should == %w{one two}
  end

  it "should always convert assigned tags to an array" do
    @transaction.tags = "one::two"
    @transaction.tags.should == %w{one::two}
  end

  it "should accept a comma-delimited string" do
    @transaction.tags = "one, two"
    @transaction.tags.should == %w{one two}
  end

  it "should accept an empty string" do
    @transaction.tags = ""
    @transaction.tags.should == []
  end
end
