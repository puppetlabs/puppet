#!/usr/bin/env ruby

require 'spec_helper'

require 'puppet/util/windows'

describe Puppet::Util::Windows::EventLog, :if => Puppet.features.microsoft_windows? do

  before(:each) { @event_log = Puppet::Util::Windows::EventLog.new }
  after(:each) { @event_log.close }

  describe "class constants" do
    it "should define NULL_HANDLE as 0" do
      expect(Puppet::Util::Windows::EventLog::NULL_HANDLE).to eq(0)
    end

    it "should define WIN32_FALSE as 0" do
      expect(Puppet::Util::Windows::EventLog::WIN32_FALSE).to eq(0)
    end
  end

  describe "self.open" do
    it "sets a handle to the event log" do
      default_name = Puppet::Util::Windows::String.wide_string('Puppet')
      # return nil explicitly just to reinforce that we're not leaking eventlog handle
      Puppet::Util::Windows::EventLog.any_instance.expects(:RegisterEventSourceW).with(nil, default_name).returns(nil)
      Puppet::Util::Windows::EventLog.new
    end

    context "when it fails to open the event log" do
      before do
        # RegisterEventSourceW will return NULL on failure
        # Stubbing prevents leaking eventlog handle
        Puppet::Util::Windows::EventLog.any_instance.stubs(:RegisterEventSourceW).returns(Puppet::Util::Windows::EventLog::NULL_HANDLE)
      end

      it "raises an exception warning that the event log failed to open" do
        expect { Puppet::Util::Windows::EventLog.open('foo') }.to raise_error(Puppet::Util::Windows::EventLog::EventLogError, /failed to open Windows eventlog/)
      end

      it "passes the exit code to the exception constructor" do
        fake_error = Puppet::Util::Windows::EventLog::EventLogError.new('foo', 87)
        FFI.stubs(:errno).returns(87)
        # All we're testing here is that the constructor actually receives the exit code from FFI.errno (87)
        # We do so because `expect to...raise_error` doesn't support multiple parameter match arguments
        # We return fake_error just because `raise` expects an exception class
        Puppet::Util::Windows::EventLog::EventLogError.expects(:new).with(regexp_matches(/failed to open Windows eventlog/), 87).returns(fake_error)
        expect { Puppet::Util::Windows::EventLog.open('foo') }.to raise_error(Puppet::Util::Windows::EventLog::EventLogError)
      end
    end
  end

  describe "#close" do
    it "closes the handle to the event log" do
      @handle = "12345"
      Puppet::Util::Windows::EventLog.any_instance.stubs(:RegisterEventSourceW).returns(@handle)
      event_log = Puppet::Util::Windows::EventLog.new
      event_log.expects(:DeregisterEventSource).with(@handle).returns(1)
      event_log.close
    end
  end

  describe "#report_event" do
    it "raises an exception if the message passed is not a string" do
      expect { @event_log.report_event(:data => 123, :event_type => nil, :event_id => nil) }.to raise_error(ArgumentError, /data must be a string/)
    end

    context "when an event report fails" do
      before do
        # ReportEventW returns 0 on failure, which is mapped to WIN32_FALSE
        @event_log.stubs(:ReportEventW).returns(Puppet::Util::Windows::EventLog::WIN32_FALSE)
      end

      it "raises an exception warning that the event report failed" do
        expect { @event_log.report_event(:data => 'foo', :event_type => Puppet::Util::Windows::EventLog::EVENTLOG_ERROR_TYPE, :event_id => 0x03) }.to raise_error(Puppet::Util::Windows::EventLog::EventLogError, /failed to report event/)
      end

      it "passes the exit code to the exception constructor" do
        fake_error = Puppet::Util::Windows::EventLog::EventLogError.new('foo', 5)
        FFI.stubs(:errno).returns(5)
        # All we're testing here is that the constructor actually receives the exit code from FFI.errno (5)
        # We do so because `expect to...raise_error` doesn't support multiple parameter match arguments
        # We return fake_error just because `raise` expects an exception class
        Puppet::Util::Windows::EventLog::EventLogError.expects(:new).with(regexp_matches(/failed to report event/), 5).returns(fake_error)
        expect { @event_log.report_event(:data => 'foo', :event_type => Puppet::Util::Windows::EventLog::EVENTLOG_ERROR_TYPE, :event_id => 0x03) }.to raise_error(Puppet::Util::Windows::EventLog::EventLogError)
      end
    end
  end

  describe "self.to_native" do

    it "raises an exception if the log level is not supported" do
      expect { Puppet::Util::Windows::EventLog.to_native(:foo) }.to raise_error(ArgumentError)
    end

    # This is effectively duplicating the data assigned to the constants in
    # Puppet::Util::Windows::EventLog but since these are public constants we
    # ensure their values don't change lightly.
    log_levels_to_type_and_id = {
      :debug    => [0x0004, 0x01],
      :info     => [0x0004, 0x01],
      :notice   => [0x0004, 0x01],
      :warning  => [0x0002, 0x02],
      :err      => [0x0001, 0x03],
      :alert    => [0x0001, 0x03],
      :emerg    => [0x0001, 0x03],
      :crit     => [0x0001, 0x03],
    }

    shared_examples_for "#to_native" do |level|
      it "should return the correct INFORMATION_TYPE and ID" do
        result = Puppet::Util::Windows::EventLog.to_native(level)
        expect(result).to eq(log_levels_to_type_and_id[level])
      end
    end

    log_levels_to_type_and_id.each_key do |level|
      describe "logging at #{level}" do
        it_should_behave_like "#to_native", level
      end
    end
  end
end
