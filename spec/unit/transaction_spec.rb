#! /usr/bin/env ruby
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
    transaction = Puppet::Transaction.new(catalog_with_resource(resource), nil, Puppet::Graph::RandomPrioritizer.new)
    transaction
  end

  before do
    @basepath = make_absolute("/what/ever")
    @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new, nil, Puppet::Graph::RandomPrioritizer.new)
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

      report.expects(:add_times).with(:config_retrieval, 5)

      Puppet::Transaction.new(catalog, report, nil)
    end
  end

  describe "when evaluating a resource" do
    let(:resource) { Puppet::Type.type(:file).new :path => @basepath }

    it "should process events" do
      transaction = transaction_with_resource(resource)

      transaction.expects(:skip?).with(resource).returns false
      transaction.event_manager.expects(:process_events).with(resource)

      transaction.evaluate
    end

    describe "and the resource should be skipped" do
      it "should mark the resource's status as skipped" do
        transaction = transaction_with_resource(resource)

        transaction.expects(:skip?).with(resource).returns true

        transaction.evaluate
        expect(transaction.resource_status(resource)).to be_skipped
      end

      it "does not process any scheduled events" do
        transaction = transaction_with_resource(resource)
        transaction.expects(:skip?).with(resource).returns true
        transaction.event_manager.expects(:process_events).with(resource).never
        transaction.evaluate
      end

      it "dequeues all events scheduled on that resource" do
        transaction = transaction_with_resource(resource)
        transaction.expects(:skip?).with(resource).returns true
        transaction.event_manager.expects(:dequeue_all_events_for_resource).with(resource)
        transaction.evaluate
      end
    end
  end

  describe "when evaluating a skipped resource for corrective change it" do
    before :each do
      # Enable persistence during tests
      Puppet::Transaction::Persistence.any_instance.stubs(:enabled?).returns(true)
    end

    it "should persist in the transactionstore" do
      Puppet[:transactionstorefile] = tmpfile('persistence_test')

      resource = Puppet::Type.type(:notify).new :title => "foobar"
      transaction = transaction_with_resource(resource)
      transaction.evaluate
      expect(transaction.resource_status(resource)).to be_changed

      transaction = transaction_with_resource(resource)
      transaction.expects(:skip?).with(resource).returns true
      transaction.event_manager.expects(:process_events).with(resource).never
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

      @transaction = Puppet::Transaction.new(@catalog, nil, Puppet::Graph::RandomPrioritizer.new)
      @transaction.event_manager.stubs(:queue_events)
    end

    it "should use its resource harness to apply the resource" do
      @transaction.resource_harness.expects(:evaluate).with(@resource)
      @transaction.evaluate
    end

    it "should add the resulting resource status to its status list" do
      @transaction.resource_harness.stubs(:evaluate).returns(@status)
      @transaction.evaluate
      expect(@transaction.resource_status(@resource)).to be_instance_of(Puppet::Resource::Status)
    end

    it "should queue any events added to the resource status" do
      @transaction.resource_harness.stubs(:evaluate).returns(@status)
      @status.expects(:events).returns %w{a b}
      @transaction.event_manager.expects(:queue_events).with(@resource, ["a", "b"])
      @transaction.evaluate
    end

    it "should log and skip any resources that cannot be applied" do
      @resource.expects(:properties).raises ArgumentError
      @transaction.evaluate
      expect(@transaction.report.resource_statuses[@resource.to_s]).to be_failed
    end

    it "should report any_failed if any resources failed" do
      @resource.expects(:properties).raises ArgumentError
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
      vertex = stub('vertex')
      vertex.expects(:warning).with "appears to have a negative number of dependencies"
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
      Puppet::Transaction::AdditionalResourceGenerator.any_instance.expects(:eval_generate).with(resource).returns true

      yielded = false
      @transaction.evaluate do |res|
        yielded = true if res == resource
      end

      expect(yielded).to eq(true)
    end

    it "should prefetch the provider if necessary" do
      @transaction.expects(:prefetch_if_necessary).with(resource)

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

      resource.stubs(:suitable?).returns false

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
    let(:transaction) { Puppet::Transaction.new(catalog, nil, Puppet::Graph::RandomPrioritizer.new) }
    let(:generator) { Puppet::Type.type(:notify).new :title => "generator" }
    let(:generated) do
      %w[a b c].map { |name| Puppet::Type.type(:notify).new(:name => name) }
    end

    before :each do
      catalog.add_resource generator
      generator.stubs(:generate).returns generated
      # avoid crude failures because of nil resources that result
      # from implicit containment and lacking containers
      catalog.stubs(:container_of).returns generator
    end

    it "should call 'generate' on all created resources" do
      generated.each { |res| res.expects(:generate) }

      transaction.evaluate
    end

    it "should finish all resources" do
      generated.each { |res| res.expects(:finish) }

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
    let(:prioritizer) { Puppet::Graph::RandomPrioritizer.new }
    let(:report) { Puppet::Transaction::Report.new }
    let(:transaction) { Puppet::Transaction.new(catalog, report, prioritizer) }
    let(:generator) { Puppet::Transaction::AdditionalResourceGenerator.new(catalog, nil, prioritizer) }

    before :each do
      generator = Puppet::Transaction::AdditionalResourceGenerator.new(catalog, nil, prioritizer)
      Puppet::Transaction::AdditionalResourceGenerator.stubs(:new).returns(generator)
    end

    it "should should query the generator for whether resources failed to generate" do
      relationship_graph = Puppet::Graph::RelationshipGraph.new(prioritizer)
      catalog.stubs(:relationship_graph).returns(relationship_graph)

      sequence = sequence(:traverse_first)
      relationship_graph.expects(:traverse).in_sequence(sequence)
      generator.expects(:resources_failed_to_generate).in_sequence(sequence)

      transaction.evaluate
    end

    it "should report that resources failed to generate" do
      generator.expects(:resources_failed_to_generate).returns(true)
      report.expects(:resources_failed_to_generate=).with(true)

      transaction.evaluate
    end

    it "should not report that resources failed to generate if none did" do
      generator.expects(:resources_failed_to_generate).returns(false)
      report.expects(:resources_failed_to_generate=).never

      transaction.evaluate
    end
  end

  describe "when performing pre-run checks" do
    let(:resource) { Puppet::Type.type(:notify).new(:title => "spec") }
    let(:transaction) { transaction_with_resource(resource) }
    let(:spec_exception) { 'spec-exception' }

    it "should invoke each resource's hook and apply the catalog after no failures" do
      resource.expects(:pre_run_check)

      transaction.evaluate
    end

    it "should abort the transaction on failure" do
      resource.expects(:pre_run_check).raises(Puppet::Error, spec_exception)

      expect { transaction.evaluate }.to raise_error(Puppet::Error, /Some pre-run checks failed/)
    end

    it "should log the resource-specific exception" do
      resource.expects(:pre_run_check).raises(Puppet::Error, spec_exception)
      resource.expects(:log_exception).with(responds_with(:message, spec_exception))

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
      @transaction.stubs(:missing_tags?).returns(true)
      expect(@transaction).to be_skip(@resource)
    end

    it "should skip resources tagged with the skip tags" do
      @transaction.stubs(:skip_tags?).returns(true)
      expect(@transaction).to be_skip(@resource)
    end

    it "should skip unscheduled resources" do
      @transaction.stubs(:scheduled?).returns(false)
      expect(@transaction).to be_skip(@resource)
    end

    it "should skip resources with failed dependencies" do
      @transaction.stubs(:failed_dependencies?).returns(true)
      expect(@transaction).to be_skip(@resource)
    end

    it "should skip virtual resource" do
      @resource.stubs(:virtual?).returns true
      expect(@transaction).to be_skip(@resource)
    end

    it "should skip device only resouce on normal host" do
      @resource.stubs(:appliable_to_host?).returns false
      @resource.stubs(:appliable_to_device?).returns true
      @transaction.for_network_device = false
      expect(@transaction).to be_skip(@resource)
    end

    it "should not skip device only resouce on remote device" do
      @resource.stubs(:appliable_to_host?).returns false
      @resource.stubs(:appliable_to_device?).returns true
      @transaction.for_network_device = true
      expect(@transaction).not_to be_skip(@resource)
    end

    it "should skip host resouce on device" do
      @resource.stubs(:appliable_to_host?).returns true
      @resource.stubs(:appliable_to_device?).returns false
      @transaction.for_network_device = true
      expect(@transaction).to be_skip(@resource)
    end

    it "should not skip resouce available on both device and host when on device" do
      @resource.stubs(:appliable_to_host?).returns true
      @resource.stubs(:appliable_to_device?).returns true
      @transaction.for_network_device = true
      expect(@transaction).not_to be_skip(@resource)
    end

    it "should not skip resouce available on both device and host when on host" do
      @resource.stubs(:appliable_to_host?).returns true
      @resource.stubs(:appliable_to_device?).returns true
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

      @transaction.stubs(:ignore_tags?).returns false
    end

    it "should not be missing tags if tags are being ignored" do
      @transaction.expects(:ignore_tags?).returns true

      @resource.expects(:tagged?).never

      expect(@transaction).not_to be_missing_tags(@resource)
    end

    it "should not be missing tags if the transaction tags are empty" do
      @transaction.tags = []
      @resource.expects(:tagged?).never
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
      @transaction = Puppet::Transaction.new(@catalog, nil, Puppet::Graph::RandomPrioritizer.new)
    end

    it "should always schedule resources if 'ignoreschedules' is set" do
      @transaction.ignoreschedules = true
      @transaction.resource_harness.expects(:scheduled?).never

      @transaction.evaluate
      expect(@transaction.resource_status(@resource)).to be_changed
    end

    it "should let the resource harness determine whether the resource should be scheduled" do
      @transaction.resource_harness.expects(:scheduled?).with(@resource).returns "feh"

      @transaction.evaluate
    end
  end

  describe "when prefetching" do
    let(:catalog) { Puppet::Resource::Catalog.new }
    let(:transaction) { Puppet::Transaction.new(catalog, nil, nil) }
    let(:resource) { Puppet::Type.type(:sshkey).new :title => "foo", :name => "bar", :type => :dsa, :key => "eh", :provider => :parsed }
    let(:resource2) { Puppet::Type.type(:package).new :title => "blah", :provider => "apt" }

    before :each do
      catalog.add_resource resource
      catalog.add_resource resource2
    end

    it "should match resources by name, not title" do
      resource.provider.class.expects(:prefetch).with("bar" => resource)

      transaction.prefetch_if_necessary(resource)
    end

    it "should not prefetch a provider which has already been prefetched" do
      transaction.prefetched_providers[:sshkey][:parsed] = true

      resource.provider.class.expects(:prefetch).never

      transaction.prefetch_if_necessary(resource)
    end

    it "should mark the provider prefetched" do
      resource.provider.class.stubs(:prefetch)

      transaction.prefetch_if_necessary(resource)

      expect(transaction.prefetched_providers[:sshkey][:parsed]).to be_truthy
    end

    it "should prefetch resources without a provider if prefetching the default provider" do
      other = Puppet::Type.type(:sshkey).new :name => "other"

      other.instance_variable_set(:@provider, nil)

      catalog.add_resource other

      resource.provider.class.expects(:prefetch).with('bar' => resource, 'other' => other)

      transaction.prefetch_if_necessary(resource)
    end

    it "should not prefetch a provider which has failed" do
      transaction.prefetch_failed_providers[:sshkey][:parsed] = true

      resource.provider.class.expects(:prefetch).never

      transaction.prefetch_if_necessary(resource)
    end

    describe "and prefetching fails" do
      before :each do
        resource.provider.class.expects(:prefetch).raises(Puppet::Error, "message")
      end

      context "without future_features flag" do
        before :each do
          Puppet.settings[:future_features] = false
        end

        it "should not rescue prefetch executions" do
          expect { transaction.prefetch_if_necessary(resource) }.to raise_error(Puppet::Error)
        end
      end

      context "with future_features flag" do
        before :each do
          Puppet.settings[:future_features] = true
        end

        it "should rescue prefetch executions" do
          transaction.prefetch_if_necessary(resource)

          expect(transaction.prefetched_providers[:sshkey][:parsed]).to be_truthy
        end

        it "should mark resources as failed" do
          transaction.evaluate

          expect(transaction.resource_status(resource).failed?).to be_truthy
        end

        it "should mark a provider that has failed prefetch" do
          transaction.prefetch_if_necessary(resource)

          expect(transaction.prefetch_failed_providers[:sshkey][:parsed]).to be_truthy
        end

        describe "and new resources are generated" do
          let(:generator) { Puppet::Type.type(:notify).new :title => "generator" }
          let(:generated) do
            %w[a b c].map { |name| Puppet::Type.type(:sshkey).new :title => "foo", :name => name, :type => :dsa, :key => "eh", :provider => :parsed }
          end

          before :each do
            catalog.add_resource generator
            generator.stubs(:generate).returns generated
            catalog.stubs(:container_of).returns generator
          end

          it "should not evaluate resources with a failed provider, even if the prefetch is rescued" do
            #Only the generator resource should be applied, all the other resources are failed, and skipped.
            catalog.remove_resource resource2
            transaction.expects(:apply).once

            transaction.evaluate
          end

          it "should not fail other resources added after the failing resource" do
            new_resource = Puppet::Type.type(:notify).new :name => "baz"
            catalog.add_resource(new_resource)

            transaction.evaluate

            expect(transaction.resource_status(new_resource).failed?).to be_falsey
          end

          it "should fail other resources that require the failing resource" do
            new_resource = Puppet::Type.type(:notify).new(:name => "baz", :require => resource)
            catalog.add_resource(new_resource)

            catalog.remove_resource resource2
            transaction.expects(:apply).once

            transaction.evaluate

            expect(transaction.resource_status(resource).failed?).to be_truthy
            expect(transaction.resource_status(new_resource).dependency_failed?).to be_truthy
            expect(transaction.skip?(new_resource)).to be_truthy
          end
        end
      end
    end
  end

  describe "during teardown" do
    let(:catalog) { Puppet::Resource::Catalog.new }
    let(:transaction) do
      Puppet::Transaction.new(catalog, nil, Puppet::Graph::RandomPrioritizer.new)
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
      resource.stubs(:retrieve_resource).raises
      catalog.add_resource resource

      resource.provider.class.expects(:post_resource_eval)

      transaction.evaluate
    end
  end

  describe 'when checking application run state' do
    before do
      @catalog = Puppet::Resource::Catalog.new
      @transaction = Puppet::Transaction.new(@catalog, nil, Puppet::Graph::RandomPrioritizer.new)
    end

    context "when stop is requested" do
      before :each do
        Puppet::Application.stubs(:stop_requested?).returns(true)
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
      Puppet::Application.stubs(:stop_requested?).returns(false)
      expect(@transaction.stop_processing?).to be_falsey
    end

    describe 'within an evaluate call' do
      before do
        @resource = Puppet::Type.type(:notify).new :title => "foobar"
        @catalog.add_resource @resource
        @transaction.stubs(:add_dynamically_generated_resources)
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

  it "errors with a dependency cycle for a resource that requires itself" do
    Puppet.expects(:err).with(regexp_matches(/Found 1 dependency cycle:.*\(Notify\[cycle\] => Notify\[cycle\]\)/m))
    expect do
      apply_compiled_manifest(<<-MANIFEST)
        notify { cycle: require => Notify[cycle] }
      MANIFEST
    end.to raise_error(Puppet::Error, 'One or more resource dependency cycles detected in graph')
  end

  it "errors with a dependency cycle for a self-requiring resource also required by another resource" do
    Puppet.expects(:err).with(regexp_matches(/Found 1 dependency cycle:.*\(Notify\[cycle\] => Notify\[cycle\]\)/m))
    expect do
      apply_compiled_manifest(<<-MANIFEST)
        notify { cycle: require => Notify[cycle] }
        notify { other: require => Notify[cycle] }
      MANIFEST
    end.to raise_error(Puppet::Error, 'One or more resource dependency cycles detected in graph')
  end

  it "errors with a dependency cycle for a resource that requires itself and another resource" do
    Puppet.expects(:err).with(regexp_matches(/Found 1 dependency cycle:.*\(Notify\[cycle\] => Notify\[cycle\]\)/m))
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
    Puppet.expects(:err).with(regexp_matches(/Found 1 dependency cycle:.*\(Notify\[cycle\] => Notify\[cycle\]\)/m))
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
