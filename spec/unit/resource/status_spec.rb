#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/resource/status'

describe Puppet::Resource::Status do
  include PuppetSpec::Files

  let(:resource) { Puppet::Type.type(:file).new(:path => make_absolute("/my/file")) }
  let(:containment_path) { ["foo", "bar", "baz"] }
  let(:status) { Puppet::Resource::Status.new(resource) }

  before do
    resource.stubs(:pathbuilder).returns(containment_path)
  end

  it "should compute type and title correctly" do
    expect(status.resource_type).to eq("File")
    expect(status.title).to eq(make_absolute("/my/file"))
  end

  [:file, :line, :evaluation_time].each do |attr|
    it "should support #{attr}" do
      status.send(attr.to_s + "=", "foo")
      expect(status.send(attr)).to eq("foo")
    end
  end

  [:skipped, :failed, :restarted, :failed_to_restart, :changed, :out_of_sync, :scheduled].each do |attr|
    it "should support #{attr}" do
      status.send(attr.to_s + "=", "foo")
      expect(status.send(attr)).to eq("foo")
    end

    it "should have a boolean method for determining whether it was #{attr}" do
      status.send(attr.to_s + "=", "foo")
      expect(status).to send("be_#{attr}")
    end
  end

  it "should accept a resource at initialization" do
    expect(Puppet::Resource::Status.new(resource).resource).not_to be_nil
  end

  it "should set its source description to the resource's path" do
    resource.expects(:path).returns "/my/path"
    expect(Puppet::Resource::Status.new(resource).source_description).to eq("/my/path")
  end

  it "should set its containment path" do
  expect(Puppet::Resource::Status.new(resource).containment_path).to eq(containment_path)
  end

  [:file, :line].each do |attr|
    it "should copy the resource's #{attr}" do
      resource.expects(attr).returns "foo"
      expect(Puppet::Resource::Status.new(resource).send(attr)).to eq("foo")
    end
  end

  it "should copy the resource's tags" do
    resource.tag('foo', 'bar')
    status = Puppet::Resource::Status.new(resource)
    expect(status).to be_tagged("foo")
    expect(status).to be_tagged("bar")
  end

  it "should always convert the resource to a string" do
    resource.expects(:to_s).returns "foo"
    expect(Puppet::Resource::Status.new(resource).resource).to eq("foo")
  end

  it 'should set the provider_used correctly' do
    expected_name = if Puppet::Util::Platform.windows?
                      'windows'
                    else
                      'posix'
                    end
    expect(status.provider_used).to eq(expected_name)
  end

  it "should support tags" do
    expect(Puppet::Resource::Status.ancestors).to include(Puppet::Util::Tagging)
  end

  it "should create a timestamp at its creation time" do
    expect(status.time).to be_instance_of(Time)
  end

  it "should support adding events" do
    event = Puppet::Transaction::Event.new(:name => :foobar)
    status.add_event(event)
    expect(status.events).to eq([event])
  end

  it "should use '<<' to add events" do
    event = Puppet::Transaction::Event.new(:name => :foobar)
    expect(status << event).to equal(status)
    expect(status.events).to eq([event])
  end

  it "fails and records a failure event with a given message" do
    status.fail_with_event("foo fail")
    event = status.events[0]

    expect(event.message).to eq("foo fail")
    expect(event.status).to eq("failure")
    expect(event.name).to eq(:resource_error)
    expect(status.failed?).to be_truthy
  end

  it "fails and records a failure event with a given exception" do
    error = StandardError.new("the message")
    resource.expects(:log_exception).with(error, "Could not evaluate: the message")
    status.expects(:fail_with_event).with("the message")

    status.failed_because(error)
  end

  it "should count the number of successful events and set changed" do
    3.times{ status << Puppet::Transaction::Event.new(:status => 'success') }
    expect(status.change_count).to eq(3)

    expect(status.changed).to eq(true)
    expect(status.out_of_sync).to eq(true)
  end

  it "should not start with any changes" do
    expect(status.change_count).to eq(0)

    expect(status.changed).to eq(false)
    expect(status.out_of_sync).to eq(false)
  end

  it "should not treat failure, audit, or noop events as changed" do
    ['failure', 'audit', 'noop'].each do |s| status << Puppet::Transaction::Event.new(:status => s) end
    expect(status.change_count).to eq(0)
    expect(status.changed).to eq(false)
  end

  it "should not treat audit events as out of sync" do
    status << Puppet::Transaction::Event.new(:status => 'audit')
    expect(status.out_of_sync_count).to eq(0)
    expect(status.out_of_sync).to eq(false)
  end

  ['failure', 'noop', 'success'].each do |event_status|
    it "should treat #{event_status} events as out of sync" do
      3.times do status << Puppet::Transaction::Event.new(:status => event_status) end
      expect(status.out_of_sync_count).to eq(3)
      expect(status.out_of_sync).to eq(true)
    end
  end

  context 'when serializing' do
    let(:status) do
      s = Puppet::Resource::Status.new(resource)
      s.file = '/foo.rb'
      s.line = 27
      s.evaluation_time = 2.7
      s.tags = %w{one two}
      s << Puppet::Transaction::Event.new(:name => :mode_changed, :status => 'audit')
      s.failed = false
      s.changed = true
      s.out_of_sync = true
      s.skipped = false
      s.provider_used = 'provider_used_class_name'
      s
    end

    it 'should round trip through json' do
      expect(status.containment_path).to eq(containment_path)

      tripped = Puppet::Resource::Status.from_data_hash(JSON.parse(status.to_json))

      expect(tripped.title).to eq(status.title)
      expect(tripped.containment_path).to eq(status.containment_path)
      expect(tripped.file).to eq(status.file)
      expect(tripped.line).to eq(status.line)
      expect(tripped.resource).to eq(status.resource)
      expect(tripped.resource_type).to eq(status.resource_type)
      expect(tripped.provider_used).to eq(status.provider_used)
      expect(tripped.evaluation_time).to eq(status.evaluation_time)
      expect(tripped.tags).to eq(status.tags)
      expect(tripped.time).to eq(status.time)
      expect(tripped.failed).to eq(status.failed)
      expect(tripped.changed).to eq(status.changed)
      expect(tripped.out_of_sync).to eq(status.out_of_sync)
      expect(tripped.skipped).to eq(status.skipped)

      expect(tripped.change_count).to eq(status.change_count)
      expect(tripped.out_of_sync_count).to eq(status.out_of_sync_count)
      expect(events_as_hashes(tripped)).to eq(events_as_hashes(status))
    end

    it 'to_data_hash returns value that is instance of to Data' do
      expect(Puppet::Pops::Types::TypeFactory.data.instance?(status.to_data_hash)).to be_truthy
    end

    def events_as_hashes(report)
      report.events.collect do |e|
        {
          :audited => e.audited,
          :property => e.property,
          :previous_value => e.previous_value,
          :desired_value => e.desired_value,
          :historical_value => e.historical_value,
          :message => e.message,
          :name => e.name,
          :status => e.status,
          :time => e.time,
        }
      end
    end
  end
end
