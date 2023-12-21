require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Windows',
    :if => Puppet::Util::Platform.windows? && !Puppet::Util::Platform.jruby? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:windows) }
  let(:name)     { 'nonexistentservice' }
  let(:resource) { Puppet::Type.type(:service).new(:name => name, :provider => :windows) }
  let(:provider) { resource.provider }
  let(:config)   { Struct::ServiceConfigInfo.new }
  let(:status)   { Struct::ServiceStatus.new }
  let(:service_util) { Puppet::Util::Windows::Service }
  let(:service_handle) { double() }

  before :each do
    # make sure we never actually execute anything (there are two execute methods)
    allow(provider.class).to receive(:execute)
    allow(provider).to receive(:execute)

    allow(service_util).to receive(:exists?).with(resource[:name]).and_return(true)
  end

  describe ".instances" do
    it "should enumerate all services" do
      list_of_services = {'snmptrap' => {}, 'svchost' => {}, 'sshd' => {}}
      expect(service_util).to receive(:services).and_return(list_of_services)

      expect(provider_class.instances.map(&:name)).to match_array(['snmptrap', 'svchost', 'sshd'])
    end
  end

  describe "#start" do
    before(:each) do
      allow(provider).to receive(:status).and_return(:stopped)
    end

    it "should resume a paused service" do
      allow(provider).to receive(:status).and_return(:paused)
      expect(service_util).to receive(:resume)
      provider.start
    end

    it "should start the service" do
      expect(service_util).to receive(:service_start_type).with(name).and_return(:SERVICE_AUTO_START)
      expect(service_util).to receive(:start)
      provider.start
    end

    context "when the service is disabled" do
      before :each do
        expect(service_util).to receive(:service_start_type).with(name).and_return(:SERVICE_DISABLED)
      end

      it "should refuse to start if not managing enable" do
        expect { provider.start }.to raise_error(Puppet::Error, /Will not start disabled service/)
      end

      it "should enable if managing enable and enable is true" do
        resource[:enable] = :true
        expect(service_util).to receive(:start)
        expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_AUTO_START})

        provider.start
      end

      it "should manual start if managing enable and enable is false" do
        resource[:enable] = :false
        expect(service_util).to receive(:start)
        expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_DEMAND_START})

        provider.start
      end
    end
  end

  describe "#stop" do
    it "should stop a running service" do
      expect(service_util).to receive(:stop)

      provider.stop
    end
  end

  describe "#status" do
    it "should report a nonexistent service as stopped" do
      allow(service_util).to receive(:exists?).with(resource[:name]).and_return(false)

      expect(provider.status).to eql(:stopped)
    end

    it "should report service as stopped when status cannot be retrieved" do
      allow(service_util).to receive(:exists?).with(resource[:name]).and_return(true)
      allow(service_util).to receive(:service_state).with(name).and_raise(Puppet::Error.new('Service query failed: The specified path is invalid.'))

      expect(Puppet).to receive(:warning).with("Status for service #{resource[:name]} could not be retrieved: Service query failed: The specified path is invalid.")
      expect(provider.status).to eql(:stopped)
    end

    [
      :SERVICE_PAUSED,
      :SERVICE_PAUSE_PENDING
    ].each do |state|
      it "should report a #{state} service as paused" do
        expect(service_util).to receive(:service_state).with(name).and_return(state)
        expect(provider.status).to eq(:paused)
      end
    end

    [
      :SERVICE_STOPPED,
      :SERVICE_STOP_PENDING
    ].each do |state|
      it "should report a #{state} service as stopped" do
        expect(service_util).to receive(:service_state).with(name).and_return(state)
        expect(provider.status).to eq(:stopped)
      end
    end

    [
      :SERVICE_RUNNING,
      :SERVICE_CONTINUE_PENDING,
      :SERVICE_START_PENDING,
    ].each do |state|
      it "should report a #{state} service as running" do
        expect(service_util).to receive(:service_state).with(name).and_return(state)

        expect(provider.status).to eq(:running)
      end
    end

    context 'when querying lmhosts', if: Puppet::Util::Platform.windows? do
      # This service should be ubiquitous across all supported Windows platforms
      let(:service) { Puppet::Type.type(:service).new(:name => 'lmhosts') }

      before :each do
        allow(service_util).to receive(:exists?).with(service.name).and_call_original
      end

      it "reports if the service is enabled" do
        expect([:true, :false, :manual]).to include(service.provider.enabled?)
      end

      it "reports on the service status" do
        expect(
          [
            :running,
            :'continue pending',
            :'pause pending',
            :paused,
            :running,
            :'start pending',
            :'stop pending',
            :stopped
          ]
        ).to include(service.provider.status)
      end
    end
  end

  describe "#restart" do
    it "should use the supplied restart command if specified" do
      resource[:restart] = 'c:/bin/foo'

      expect(provider).to receive(:execute).with(['c:/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)

      provider.restart
    end

    it "should restart the service" do
      expect(provider).to receive(:stop).ordered
      expect(provider).to receive(:start).ordered

      provider.restart
    end
  end

  describe "#enabled?" do
    it "should report a nonexistent service as false" do
      allow(service_util).to receive(:exists?).with(resource[:name]).and_return(false)

      expect(provider.enabled?).to eql(:false)
    end

    it "should report a service with a startup type of manual as manual" do
      expect(service_util).to receive(:service_start_type).with(name).and_return(:SERVICE_DEMAND_START)
      expect(provider.enabled?).to eq(:manual)
    end

    it "should report a service with a startup type of delayed as delayed" do
      expect(service_util).to receive(:service_start_type).with(name).and_return(:SERVICE_DELAYED_AUTO_START)
      expect(provider.enabled?).to eq(:delayed)
    end

    it "should report a service with a startup type of disabled as false" do
      expect(service_util).to receive(:service_start_type).with(name).and_return(:SERVICE_DISABLED)
      expect(provider.enabled?).to eq(:false)
    end

    # We need to guard this section explicitly since rspec will always
    # construct all examples, even if it isn't going to run them.
    if Puppet.features.microsoft_windows?
      [
        :SERVICE_AUTO_START,
        :SERVICE_BOOT_START,
        :SERVICE_SYSTEM_START
      ].each do |start_type|
        it "should report a service with a startup type of '#{start_type}' as true" do
          expect(service_util).to receive(:service_start_type).with(name).and_return(start_type)
          expect(provider.enabled?).to eq(:true)
        end
      end
    end
  end

  describe "#enable" do
    it "should set service start type to Service_Auto_Start when enabled" do
      expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_AUTO_START})
      provider.enable
    end

    it "raises an error if set_startup_configuration fails" do
      expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_AUTO_START}).and_raise(Puppet::Error.new('foobar'))

      expect {
        provider.enable
      }.to raise_error(Puppet::Error, /Cannot enable #{name}/)
    end
  end

  describe "#disable" do
    it "should set service start type to Service_Disabled when disabled" do
      expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_DISABLED})
      provider.disable
    end

    it "raises an error if set_startup_configuration fails" do
      expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_DISABLED}).and_raise(Puppet::Error.new('foobar'))

      expect {
        provider.disable
      }.to raise_error(Puppet::Error, /Cannot disable #{name}/)
    end
  end

  describe "#manual_start" do
    it "should set service start type to Service_Demand_Start (manual) when manual" do
      expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_DEMAND_START})
      provider.manual_start
    end

    it "raises an error if set_startup_configuration fails" do
      expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_DEMAND_START}).and_raise(Puppet::Error.new('foobar'))

      expect {
        provider.manual_start
      }.to raise_error(Puppet::Error, /Cannot enable #{name}/)
    end
  end

  describe "#delayed_start" do
    it "should set service start type to Service_Config_Delayed_Auto_Start (delayed) when delayed" do
      expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_AUTO_START, delayed: true})
      provider.delayed_start
    end

    it "raises an error if set_startup_configuration fails" do
      expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_AUTO_START, delayed: true}).and_raise(Puppet::Error.new('foobar'))

      expect {
        provider.delayed_start
      }.to raise_error(Puppet::Error, /Cannot enable #{name}/)
    end
  end

  describe "when managing logon credentials" do
    before do
      allow(Puppet::Util::Windows::ADSI).to receive(:computer_name).and_return(computer_name)
      allow(Puppet::Util::Windows::SID).to receive(:name_to_principal).and_return(principal)
      allow(Puppet::Util::Windows::Service).to receive(:set_startup_configuration).and_return(nil)
    end

    let(:computer_name) { 'myPC' }

    describe "#logonaccount=" do
      before do
        allow(Puppet::Util::Windows::User).to receive(:password_is?).and_return(true)
        resource[:logonaccount] = user_input
        provider.logonaccount_insync?(user_input)
      end

      let(:user_input) { principal.account }
      let(:principal) do
        Puppet::Util::Windows::SID::Principal.new("myUser", nil, nil, computer_name, :SidTypeUser)
      end

      context "when given user is 'myUser'" do
        it "should fail when the `Log On As A Service` right is missing from given user" do
          allow(Puppet::Util::Windows::User).to receive(:get_rights).with(principal.domain_account).and_return("")
          expect { provider.logonaccount=(user_input) }.to raise_error(Puppet::Error, /".\\#{principal.account}" is missing the 'Log On As A Service' right./)
        end

        it "should fail when the `Log On As A Service` right is set to denied for given user" do
          allow(Puppet::Util::Windows::User).to receive(:get_rights).with(principal.domain_account).and_return("SeDenyServiceLogonRight")
          expect { provider.logonaccount=(user_input) }.to raise_error(Puppet::Error, /".\\#{principal.account}" has the 'Log On As A Service' right set to denied./)
        end

        it "should not fail when given user has the `Log On As A Service` right" do
          allow(Puppet::Util::Windows::User).to receive(:get_rights).with(principal.domain_account).and_return("SeServiceLogonRight")
          expect { provider.logonaccount=(user_input) }.not_to raise_error
        end

        ['myUser', 'myPC\\myUser', ".\\myUser", "MYPC\\mYuseR"].each do |user_input_variant|
          let(:user_input) { user_input_variant }

          it "should succesfully munge #{user_input_variant} to '.\\myUser'" do
            allow(Puppet::Util::Windows::User).to receive(:get_rights).with(principal.domain_account).and_return("SeServiceLogonRight")
            expect { provider.logonaccount=(user_input) }.not_to raise_error
            expect(resource[:logonaccount]).to eq(".\\myUser")
          end
        end
      end

      context "when given user is a system account" do
        before do
          allow(Puppet::Util::Windows::User).to receive(:default_system_account?).and_return(true)
        end

        let(:user_input) { principal.account }
        let(:principal) do
          Puppet::Util::Windows::SID::Principal.new("LOCAL SERVICE", nil, nil, "NT AUTHORITY", :SidTypeUser)
        end

        it "should not fail when given user is a default system account even if the `Log On As A Service` right is missing" do
          expect(Puppet::Util::Windows::User).not_to receive(:get_rights)
          expect { provider.logonaccount=(user_input) }.not_to raise_error
        end

        ['LocalSystem', '.\LocalSystem', 'myPC\LocalSystem', 'lOcALsysTem'].each do |user_input_variant|
          let(:user_input) { user_input_variant }

          it "should succesfully munge #{user_input_variant} to 'LocalSystem'" do
            expect { provider.logonaccount=(user_input) }.not_to raise_error
            expect(resource[:logonaccount]).to eq('LocalSystem')
          end
        end
      end

      context "when domain is different from computer name" do
        before do
          allow(Puppet::Util::Windows::User).to receive(:get_rights).and_return("SeServiceLogonRight")
        end

        context "when given user is from AD" do
          let(:user_input) { 'myRemoteUser' }
          let(:principal) do
            Puppet::Util::Windows::SID::Principal.new("myRemoteUser", nil, nil, "AD", :SidTypeUser)
          end

          it "should not raise any error" do
            expect { provider.logonaccount=(user_input) }.not_to raise_error
          end

          it "should succesfully be munged" do
            expect { provider.logonaccount=(user_input) }.not_to raise_error
            expect(resource[:logonaccount]).to eq('AD\myRemoteUser')
          end
        end

        context "when given user is LocalService" do
          let(:user_input) { 'LocalService' }
          let(:principal) do
            Puppet::Util::Windows::SID::Principal.new("LOCAL SERVICE", nil, nil, "NT AUTHORITY", :SidTypeWellKnownGroup)
          end

          it "should succesfully munge well known user" do
            expect { provider.logonaccount=(user_input) }.not_to raise_error
            expect(resource[:logonaccount]).to eq('NT AUTHORITY\LOCAL SERVICE')
          end
        end

        context "when given user is in SID form" do
          let(:user_input) { 'S-1-5-20' }
          let(:principal) do
            Puppet::Util::Windows::SID::Principal.new("NETWORK SERVICE", nil, nil, "NT AUTHORITY", :SidTypeUser)
          end

          it "should succesfully munge" do
            expect { provider.logonaccount=(user_input) }.not_to raise_error
            expect(resource[:logonaccount]).to eq('NT AUTHORITY\NETWORK SERVICE')
          end
        end

        context "when given user is actually a group" do
          let(:principal) do
            Puppet::Util::Windows::SID::Principal.new("Administrators", nil, nil, "BUILTIN", :SidTypeAlias)
          end
          let(:user_input) { 'Administrators' }

          it "should fail when sid type is not user or well known user" do
            expect { provider.logonaccount=(user_input) }.to raise_error(Puppet::Error, /"BUILTIN\\#{user_input}" is not a valid account/)
          end
        end
      end
    end

    describe "#logonpassword=" do
      before do
        allow(Puppet::Util::Windows::User).to receive(:get_rights).and_return('SeServiceLogonRight')
        resource[:logonaccount] = account
        resource[:logonpassword] = user_input
        provider.logonaccount_insync?(account)
      end

      let(:account) { 'LocalSystem' }

      describe "when given logonaccount is a predefined_local_account" do
        let(:user_input) { 'pass' }
        let(:principal) { nil }

        it "should pass validation when given account is 'LocalSystem'" do
          allow(Puppet::Util::Windows::User).to receive(:localsystem?).with('LocalSystem').and_return(true)
          allow(Puppet::Util::Windows::User).to receive(:default_system_account?).with('LocalSystem').and_return(true)

          expect(Puppet::Util::Windows::User).not_to receive(:password_is?)
          expect { provider.logonpassword=(user_input) }.not_to raise_error
        end

        ['LOCAL SERVICE', 'NETWORK SERVICE', 'SYSTEM'].each do |predefined_local_account|
          describe "when given account is #{predefined_local_account}" do
            let(:account) { 'predefined_local_account' }
            let(:principal) do
              Puppet::Util::Windows::SID::Principal.new(account, nil, nil, "NT AUTHORITY", :SidTypeUser)
            end

            it "should pass validation" do
              allow(Puppet::Util::Windows::User).to receive(:localsystem?).with(principal.account).and_return(false)
              allow(Puppet::Util::Windows::User).to receive(:localsystem?).with(principal.domain_account).and_return(false)
              expect(Puppet::Util::Windows::User).to receive(:default_system_account?).with(principal.domain_account).and_return(true).twice

              expect(Puppet::Util::Windows::User).not_to receive(:password_is?)
              expect { provider.logonpassword=(user_input) }.not_to raise_error
            end
          end
        end
      end

      describe "when given logonaccount is not a predefined local account" do
        before do
          allow(Puppet::Util::Windows::User).to receive(:localsystem?).with(".\\#{principal.account}").and_return(false)
          allow(Puppet::Util::Windows::User).to receive(:default_system_account?).with(".\\#{principal.account}").and_return(false)
        end

        let(:account) { 'myUser' }
        let(:principal) do
          Puppet::Util::Windows::SID::Principal.new(account, nil, nil, computer_name, :SidTypeUser)
        end

        describe "when password is proven correct" do
          let(:user_input) { 'myPass' }
          it "should pass validation" do
            allow(Puppet::Util::Windows::User).to receive(:password_is?).with('myUser', 'myPass', '.').and_return(true)
            expect { provider.logonpassword=(user_input) }.not_to raise_error
          end
        end

        describe "when password is not proven correct" do
          let(:user_input) { 'myWrongPass' }
          it "should not pass validation" do
            allow(Puppet::Util::Windows::User).to receive(:password_is?).with('myUser', 'myWrongPass', '.').and_return(false)
            expect { provider.logonpassword=(user_input) }.to raise_error(Puppet::Error, /The given password is invalid for user '.\\myUser'/)
          end
        end
      end
    end
  end
end
