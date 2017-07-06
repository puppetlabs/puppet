#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/transaction/event'

class TestResource
  def to_s
    "Foo[bar]"
  end
  def [](v)
    nil
  end
end

describe Puppet::Transaction::Event do
  include PuppetSpec::Files

  it "should support resource" do
    event = Puppet::Transaction::Event.new
    event.resource = TestResource.new
    expect(event.resource).to eq("Foo[bar]")
  end

  it "should always convert the property to a string" do
    expect(Puppet::Transaction::Event.new(:property => :foo).property).to eq("foo")
  end

  it "should always convert the resource to a string" do
    expect(Puppet::Transaction::Event.new(:resource => TestResource.new).resource).to eq("Foo[bar]")
  end

  it "should produce the message when converted to a string" do
    event = Puppet::Transaction::Event.new
    event.expects(:message).returns "my message"
    expect(event.to_s).to eq("my message")
  end

  it "should support 'status'" do
    event = Puppet::Transaction::Event.new
    event.status = "success"
    expect(event.status).to eq("success")
  end

  it "should fail if the status is not to 'audit', 'noop', 'success', or 'failure" do
    event = Puppet::Transaction::Event.new
    expect { event.status = "foo" }.to raise_error(ArgumentError)
  end

  it "should support tags" do
    expect(Puppet::Transaction::Event.ancestors).to include(Puppet::Util::Tagging)
  end

  it "should create a timestamp at its creation time" do
    expect(Puppet::Transaction::Event.new.time).to be_instance_of(Time)
  end

  describe "audit property" do
    it "should default to false" do
      expect(Puppet::Transaction::Event.new.audited).to eq(false)
    end
  end

  describe "when sending logs" do
    before do
      Puppet::Util::Log.stubs(:new)
    end

    it "should set the level to the resources's log level if the event status is 'success' and a resource is available" do
      resource = stub 'resource'
      resource.expects(:[]).with(:loglevel).returns :myloglevel
      Puppet::Util::Log.expects(:create).with { |args| args[:level] == :myloglevel }
      Puppet::Transaction::Event.new(:status => "success", :resource => resource).send_log
    end

    it "should set the level to 'notice' if the event status is 'success' and no resource is available" do
      Puppet::Util::Log.expects(:new).with { |args| args[:level] == :notice }
      Puppet::Transaction::Event.new(:status => "success").send_log
    end

    it "should set the level to 'notice' if the event status is 'noop'" do
      Puppet::Util::Log.expects(:new).with { |args| args[:level] == :notice }
      Puppet::Transaction::Event.new(:status => "noop").send_log
    end

    it "should set the level to 'err' if the event status is 'failure'" do
      Puppet::Util::Log.expects(:new).with { |args| args[:level] == :err }
      Puppet::Transaction::Event.new(:status => "failure").send_log
    end

    it "should set the 'message' to the event log" do
      Puppet::Util::Log.expects(:new).with { |args| args[:message] == "my message" }
      Puppet::Transaction::Event.new(:message => "my message").send_log
    end

    it "should set the tags to the event tags" do
      Puppet::Util::Log.expects(:new).with { |args| expect(args[:tags].to_a).to match_array(%w{one two}) }
      Puppet::Transaction::Event.new(:tags => %w{one two}).send_log
    end

    [:file, :line].each do |attr|
      it "should pass the #{attr}" do
        Puppet::Util::Log.expects(:new).with { |args| args[attr] == "my val" }
        Puppet::Transaction::Event.new(attr => "my val").send_log
      end
    end

    it "should use the source description as the source if one is set" do
      Puppet::Util::Log.expects(:new).with { |args| args[:source] == "/my/param" }
      Puppet::Transaction::Event.new(:source_description => "/my/param", :resource => TestResource.new, :property => "foo").send_log
    end

    it "should use the property as the source if one is available and no source description is set" do
      Puppet::Util::Log.expects(:new).with { |args| args[:source] == "foo" }
      Puppet::Transaction::Event.new(:resource => TestResource.new, :property => "foo").send_log
    end

    it "should use the property as the source if one is available and no property or source description is set" do
      Puppet::Util::Log.expects(:new).with { |args| args[:source] == "Foo[bar]" }
      Puppet::Transaction::Event.new(:resource => TestResource.new).send_log
    end
  end

  describe "When converting to YAML" do
    let(:resource) { Puppet::Type.type(:file).new(:title => make_absolute('/tmp/foo')) }
    let(:event) do
      Puppet::Transaction::Event.new(:source_description => "/my/param", :resource => resource,
        :file => "/foo.rb", :line => 27, :tags => %w{one two},
        :desired_value => 7, :historical_value => 'Brazil',
        :message => "Help I'm trapped in a spec test",
        :name => :mode_changed, :previous_value => 6, :property => :mode,
        :status => 'success',
        :redacted => false,
        :corrective_change => false)
    end

    it 'to_data_hash returns value that is instance of to Data' do
      expect(Puppet::Pops::Types::TypeFactory.data.instance?(event.to_data_hash)).to be_truthy
    end
  end

  it "should round trip through json" do
      resource = Puppet::Type.type(:file).new(:title => make_absolute("/tmp/foo"))
      event = Puppet::Transaction::Event.new(
        :source_description => "/my/param",
        :resource => resource,
        :file => "/foo.rb",
        :line => 27,
        :tags => %w{one two},
        :desired_value => 7,
        :historical_value => 'Brazil',
        :message => "Help I'm trapped in a spec test",
        :name => :mode_changed,
        :previous_value => 6,
        :property => :mode,
        :status => 'success')

      tripped = Puppet::Transaction::Event.from_data_hash(JSON.parse(event.to_json))

      expect(tripped.audited).to eq(event.audited)
      expect(tripped.property).to eq(event.property)
      expect(tripped.previous_value).to eq(event.previous_value)
      expect(tripped.desired_value).to eq(event.desired_value)
      expect(tripped.historical_value).to eq(event.historical_value)
      expect(tripped.message).to eq(event.message)
      expect(tripped.name).to eq(event.name)
      expect(tripped.status).to eq(event.status)
      expect(tripped.time).to eq(event.time)
  end

  it "should round trip an event for an inspect report through json" do
      resource = Puppet::Type.type(:file).new(:title => make_absolute("/tmp/foo"))
      event = Puppet::Transaction::Event.new(
        :audited => true,
        :source_description => "/my/param",
        :resource => resource,
        :file => "/foo.rb",
        :line => 27,
        :tags => %w{one two},
        :message => "Help I'm trapped in a spec test",
        :previous_value => 6,
        :property => :mode,
        :status => 'success')

      tripped = Puppet::Transaction::Event.from_data_hash(JSON.parse(event.to_json))

      expect(tripped.desired_value).to be_nil
      expect(tripped.historical_value).to be_nil
      expect(tripped.name).to be_nil

      expect(tripped.audited).to eq(event.audited)
      expect(tripped.property).to eq(event.property)
      expect(tripped.previous_value).to eq(event.previous_value)
      expect(tripped.message).to eq(event.message)
      expect(tripped.status).to eq(event.status)
      expect(tripped.time).to eq(event.time)
  end
end
