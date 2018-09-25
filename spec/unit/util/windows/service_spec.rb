#!/usr/bin/env ruby
require 'spec_helper'

describe "Puppet::Util::Windows::Service", :if => Puppet.features.microsoft_windows? do
  require 'puppet/util/windows'

  # The following should emulate a successful call to the private function
  # query_status that returns the value of query_return. This should give
  # us a way to mock changes in service status.
  #
  # Everything else is stubbed, the emulation of the successful call is really
  # just an expectation of subject::SERVICE_STATUS_PROCESS.new in sequence that
  # returns the value passed in as a param
  def expect_successful_status_query_and_return(query_return)
    subject::SERVICE_STATUS_PROCESS.expects(:new).in_sequence(status_checks).returns(query_return)
  end

  # The following should emulate a successful call to the private function
  # query_config that returns the value of query_return. This should give
  # us a way to mock changes in service configuration.
  #
  # Everything else is stubbed, the emulation of the successful call is really
  # just an expectation of subject::QUERY_SERVICE_CONFIGW.new in sequence that
  # returns the value passed in as a param
  def expect_successful_config_query_and_return(query_return)
    subject::QUERY_SERVICE_CONFIGW.expects(:new).in_sequence(status_checks).returns(query_return)
  end

  let(:subject)      { Puppet::Util::Windows::Service }
  let(:pointer) { mock() }
  let(:status_checks) { sequence('status_checks') }
  let(:mock_service_name) { mock() }
  let(:service) { mock() }
  let(:scm) { mock() }

  before do
    subject.stubs(:QueryServiceStatusEx).returns(1)
    subject.stubs(:QueryServiceConfigW).returns(1)
    subject.stubs(:StartServiceW).returns(1)
    subject.stubs(:ControlService).returns(1)
    subject.stubs(:ChangeServiceConfigW).returns(1)
    subject.stubs(:OpenSCManagerW).returns(scm)
    subject.stubs(:OpenServiceW).returns(service)
    subject.stubs(:CloseServiceHandle)
    subject.stubs(:EnumServicesStatusExW).returns(1)
    subject.stubs(:wide_string)
    subject::SERVICE_STATUS_PROCESS.stubs(:new)
    subject::QUERY_SERVICE_CONFIGW.stubs(:new)
    subject::SERVICE_STATUS.stubs(:new).returns({:dwCurrentState => subject::SERVICE_RUNNING})
    Puppet::Util::Windows::Error.stubs(:new).raises(Puppet::Error.new('fake error'))
    FFI::MemoryPointer.stubs(:new).yields(pointer)
    pointer.stubs(:read_dword)
    pointer.stubs(:write_dword)
    pointer.stubs(:size)
    subject.stubs(:sleep)
  end

  describe "#start" do

    context "when the service control manager cannot be opened" do
      let(:scm) { FFI::Pointer::NULL_HANDLE }
      it "raises a puppet error" do
        expect{ subject.start(mock_service_name) }.to raise_error(Puppet::Error)
      end
    end

    context "when the service cannot be opened" do
      let(:service) { FFI::Pointer::NULL_HANDLE }
      it "raises a puppet error" do
        expect{ subject.start(mock_service_name) }.to raise_error(Puppet::Error)
      end
    end

    context "when the service can be opened and is in the stopped state" do
      before do
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOPPED})
      end

      it "Starts the service once the service reports SERVICE_RUNNING" do
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING})
        subject.start(mock_service_name)
      end

      it "Raises an error if after calling StartServiceW the service never transitions to RUNNING or START_PENDING" do
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_PAUSED}).times(31)
        expect{ subject.start(mock_service_name) }.to raise_error(Puppet::Error)
      end

      it "raises a puppet error if StartServiceW returns false" do
        subject.expects(:StartServiceW).returns(FFI::WIN32_FALSE)
        expect{ subject.start(mock_service_name) }.to raise_error(Puppet::Error)
      end
    end

    context "when the service hasn't stopped yet:" do
      it "waits, then queries again until SERVICE_STOPPED" do
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 30000, :dwCheckPoint => 1})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 30000, :dwCheckPoint => 1})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 30000, :dwCheckPoint => 50})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOPPED})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING})
        subject.expects(:sleep).with(3).twice
        subject.start(mock_service_name)
      end

      it "waits for at least 1 second if wait hint/10 is < 1 second" do
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 30000, :dwCheckPoint => 1})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 0, :dwCheckPoint => 1})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOPPED})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING})
        subject.expects(:sleep).with(1)
        subject.start(mock_service_name)
      end

      it "waits for at most 10 seconds if wait hint/10 is > 10 seconds" do
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 30000, :dwCheckPoint => 1})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 1000000, :dwCheckPoint => 1})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOPPED})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING})
        subject.expects(:sleep).with(10)
        subject.start(mock_service_name)
      end

      it "raises a puppet error if the service query fails" do
        subject.expects(:QueryServiceStatusEx).in_sequence(status_checks).returns(1)
        subject.expects(:QueryServiceStatusEx).in_sequence(status_checks).returns(FFI::WIN32_FALSE)
        expect{subject.start(mock_service_name)}.to raise_error(Puppet::Error)
      end

      it "Does not raise an error if the service makes progress" do
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 0, :dwCheckPoint => 0})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 0, :dwCheckPoint => 0})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 0, :dwCheckPoint => 2})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 0, :dwCheckPoint => 30})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 0, :dwCheckPoint => 50})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 0, :dwCheckPoint => 98})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOPPED})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING})
        expect{subject.start(mock_service_name)}.to_not raise_error
      end
    end

    context "when the service ends up still in STOPPED:" do
      it "waits, then queries again until RUNNING" do
        # these will be before the call to controlService
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOPPED})
        # everything from here on will be _after_ the call to ControlService
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOPPED})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_START_PENDING, :dwWaitHint => 30000, :dwCheckPoint => 1})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_START_PENDING, :dwWaitHint => 30000, :dwCheckPoint => 50})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING})
        subject.start(mock_service_name)
      end

      it "raises a puppet error if the services never exits the RUNNING state" do
        # these will be before the call to controlService
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOPPED})
        # the number of times here is a little strange: there are 31 status queries sleeps because there will be a 31st query
        # that is the final query where the command has reached the wait hint and it's time to error
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOPPED}).times(31)
        subject.expects(:sleep).times(30).with(1)
        expect{subject.start(mock_service_name)}.to raise_error(Puppet::Error)
      end
    end

    context "when the service ends up in START_PENDING:" do
      before(:each) do
        # these will be before the call to StartService
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOPPED})
      end

      it "waits, then queries again until SERVICE_RUNNING" do
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_START_PENDING, :dwWaitHint => 30000, :dwCheckPoint => 1})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_START_PENDING, :dwWaitHint => 30000, :dwCheckPoint => 50})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING})
        subject.start(mock_service_name)
      end

      it "waits for at least 1 second if wait hint/10 is < 1 second" do
        # the first call is executed in wait_for_state, which we aren't testing here
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_START_PENDING})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_START_PENDING, :dwWaitHint => 0, :dwCheckPoint => 2})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING})
        subject.expects(:sleep).with(1)
        subject.start(mock_service_name)
      end

      it "waits for at most 10 seconds if wait hint/10 is > 10 seconds" do
        # the first call is executed in wait_for_state, which we aren't testing here
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_START_PENDING})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_START_PENDING, :dwWaitHint => 1000000, :dwCheckPoint => 1})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING})
        subject.expects(:sleep).with(10)
        subject.start(mock_service_name)
      end

      it "raises a puppet error if the services configured dwWaitHint is 0, 30 seconds have passed and dwCheckPoint hasn't increased" do
        # the first call is executed in wait_for_state, which we aren't testing here
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_START_PENDING})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_START_PENDING, :dwWaitHint => 0, :dwCheckPoint => 0}).times(31)
        subject.expects(:sleep).times(30).with(1)
        expect{subject.start(mock_service_name)}.to raise_error(Puppet::Error)
      end

      it "raises a puppet error if the service's configured dwWaitHint has passed and dwCheckPoint hasn't increased" do
        # the first call is executed in wait_for_state, which we aren't testing here
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_START_PENDING})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_START_PENDING, :dwWaitHint => 40000, :dwCheckPoint => 0}).times(11)
        subject.expects(:sleep).times(10).with(4)
        expect{subject.start(mock_service_name)}.to raise_error(Puppet::Error)
      end

      it "Does not raise an error if the service makes progress" do
        # the first call is executed in wait_for_state, which we aren't testing here
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_START_PENDING})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_START_PENDING, :dwWaitHint => 0, :dwCheckPoint => 0})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_START_PENDING, :dwWaitHint => 0, :dwCheckPoint => 2})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_START_PENDING, :dwWaitHint => 0, :dwCheckPoint => 30})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_START_PENDING, :dwWaitHint => 0, :dwCheckPoint => 50})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_START_PENDING, :dwWaitHint => 0, :dwCheckPoint => 98})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING})
        subject.expects(:sleep).times(5).with(1)
        expect{subject.start(mock_service_name)}.to_not raise_error
      end
    end
  end

  describe "#stop" do
    context "when the service control manager cannot be opened" do
      let(:scm) { FFI::Pointer::NULL_HANDLE }
      it "raises a puppet error" do
        expect{ subject.stop(mock_service_name) }.to raise_error(Puppet::Error)
      end
    end

    context "when the service cannot be opened" do
      let(:service) { FFI::Pointer::NULL_HANDLE }
      it "raises a puppet error" do
        expect{ subject.stop(mock_service_name) }.to raise_error(Puppet::Error)
      end
    end

    context "when the service can be opened and is in the running state:" do
      before do
        # this will be before the call to controlService
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING})
      end
      it "raises a puppet error if ControlService returns false" do
        subject.expects(:ControlService).returns(FFI::WIN32_FALSE)
        expect{ subject.stop(mock_service_name) }.to raise_error(Puppet::Error)
      end
    end

    # No need to retest the wait hint functionality itself here, since
    # both stop and start use the wait_for_pending_transition helper
    # which is tested in the start unit tests.
    context "when the service is already in stop pending or stopped" do
      it "waits for the service to stop and then exits immediately" do
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 30000, :dwCheckPoint => 1})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 30000, :dwCheckPoint => 5})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOPPED})
        subject.stop(mock_service_name)
      end
    end

    context "when the service ends up in STOP_PENDING:" do
      before(:each) do
        # this will be before the call to controlService
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING})
      end

      it "waits, then queries again until SERVICE_STOPPED" do
        # the first call is to wait_for_state, which we don't test here
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING})
        # everything from here on will be _after_ the call to ControlService
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 30000, :dwCheckPoint => 1})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 30000, :dwCheckPoint => 50})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOPPED})
        subject.stop(mock_service_name)
      end

      it "raises a puppet error if the services never exits the STOP_PENDING state" do
        # the first call is to wait_for_state, which we don't test here
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 0, :dwCheckPoint => 0}).times(31)
        expect{subject.stop(mock_service_name)}.to raise_error(Puppet::Error)
      end
    end

    context "when the service ends up still in RUNNING:" do
      before(:each) do
        # this will be before the call to controlService
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING})
      end
      it "waits, then queries again until SERVICE_STOPPED" do
        # the first call is to wait_for_state, which we don't test here
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING, :dwWaitHint => 0, :dwCheckPoint => 0}).times(10)
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 30000, :dwCheckPoint => 1})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOP_PENDING, :dwWaitHint => 30000, :dwCheckPoint => 50})
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_STOPPED})
        subject.stop(mock_service_name)
      end

      it "raises a puppet error if the services never exits the RUNNING state" do
        # the first call is to wait_for_state, which we don't test here
        expect_successful_status_query_and_return({:dwCurrentState => subject::SERVICE_RUNNING, :dwWaitHint => 0, :dwCheckPoint => 0}).times(31)
        subject.expects(:sleep).times(30).with(1)
        expect{subject.stop(mock_service_name)}.to raise_error(Puppet::Error)
      end
    end
  end

  describe "#service_state" do
    context "when the service control manager cannot be opened" do
      let(:scm) { FFI::Pointer::NULL_HANDLE }
      it "raises a puppet error" do
        expect{ subject.service_state(mock_service_name) }.to raise_error(Puppet::Error)
      end
    end

    context "when the service cannot be opened" do
      let(:service) { FFI::Pointer::NULL_HANDLE }
      it "raises a puppet error" do
        expect{ subject.service_state(mock_service_name) }.to raise_error(Puppet::Error)
      end
    end

    context "when the service can be opened" do
      it "raises Puppet::Error if the result of the query is empty" do
        expect_successful_status_query_and_return({})
        expect{subject.service_state(mock_service_name)}.to raise_error(Puppet::Error)
      end

      it "raises Puppet::Error if the result of the query is an unknown state" do
        expect_successful_status_query_and_return({:dwCurrentState => 999})
        expect{subject.service_state(mock_service_name)}.to raise_error(Puppet::Error)
      end

      # We need to guard this section explicitly since rspec will always
      # construct all examples, even if it isn't going to run them.
      if Puppet.features.microsoft_windows?
        {
          :SERVICE_STOPPED => Puppet::Util::Windows::Service::SERVICE_STOPPED,
          :SERVICE_PAUSED => Puppet::Util::Windows::Service::SERVICE_PAUSED,
          :SERVICE_STOP_PENDING => Puppet::Util::Windows::Service::SERVICE_STOP_PENDING,
          :SERVICE_PAUSE_PENDING => Puppet::Util::Windows::Service::SERVICE_PAUSE_PENDING,
          :SERVICE_RUNNING => Puppet::Util::Windows::Service::SERVICE_RUNNING,
          :SERVICE_CONTINUE_PENDING => Puppet::Util::Windows::Service::SERVICE_CONTINUE_PENDING,
          :SERVICE_START_PENDING => Puppet::Util::Windows::Service::SERVICE_START_PENDING,
        }.each do |state_name, state|
          it "queries the service and returns #{state_name}" do
            expect_successful_status_query_and_return({:dwCurrentState => state})
            expect(subject.service_state(mock_service_name)).to eq(state_name)
          end
        end
      end
    end
  end

  describe "#service_start_type" do
    context "when the service control manager cannot be opened" do
      let(:scm) { FFI::Pointer::NULL_HANDLE }
      it "raises a puppet error" do
        expect{ subject.service_start_type(mock_service_name) }.to raise_error(Puppet::Error)
      end
    end

    context "when the service cannot be opened" do
      let(:service) { FFI::Pointer::NULL_HANDLE }
      it "raises a puppet error" do
        expect{ subject.service_start_type(mock_service_name) }.to raise_error(Puppet::Error)
      end
    end

    context "when the service can be opened" do

      # We need to guard this section explicitly since rspec will always
      # construct all examples, even if it isn't going to run them.
      if Puppet.features.microsoft_windows?
        {
          :SERVICE_AUTO_START => Puppet::Util::Windows::Service::SERVICE_AUTO_START,
          :SERVICE_BOOT_START => Puppet::Util::Windows::Service::SERVICE_BOOT_START,
          :SERVICE_SYSTEM_START => Puppet::Util::Windows::Service::SERVICE_SYSTEM_START,
          :SERVICE_DEMAND_START => Puppet::Util::Windows::Service::SERVICE_DEMAND_START,
          :SERVICE_DISABLED => Puppet::Util::Windows::Service::SERVICE_DISABLED,
        }.each do |start_type_name, start_type|
          it "queries the service and returns the service start type #{start_type_name}" do
            expect_successful_config_query_and_return({:dwStartType => start_type})
            expect(subject.service_start_type(mock_service_name)).to eq(start_type_name)
          end
        end
      end
      it "raises a puppet error if the service query fails" do
        subject.expects(:QueryServiceConfigW).in_sequence(status_checks)
        subject.expects(:QueryServiceConfigW).in_sequence(status_checks).returns(FFI::WIN32_FALSE)
        expect{ subject.service_start_type(mock_service_name) }.to raise_error(Puppet::Error)
      end
    end
  end

  describe "#set_startup_mode" do
    let(:status_checks) { sequence('status_checks') }

    context "when the service control manager cannot be opened" do
      let(:scm) { FFI::Pointer::NULL_HANDLE }
      it "raises a puppet error" do
        expect{ subject.set_startup_mode(mock_service_name, :SERVICE_DEMAND_START) }.to raise_error(Puppet::Error)
      end
    end

    context "when the service cannot be opened" do
      let(:service) { FFI::Pointer::NULL_HANDLE }
      it "raises a puppet error" do
        expect{ subject.set_startup_mode(mock_service_name, :SERVICE_DEMAND_START) }.to raise_error(Puppet::Error)
      end
    end

    context "when the service can be opened" do
      it "Raises an error on an unsuccessful change" do
        subject.expects(:ChangeServiceConfigW).returns(FFI::WIN32_FALSE)
        expect{ subject.set_startup_mode(mock_service_name, :SERVICE_DEMAND_START) }.to raise_error(Puppet::Error)
      end
    end
  end

  describe "#services" do
    let(:pointer_sequence) { sequence('pointer_sequence') }

    context "when the service control manager cannot be opened" do
      let(:scm) { FFI::Pointer::NULL_HANDLE }
      it "raises a puppet error" do
        expect{ subject.services }.to raise_error(Puppet::Error)
      end
    end

    context "when the service control manager is open" do
      let(:cursor) { [ 'svc1', 'svc2', 'svc3' ] }
      let(:svc1name_ptr) { mock() }
      let(:svc2name_ptr) { mock() }
      let(:svc3name_ptr) { mock() }
      let(:svc1displayname_ptr) { mock() }
      let(:svc2displayname_ptr) { mock() }
      let(:svc3displayname_ptr) { mock() }
      let(:svc1) { { :lpServiceName => svc1name_ptr, :lpDisplayName => svc1displayname_ptr, :ServiceStatusProcess => 'foo' } }
      let(:svc2) { { :lpServiceName => svc2name_ptr, :lpDisplayName => svc2displayname_ptr, :ServiceStatusProcess => 'foo' } }
      let(:svc3) { { :lpServiceName => svc3name_ptr, :lpDisplayName => svc3displayname_ptr, :ServiceStatusProcess => 'foo' } }

      it "Raises an error if EnumServicesStatusExW fails" do
        subject.expects(:EnumServicesStatusExW).in_sequence(pointer_sequence)
        subject.expects(:EnumServicesStatusExW).in_sequence(pointer_sequence).returns(FFI::WIN32_FALSE)
        expect{ subject.services }.to raise_error(Puppet::Error)
      end

      it "Reads the buffer using pointer arithmetic to create a hash of service entries" do
        # the first read_dword is for reading the bytes required, let that return 3 too.
        # the second read_dword will actually read the number of services returned
        pointer.expects(:read_dword).twice.returns(3)
        FFI::Pointer.expects(:new).with(subject::ENUM_SERVICE_STATUS_PROCESSW, pointer).returns(cursor)
        subject::ENUM_SERVICE_STATUS_PROCESSW.expects(:new).in_sequence(pointer_sequence).with('svc1').returns(svc1)
        subject::ENUM_SERVICE_STATUS_PROCESSW.expects(:new).in_sequence(pointer_sequence).with('svc2').returns(svc2)
        subject::ENUM_SERVICE_STATUS_PROCESSW.expects(:new).in_sequence(pointer_sequence).with('svc3').returns(svc3)
        svc1name_ptr.expects(:read_arbitrary_wide_string_up_to).returns('svc1')
        svc2name_ptr.expects(:read_arbitrary_wide_string_up_to).returns('svc2')
        svc3name_ptr.expects(:read_arbitrary_wide_string_up_to).returns('svc3')
        svc1displayname_ptr.expects(:read_arbitrary_wide_string_up_to).returns('service 1')
        svc2displayname_ptr.expects(:read_arbitrary_wide_string_up_to).returns('service 2')
        svc3displayname_ptr.expects(:read_arbitrary_wide_string_up_to).returns('service 3')
        expect(subject.services).to eq({
          'svc1' => { :display_name => 'service 1', :service_status_process => 'foo' },
          'svc2' => { :display_name => 'service 2', :service_status_process => 'foo' },
          'svc3' => { :display_name => 'service 3', :service_status_process => 'foo' }
        })
      end
    end
  end
end
