require 'spec_helper'
require 'matchers/include_in_order'
require 'puppet_spec/compiler'

require 'puppet/transaction'
require 'fileutils'

describe Puppet::Transaction do
  include PuppetSpec::Files
  include PuppetSpec::Compiler

  def catalog_with_resource(resource)
    catalog = Puppet::Resource::Catalog.new
    catalog.add_resource(resource)
    catalog
  end

  def transaction_with_resource(resource)
    transaction = Puppet::Transaction.new(catalog_with_resource(resource), nil, Puppet::Graph::SequentialPrioritizer.new)
    transaction
  end

  before do
    @basepath = make_absolute("/what/ever")
    @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new, nil, Puppet::Graph::SequentialPrioritizer.new)
  end

  it "should be able to look resource status up by resource reference" do
    resource = Puppet::Type.type(:notify).new :title => "foobar"
    transaction = transaction_with_resource(resource)
    transaction.evaluate

    expect(transaction.resource_status(resource.to_s)).to be_changed
  end

  # This will basically only ever be used during testing.
  it "should automatically create resource statuses if asked for a non-existent status" do
    resource = Puppet::Type.type(:notify).new :title => "foobar"
    transaction = transaction_with_resource(resource)
    expect(transaction.resource_status(resource)).to be_instance_of(Puppet::Resource::Status)
  end

  it "should add provided resource statuses to its report" do
    resource = Puppet::Type.type(:notify).new :title => "foobar"
    transaction = transaction_with_resource(resource)
    transaction.evaluate

    status = transaction.resource_status(resource)
    expect(transaction.report.resource_statuses[resource.to_s]).to equal(status)
  end

  it "should not consider there to be failed or failed_to_restart resources if no statuses are marked failed" do
    resource = Puppet::Type.type(:notify).new :title => "foobar"
    transaction = transaction_with_resource(resource)
    transaction.evaluate

    expect(transaction).not_to be_any_failed
  end

  it "should use the provided report object" do
    report = Puppet::Transaction::Report.new
    transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new, report, nil)

    expect(transaction.report).to eq(report)
  end

  it "should create a report if none is provided" do
    transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new, nil, nil)

    expect(transaction.report).to be_kind_of Puppet::Transaction::Report
  end

  describe "when initializing" do
    it "should create an event manager" do
      transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new, nil, nil)
      expect(transaction.event_manager).to be_instance_of(Puppet::Transaction::EventManager)
      expect(transaction.event_manager.transaction).to equal(transaction)
    end

    it "should create a resource harness" do
      transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new, nil, nil)
      expect(transaction.resource_harness).to be_instance_of(Puppet::Transaction::ResourceHarness)
      expect(transaction.resource_harness.transaction).to equal(transaction)
    end

    it "should set retrieval time on the report" do
      catalog = Puppet::Resource::Catalog.new
      report = Puppet::Transaction::Report.new
      catalog.retrieval_duration = 5

      expect(report).to receive(:add_times).with(:config_retrieval, 5)

      Puppet::Transaction.new(catalog, report, nil)
    end
  end

  describe "when evaluating a resource" do
    let(:resource) { Puppet::Type.type(:file).new :path => @basepath }

    it "should process events" do
      transaction = transaction_with_resource(resource)

      expect(transaction).to receive(:skip?).with(resource).and_return(false)
      expect(transaction.event_manager).to receive(:process_events).with(resource)

      transaction.evaluate
    end

    describe "and the resource should be skipped" do
      it "should mark the resource's status as skipped" do
        transaction = transaction_with_resource(resource)

        expect(transaction).to receive(:skip?).with(resource).and_return(true)

        transaction.evaluate
        expect(transaction.resource_status(resource)).to be_skipped
      end

      it "does not process any scheduled events" do
        transaction = transaction_with_resource(resource)
        expect(transaction).to receive(:skip?).with(resource).and_return(true)
        expect(transaction.event_manager).not_to receive(:process_events).with(resource)
        transaction.evaluate
      end

      it "dequeues all events scheduled on that resource" do
        transaction = transaction_with_resource(resource)
        expect(transaction).to receive(:skip?).with(resource).and_return(true)
        expect(transaction.event_manager).to receive(:dequeue_all_events_for_resource).with(resource)
        transaction.evaluate
      end
    end
  end

  describe "when evaluating a skipped resource for corrective change it" do
    before :each do
      # Enable persistence during tests
      allow_any_instance_of(Puppet::Transaction::Persistence).to receive(:enabled?).and_return(true)
    end

    it "should persist in the transactionstore" do
      Puppet[:transactionstorefile] = tmpfile('persistence_test')

      resource = Puppet::Type.type(:notify).new :title => "foobar"
      transaction = transaction_with_resource(resource)
      transaction.evaluate
      expect(transaction.resource_status(resource)).to be_changed

      transaction = transaction_with_resource(resource)
      expect(transaction).to receive(:skip?).with(resource).and_return(true)
      expect(transaction.event_manager).not_to receive(:process_events).with(resource)
      transaction.evaluate
      expect(transaction.resource_status(resource)).to be_skipped

      persistence = Puppet::Transaction::Persistence.new
      persistence.load
      expect(persistence.get_system_value(resource.ref, "message")).to eq(["foobar"])
    end
  end

  describe "when applying a resource" do
    before do
      @catalog = Puppet::Resource::Catalog.new
      @resource = Puppet::Type.type(:file).new :path => @basepath
      @catalog.add_resource(@resource)
      @status = Puppet::Resource::Status.new(@resource)

      @transaction = Puppet::Transaction.new(@catalog, nil, Puppet::Graph::SequentialPrioritizer.new)
      allow(@transaction.event_manager).to receive(:queue_events)
    end

    it "should use its resource harness to apply the resource" do
      expect(@transaction.resource_harness).to receive(:evaluate).with(@resource)
      @transaction.evaluate
    end

    it "should add the resulting resource status to its status list" do
      allow(@transaction.resource_harness).to receive(:evaluate).and_return(@status)
      @transaction.evaluate
      expect(@transaction.resource_status(@resource)).to be_instance_of(Puppet::Resource::Status)
    end

    it "should queue any events added to the resource status" do
      allow(@transaction.resource_harness).to receive(:evaluate).and_return(@status)
      expect(@status).to receive(:events).and_return(%w{a b})
      expect(@transaction.event_manager).to receive(:queue_events).with(@resource, ["a", "b"])
      @transaction.evaluate
    end

    it "should log and skip any resources that cannot be applied" do
      expect(@resource).to receive(:properties).and_raise(ArgumentError)
      @transaction.evaluate
      expect(@transaction.report.resource_statuses[@resource.to_s]).to be_failed
    end

    it "should report any_failed if any resources failed" do
      expect(@resource).to receive(:properties).and_raise(ArgumentError)
      @transaction.evaluate

      expect(@transaction).to be_any_failed
    end

    it "should report any_failed if any resources failed to restart" do
      @transaction.evaluate
      @transaction.report.resource_statuses[@resource.to_s].failed_to_restart = true

      expect(@transaction).to be_any_failed
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

      expect(graph.blockers[resource]).to eq(2)
    end

    it "should decrement the number of blockers if there are any" do
      graph.blockers[resource] = 40

      graph.unblock(resource)

      expect(graph.blockers[resource]).to eq(39)
    end

    it "should warn if there are no blockers" do
      vertex = double('vertex')
      expect(vertex).to receive(:warning).with("appears to have a negative number of dependencies")
      graph.blockers[vertex] = 0

      graph.unblock(vertex)
    end

    it "should return true if the resource is now unblocked" do
      graph.blockers[resource] = 1

      expect(graph.unblock(resource)).to eq(true)
    end

    it "should return false if the resource is still blocked" do
      graph.blockers[resource] = 2

      expect(graph.unblock(resource)).to eq(false)
    end
  end

  describe "when traversing" do
    let(:path) { tmpdir('eval_generate') }
    let(:resource) { Puppet::Type.type(:file).new(:path => path, :recurse => true) }

    before :each do
      @transaction.catalog.add_resource(resource)
    end

    it "should yield the resource even if eval_generate is called" do
      expect_any_instance_of(Puppet::Transaction::AdditionalResourceGenerator).to receive(:eval_generate).with(resource).and_return(true)

      yielded = false
      @transaction.evaluate do |res|
        yielded = true if res == resource
      end

      expect(yielded).to eq(true)
    end

    it "should prefetch the provider if necessary" do
      expect(@transaction).to receive(:prefetch_if_necessary).with(resource)

      @transaction.evaluate {}
    end

    it "traverses independent resources before dependent resources" do
      dependent = Puppet::Type.type(:notify).new(:name => "hello", :require => resource)
      @transaction.catalog.add_resource(dependent)

      seen = []
      @transaction.evaluate do |res|
        seen << res
      end

      expect(seen).to include_in_order(resource, dependent)
    end

    it "traverses completely independent resources in the order they appear in the catalog" do
      independent = Puppet::Type.type(:notify).new(:name => "hello", :require => resource)
      @transaction.catalog.add_resource(independent)

      seen = []
      @transaction.evaluate do |res|
        seen << res
      end

      expect(seen).to include_in_order(resource, independent)
    end

    it "should fail unsuitable resources and go on if it gets blocked" do
      dependent = Puppet::Type.type(:notify).new(:name => "hello", :require => resource)
      @transaction.catalog.add_resource(dependent)

      allow(resource).to receive(:suitable?).and_return(false)

      evaluated = []
      @transaction.evaluate do |res|
        evaluated << res
      end

      # We should have gone on to evaluate the children
      expect(evaluated).to eq([dependent])
      expect(@transaction.resource_status(resource)).to be_failed
    end
  end

  describe "when generating resources before traversal" do
    let(:catalog) { Puppet::Resource::Catalog.new }
    let(:transaction) { Puppet::Transaction.new(catalog, nil, Puppet::Graph::SequentialPrioritizer.new) }
    let(:generator) { Puppet::Type.type(:notify).new :title => "generator" }
    let(:generated) do
      %w[a b c].map { |name| Puppet::Type.type(:notify).new(:name => name) }
    end

    before :each do
      catalog.add_resource generator
      allow(generator).to receive(:generate).and_return(generated)
      # avoid crude failures because of nil resources that result
      # from implicit containment and lacking containers
      allow(catalog).to receive(:container_of).and_return(generator)
    end

    it "should call 'generate' on all created resources" do
      generated.each { |res| expect(res).to receive(:generate) }

      transaction.evaluate
    end

    it "should finish all resources" do
      generated.each { |res| expect(res).to receive(:finish) }

      transaction.evaluate
    end

    it "should copy all tags to the newly generated resources" do
      generator.tag('one', 'two')

      transaction.evaluate

      generated.each do |res|
        expect(res).to be_tagged(*generator.tags)
      end
    end
  end

  describe "after resource traversal" do
    let(:catalog) { Puppet::Resource::Catalog.new }
    let(:prioritizer) { Puppet::Graph::SequentialPrioritizer.new }
    let(:report) { Puppet::Transaction::Report.new }
    let(:transaction) { Puppet::Transaction.new(catalog, report, prioritizer) }
    let(:generator) { Puppet::Transaction::AdditionalResourceGenerator.new(catalog, nil, prioritizer) }

    before :each do
      generator = Puppet::Transaction::AdditionalResourceGenerator.new(catalog, nil, prioritizer)
      allow(Puppet::Transaction::AdditionalResourceGenerator).to receive(:new).and_return(generator)
    end

    it "should should query the generator for whether resources failed to generate" do
      relationship_graph = Puppet::Graph::RelationshipGraph.new(prioritizer)
      allow(catalog).to receive(:relationship_graph).and_return(relationship_graph)

      expect(relationship_graph).to receive(:traverse).ordered
      expect(generator).to receive(:resources_failed_to_generate).ordered

      transaction.evaluate
    end

    it "should report that resources failed to generate" do
      expect(generator).to receive(:resources_failed_to_generate).and_return(true)
      expect(report).to receive(:resources_failed_to_generate=).with(true)

      transaction.evaluate
    end

    it "should not report that resources failed to generate if none did" do
      expect(generator).to receive(:resources_failed_to_generate).and_return(false)
      expect(report).not_to receive(:resources_failed_to_generate=)

      transaction.evaluate
    end
  end

  describe "when performing pre-run checks" do
    let(:resource) { Puppet::Type.type(:notify).new(:title => "spec") }
    let(:transaction) { transaction_with_resource(resource) }
    let(:spec_exception) { 'spec-exception' }

    it "should invoke each resource's hook and apply the catalog after no failures" do
      expect(resource).to receive(:pre_run_check)

      transaction.evaluate
    end

    it "should abort the transaction on failure" do
      expect(resource).to receive(:pre_run_check).and_raise(Puppet::Error, spec_exception)

      expect { transaction.evaluate }.to raise_error(Puppet::Error, /Some pre-run checks failed/)
    end

    it "should log the resource-specific exception" do
      expect(resource).to receive(:pre_run_check).and_raise(Puppet::Error, spec_exception)
      expect(resource).to receive(:log_exception).with(have_attributes(message: match(/#{spec_exception}/)))

      expect { transaction.evaluate }.to raise_error(Puppet::Error)
    end
  end

  describe "when skipping a resource" do
    before :each do
      @resource = Puppet::Type.type(:notify).new :name => "foo"
      @catalog = Puppet::Resource::Catalog.new
      @resource.catalog = @catalog
      @transaction = Puppet::Transaction.new(@catalog, nil, nil)
    end

    it "should skip resource with missing tags" do
      allow(@transaction).to receive(:missing_tags?).and_return(true)
      expect(@transaction).to be_skip(@resource)
    end

    it "should skip resources tagged with the skip tags" do
      allow(@transaction).to receive(:skip_tags?).and_return(true)
      expect(@transaction).to be_skip(@resource)
    end

    it "should skip unscheduled resources" do
      allow(@transaction).to receive(:scheduled?).and_return(false)
      expect(@transaction).to be_skip(@resource)
    end

    it "should skip resources with failed dependencies" do
      allow(@transaction).to receive(:failed_dependencies?).and_return(true)
      expect(@transaction).to be_skip(@resource)
    end

    it "should skip virtual resource" do
      allow(@resource).to receive(:virtual?).and_return(true)
      expect(@transaction).to be_skip(@resource)
    end

    it "should skip device only resouce on normal host" do
      allow(@resource).to receive(:appliable_to_host?).and_return(false)
      allow(@resource).to receive(:appliable_to_device?).and_return(true)
      @transaction.for_network_device = false
      expect(@transaction).to be_skip(@resource)
    end

    it "should not skip device only resouce on remote device" do
      allow(@resource).to receive(:appliable_to_host?).and_return(false)
      allow(@resource).to receive(:appliable_to_device?).and_return(true)
      @transaction.for_network_device = true
      expect(@transaction).not_to be_skip(@resource)
    end

    it "should skip host resouce on device" do
      allow(@resource).to receive(:appliable_to_host?).and_return(true)
      allow(@resource).to receive(:appliable_to_device?).and_return(false)
      @transaction.for_network_device = true
      expect(@transaction).to be_skip(@resource)
    end

    it "should not skip resouce available on both device and host when on device" do
      allow(@resource).to receive(:appliable_to_host?).and_return(true)
      allow(@resource).to receive(:appliable_to_device?).and_return(true)
      @transaction.for_network_device = true
      expect(@transaction).not_to be_skip(@resource)
    end

    it "should not skip resouce available on both device and host when on host" do
      allow(@resource).to receive(:appliable_to_host?).and_return(true)
      allow(@resource).to receive(:appliable_to_device?).and_return(true)
      @transaction.for_network_device = false
      expect(@transaction).not_to be_skip(@resource)
    end
  end

  describe "when determining if tags are missing" do
    before :each do
      @resource = Puppet::Type.type(:notify).new :name => "foo"
      @catalog = Puppet::Resource::Catalog.new
      @resource.catalog = @catalog
      @transaction = Puppet::Transaction.new(@catalog, nil, nil)

      allow(@transaction).to receive(:ignore_tags?).and_return(false)
    end

    it "should not be missing tags if tags are being ignored" do
      expect(@transaction).to receive(:ignore_tags?).and_return(true)

      expect(@resource).not_to receive(:tagged?)

      expect(@transaction).not_to be_missing_tags(@resource)
    end

    it "should not be missing tags if the transaction tags are empty" do
      @transaction.tags = []
      expect(@resource).not_to receive(:tagged?)
      expect(@transaction).not_to be_missing_tags(@resource)
    end

    it "should otherwise let the resource determine if it is missing tags" do
      tags = ['one', 'two']
      @transaction.tags = tags
      expect(@transaction).to be_missing_tags(@resource)
    end
  end

  describe "when determining if a resource should be scheduled" do
    before :each do
      @resource = Puppet::Type.type(:notify).new :name => "foo"
      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource(@resource)
      @transaction = Puppet::Transaction.new(@catalog, nil, Puppet::Graph::SequentialPrioritizer.new)
    end

    it "should always schedule resources if 'ignoreschedules' is set" do
      @transaction.ignoreschedules = true
      expect(@transaction.resource_harness).not_to receive(:scheduled?)

      @transaction.evaluate
      expect(@transaction.resource_status(@resource)).to be_changed
    end

    it "should let the resource harness determine whether the resource should be scheduled" do
      expect(@transaction.resource_harness).to receive(:scheduled?).with(@resource).and_return("feh")

      @transaction.evaluate
    end
  end

  describe "when prefetching" do
    let(:catalog) { Puppet::Resource::Catalog.new }
    let(:transaction) { Puppet::Transaction.new(catalog, nil, nil) }
    let(:resource) { Puppet::Type.type(:package).new :title => "foo", :name => "bar", :provider => :pkgng }
    let(:resource2) { Puppet::Type.type(:package).new :title => "blah", :provider => :apt }

    before :each do
      allow(resource).to receive(:suitable?).and_return(true)
      catalog.add_resource resource
      catalog.add_resource resource2
    end

    it "should match resources by name, not title" do
      expect(resource.provider.class).to receive(:prefetch).with("bar" => resource)

      transaction.prefetch_if_necessary(resource)
    end

    it "should not prefetch a provider which has already been prefetched" do
      transaction.prefetched_providers[:package][:pkgng] = true

      expect(resource.provider.class).not_to receive(:prefetch)

      transaction.prefetch_if_necessary(resource)
    end

    it "should mark the provider prefetched" do
      allow(resource.provider.class).to receive(:prefetch)

      transaction.prefetch_if_necessary(resource)

      expect(transaction.prefetched_providers[:package][:pkgng]).to be_truthy
    end

    it "should prefetch resources without a provider if prefetching the default provider" do
      other = Puppet::Type.type(:package).new :name => "other"
      other.instance_variable_set(:@provider, nil)

      catalog.add_resource other

      allow(resource.class).to receive(:defaultprovider).and_return(resource.provider.class)
      expect(resource.provider.class).to receive(:prefetch).with('bar' => resource, 'other' => other)

      transaction.prefetch_if_necessary(resource)
    end

    it "should not prefetch a provider which has failed" do
      transaction.prefetch_failed_providers[:package][:pkgng] = true

      expect(resource.provider.class).not_to receive(:prefetch)

      transaction.prefetch_if_necessary(resource)
    end

    it "should not rescue SystemExit" do
      expect(resource.provider.class).to receive(:prefetch).and_raise(SystemExit, "SystemMessage")
      expect { transaction.prefetch_if_necessary(resource) }.to raise_error(SystemExit, "SystemMessage")
    end

    it "should rescue LoadError" do
      expect(resource.provider.class).to receive(:prefetch).and_raise(LoadError, "LoadMessage")
      expect { transaction.prefetch_if_necessary(resource) }.not_to raise_error
    end

    describe "and prefetching raises Puppet::Error" do
      before :each do
        expect(resource.provider.class).to receive(:prefetch).and_raise(Puppet::Error, "message")
      end

      it "should rescue prefetch executions" do
        transaction.prefetch_if_necessary(resource)

        expect(transaction.prefetched_providers[:package][:pkgng]).to be_truthy
      end

      it "should mark resources as failed", :unless => RUBY_PLATFORM == 'java' do
        transaction.evaluate

        expect(transaction.resource_status(resource).failed?).to be_truthy
      end

      it "should mark a provider that has failed prefetch" do
        transaction.prefetch_if_necessary(resource)

        expect(transaction.prefetch_failed_providers[:package][:pkgng]).to be_truthy
      end

      describe "and new resources are generated" do
        let(:generator) { Puppet::Type.type(:notify).new :title => "generator" }
        let(:generated) do
          %w[a b c].map { |name| Puppet::Type.type(:package).new :title => "foo", :name => name, :provider => :apt }
        end

        before :each do
          catalog.add_resource generator
          allow(generator).to receive(:generate).and_return(generated)
          allow(catalog).to receive(:container_of).and_return(generator)
        end

        it "should not evaluate resources with a failed provider, even if the prefetch is rescued" do
          #Only the generator resource should be applied, all the other resources are failed, and skipped.
          catalog.remove_resource resource2
          expect(transaction).to receive(:apply).once

          transaction.evaluate
        end

        it "should not fail other resources added after the failing resource", :unless => RUBY_PLATFORM == 'java' do
          new_resource = Puppet::Type.type(:notify).new :name => "baz"
          catalog.add_resource(new_resource)

          transaction.evaluate

          expect(transaction.resource_status(new_resource).failed?).to be_falsey
        end

        it "should fail other resources that require the failing resource" do
          new_resource = Puppet::Type.type(:notify).new(:name => "baz", :require => resource)
          catalog.add_resource(new_resource)

          catalog.remove_resource resource2
          expect(transaction).to receive(:apply).once

          transaction.evaluate

          expect(transaction.resource_status(resource).failed?).to be_truthy
          expect(transaction.resource_status(new_resource).dependency_failed?).to be_truthy
          expect(transaction.skip?(new_resource)).to be_truthy
        end
      end
    end
  end

  describe "during teardown" do
    let(:catalog) { Puppet::Resource::Catalog.new }
    let(:transaction) do
      Puppet::Transaction.new(catalog, nil, Puppet::Graph::SequentialPrioritizer.new)
    end

    let(:teardown_type) do
      Puppet::Type.newtype(:teardown_test) do
        newparam(:name) {}
      end
    end

    before :each do
      teardown_type.provide(:teardown_provider) do
        class << self
          attr_reader :result

          def post_resource_eval
            @result = 'passed'
          end
        end
      end
    end

    it "should call ::post_resource_eval on provider classes that support it" do
      resource = teardown_type.new(:title => "foo", :provider => :teardown_provider)

      transaction = transaction_with_resource(resource)
      transaction.evaluate

      expect(resource.provider.class.result).to eq('passed')
    end

    it "should call ::post_resource_eval even if other providers' ::post_resource_eval fails" do
      teardown_type.provide(:always_fails) do
        class << self
          attr_reader :result

          def post_resource_eval
            @result = 'failed'
            raise Puppet::Error, "This provider always fails"
          end
        end
      end

      good_resource = teardown_type.new(:title => "bloo", :provider => :teardown_provider)
      bad_resource  = teardown_type.new(:title => "blob", :provider => :always_fails)

      catalog.add_resource(bad_resource)
      catalog.add_resource(good_resource)

      transaction.evaluate

      expect(good_resource.provider.class.result).to eq('passed')
      expect(bad_resource.provider.class.result).to eq('failed')
    end

    it "should call ::post_resource_eval even if one of the resources fails" do
      resource = teardown_type.new(:title => "foo", :provider => :teardown_provider)
      allow(resource).to receive(:retrieve_resource).and_raise
      catalog.add_resource resource

      expect(resource.provider.class).to receive(:post_resource_eval)

      transaction.evaluate
    end

    it "should call Selinux.matchpathcon_fini in case Selinux is enabled ", :if => Puppet.features.posix? do
      unless defined?(Selinux)
        module Selinux
          def self.is_selinux_enabled
            true
          end
        end
      end

      resource = Puppet::Type.type(:file).new(:path => make_absolute("/tmp/foo"))
      transaction = transaction_with_resource(resource)

      expect(Selinux).to receive(:matchpathcon_fini)
      expect(Puppet::Util::SELinux).to receive(:selinux_support?).and_return(true)

      transaction.evaluate
    end
  end

  describe 'when checking application run state' do
    before do
      @catalog = Puppet::Resource::Catalog.new
      @transaction = Puppet::Transaction.new(@catalog, nil, Puppet::Graph::SequentialPrioritizer.new)
    end

    context "when stop is requested" do
      before :each do
        allow(Puppet::Application).to receive(:stop_requested?).and_return(true)
      end

      it 'should return true for :stop_processing?' do
        expect(@transaction).to be_stop_processing
      end

      it 'always evaluates non-host_config catalogs' do
        @catalog.host_config = false
        expect(@transaction).not_to be_stop_processing
      end
    end

    it 'should return false for :stop_processing? if Puppet::Application.stop_requested? is false' do
      allow(Puppet::Application).to receive(:stop_requested?).and_return(false)
      expect(@transaction.stop_processing?).to be_falsey
    end

    describe 'within an evaluate call' do
      before do
        @resource = Puppet::Type.type(:notify).new :title => "foobar"
        @catalog.add_resource @resource
        allow(@transaction).to receive(:add_dynamically_generated_resources)
      end

      it 'should stop processing if :stop_processing? is true' do
        allow(@transaction).to receive(:stop_processing?).and_return(true)
        expect(@transaction).not_to receive(:eval_resource)
        @transaction.evaluate
      end

      it 'should continue processing if :stop_processing? is false' do
        allow(@transaction).to receive(:stop_processing?).and_return(false)
        expect(@transaction).to receive(:eval_resource).and_return(nil)
        @transaction.evaluate
      end
    end
  end

  it "errors with a dependency cycle for a resource that requires itself" do
    expect(Puppet).to receive(:err).with(/Found 1 dependency cycle:.*\(Notify\[cycle\] => Notify\[cycle\]\)/m)
    expect do
      apply_compiled_manifest(<<-MANIFEST)
        notify { cycle: require => Notify[cycle] }
      MANIFEST
    end.to raise_error(Puppet::Error, 'One or more resource dependency cycles detected in graph')
  end

  it "errors with a dependency cycle for a self-requiring resource also required by another resource" do
    expect(Puppet).to receive(:err).with(/Found 1 dependency cycle:.*\(Notify\[cycle\] => Notify\[cycle\]\)/m)
    expect do
      apply_compiled_manifest(<<-MANIFEST)
        notify { cycle: require => Notify[cycle] }
        notify { other: require => Notify[cycle] }
      MANIFEST
    end.to raise_error(Puppet::Error, 'One or more resource dependency cycles detected in graph')
  end

  it "errors with a dependency cycle for a resource that requires itself and another resource" do
    expect(Puppet).to receive(:err).with(/Found 1 dependency cycle:.*\(Notify\[cycle\] => Notify\[cycle\]\)/m)
    expect do
      apply_compiled_manifest(<<-MANIFEST)
        notify { cycle:
          require => [Notify[other], Notify[cycle]]
        }
        notify { other: }
      MANIFEST
    end.to raise_error(Puppet::Error, 'One or more resource dependency cycles detected in graph')
  end

  it "errors with a dependency cycle for a resource that is later modified to require itself" do
    expect(Puppet).to receive(:err).with(/Found 1 dependency cycle:.*\(Notify\[cycle\] => Notify\[cycle\]\)/m)
    expect do
      apply_compiled_manifest(<<-MANIFEST)
        notify { cycle: }
        Notify <| title == 'cycle' |> {
          require => Notify[cycle]
        }
      MANIFEST
    end.to raise_error(Puppet::Error, 'One or more resource dependency cycles detected in graph')
  end

  context "when generating a report for a transaction with a dependency cycle" do
    let(:catalog) do
      compile_to_ral(<<-MANIFEST)
        notify { foo: require => Notify[bar] }
        notify { bar: require => Notify[foo] }
      MANIFEST
    end

    let(:prioritizer) { Puppet::Graph::SequentialPrioritizer.new }
    let(:transaction) { Puppet::Transaction.new(catalog,
                                          Puppet::Transaction::Report.new("apply"),
                                          prioritizer) }

    before(:each) do
      expect { transaction.evaluate }.to raise_error(Puppet::Error)
      transaction.report.finalize_report
    end

    it "should report resources involved in a dependency cycle as failed" do
      expect(transaction.report.resource_statuses['Notify[foo]']).to be_failed
      expect(transaction.report.resource_statuses['Notify[bar]']).to be_failed
    end

    it "should generate a failure event for a resource in a dependency cycle" do
      status = transaction.report.resource_statuses['Notify[foo]']
      expect(status.events.first.status).to eq('failure')
      expect(status.events.first.message).to eq('resource is part of a dependency cycle')
    end

    it "should report that the transaction is failed" do
      expect(transaction.report.status).to eq('failed')
    end
  end

  it "reports a changed resource with a successful run" do
    transaction = apply_compiled_manifest("notify { one: }")

    expect(transaction.report.status).to eq('changed')
    expect(transaction.report.resource_statuses['Notify[one]']).to be_changed
  end

  describe "when interrupted" do
    it "marks unprocessed resources as skipped" do
      Puppet::Application.stop!

      transaction = apply_compiled_manifest(<<-MANIFEST)
        notify { a: } ->
        notify { b: }
      MANIFEST

      expect(transaction.report.resource_statuses['Notify[a]']).to be_skipped
      expect(transaction.report.resource_statuses['Notify[b]']).to be_skipped
    end
  end

  describe "failed dependency is depended on multiple times" do
    it "notifies the failed dependency once" do
      command_string = File.expand_path('/my/command')
      allow(Puppet::Util::Execution).to receive(:execute).with([command_string]).and_raise(Puppet::ExecutionFailure, "Failed")

      allow_any_instance_of(Puppet::Type::Notify).to receive(:send_log).with(:notice, "Dependency Exec[exec1] has failures: true")
      allow_any_instance_of(Puppet::Type::Notify).to receive(:send_log).with(:notice, "Dependency Exec[exec2] has failures: true")
      allow_any_instance_of(Puppet::Type::Notify).to receive(:send_log).with(:notice, "Dependency Exec[exec3] has failures: true")
      allow_any_instance_of(Puppet::Type::Notify).to receive(:send_log).with(:notice, "Dependency Exec[exec4] has failures: true")
      allow_any_instance_of(Puppet::Type::Notify).to receive(:send_log).with(:notice, "Dependency Exec[exec5] has failures: true")

      times_send_log_with_skipping_called = 0
      allow_any_instance_of(Puppet::Type::Notify).to receive(:send_log) {times_send_log_with_skipping_called += 1; nil}.with(:warning, "Skipping because of failed dependencies")

      apply_compiled_manifest(<<-MANIFEST)
        exec { ['exec1', 'exec2', 'exec3', 'exec4', 'exec5']:
          command => '#{command_string}'
        } ->
        notify { ['notify1', 'notify2', 'notify3']: }
      MANIFEST
      expect(times_send_log_with_skipping_called).to eq(3)
    end
  end

  describe "failed dependency is depended on multiple times" do
    it "notifies and warns the failed class dependency once" do
      Puppet.settings[:merge_dependency_warnings] = true

      command_string = File.expand_path('/my/command')
      allow(Puppet::Util::Execution).to receive(:execute).with([command_string]).and_raise(Puppet::ExecutionFailure, "Failed")

      # Exec['exec1'] is outside of a class, so it's warning is not subject to being coalesced.
      times_send_log_with_skipping_called = 0
      allow_any_instance_of(Puppet::Type::Exec).to receive(:send_log) {times_send_log_with_skipping_called += 1; nil}.with(:warning, "Skipping because of failed dependencies")

      # Class['declared_class'] depends upon Class['required_class'] which contains a resource with a failure.
      times_send_log_with_class_dependency_called = 0
      allow_any_instance_of(Puppet::Type).to receive(:send_log) {times_send_log_with_class_dependency_called += 1; nil}.with(:notice, "Class dependency Exec[exec2] has failures: true")
      times_send_log_with_class_skipping_called = 0
      allow_any_instance_of(Puppet::Type).to receive(:send_log) {times_send_log_with_class_skipping_called += 1; nil}.with(:warning, "Skipping resources in class because of failed class dependencies")

      apply_compiled_manifest(<<-MANIFEST)
        class required_class {
          exec { 'exec2':
            command => '#{command_string}'
          }
        }
        class declared_class {
          require required_class
          exec { 'exec3':
            command => '#{command_string}'
          }
          exec { 'exec4':
            command => '#{command_string}'
          }
        }
        exec { 'exec1':
          command => '#{command_string}',
          require => Exec['exec2']
        }
        include declared_class
      MANIFEST

      expect(times_send_log_with_skipping_called).to eq(1)
      expect(times_send_log_with_class_dependency_called).to eq(1)
      expect(times_send_log_with_class_skipping_called).to eq(1)
    end
  end
end

describe Puppet::Transaction, " when determining tags" do
  before do
    @config = Puppet::Resource::Catalog.new
    @transaction = Puppet::Transaction.new(@config, nil, nil)
  end

  it "should default to the tags specified in the :tags setting" do
    Puppet[:tags] = "one"
    expect(@transaction).to be_tagged("one")
  end

  it "should split tags based on ','" do
    Puppet[:tags] = "one,two"
    expect(@transaction).to be_tagged("one")
    expect(@transaction).to be_tagged("two")
  end

  it "should use any tags set after creation" do
    Puppet[:tags] = ""
    @transaction.tags = %w{one two}
    expect(@transaction).to be_tagged("one")
    expect(@transaction).to be_tagged("two")
  end

  it "should always convert assigned tags to an array" do
    @transaction.tags = "one::two"
    expect(@transaction).to be_tagged("one::two")
  end

  it "should tag one::two only as 'one::two' and not 'one', 'two', and 'one::two'" do
    @transaction.tags = "one::two"
    expect(@transaction).to be_tagged("one::two")
    expect(@transaction).to_not be_tagged("one")
    expect(@transaction).to_not be_tagged("two")
  end

  it "should accept a comma-delimited string" do
    @transaction.tags = "one, two"
    expect(@transaction).to be_tagged("one")
    expect(@transaction).to be_tagged("two")
  end

  it "should accept an empty string" do
    @transaction.tags = "one, two"
    expect(@transaction).to be_tagged("one")
    @transaction.tags = ""
    expect(@transaction).not_to be_tagged("one")
  end
end
