require 'spec_helper'

def safely_load_service_type
  before(:each) do
    # We have a :confine block that calls execute in our upstart provider, which fails
    # on jruby. Thus, we stub it out here since we don't care to do any assertions on it.
    # This is only an issue if you're running these unit tests on a platform where upstart
    # is a default provider, like Ubuntu trusty.
    allow(Puppet::Util::Execution).to receive(:execute)
    Puppet::Type.type(:service)
  end
end

test_title = 'Puppet::Type::Service'

describe test_title do
  safely_load_service_type

  it "should have an :enableable feature that requires the :enable, :disable, and :enabled? methods" do
    expect(Puppet::Type.type(:service).provider_feature(:enableable).methods).to eq([:disable, :enable, :enabled?])
  end

  it "should have a :refreshable feature that requires the :restart method" do
    expect(Puppet::Type.type(:service).provider_feature(:refreshable).methods).to eq([:restart])
  end
end

describe test_title, "when validating attributes" do
  safely_load_service_type

  [:name, :binary, :hasstatus, :path, :pattern, :start, :restart, :stop, :status, :hasrestart, :control, :timeout].each do |param|
    it "should have a #{param} parameter" do
      expect(Puppet::Type.type(:service).attrtype(param)).to eq(:param)
    end
  end

  [:ensure, :enable].each do |param|
    it "should have an #{param} property" do
      expect(Puppet::Type.type(:service).attrtype(param)).to eq(:property)
    end
  end
end

describe test_title, "when validating attribute values" do
  safely_load_service_type

  before do
    @provider = double('provider', :class => Puppet::Type.type(:service).defaultprovider, :clear => nil, :controllable? => false)
    allow(Puppet::Type.type(:service).defaultprovider).to receive(:new).and_return(@provider)
  end

  it "should support :running as a value to :ensure" do
    Puppet::Type.type(:service).new(:name => "yay", :ensure => :running)
  end

  it "should support :stopped as a value to :ensure" do
    Puppet::Type.type(:service).new(:name => "yay", :ensure => :stopped)
  end

  it "should alias the value :true to :running in :ensure" do
    svc = Puppet::Type.type(:service).new(:name => "yay", :ensure => true)
    expect(svc.should(:ensure)).to eq(:running)
  end

  it "should alias the value :false to :stopped in :ensure" do
    svc = Puppet::Type.type(:service).new(:name => "yay", :ensure => false)
    expect(svc.should(:ensure)).to eq(:stopped)
  end

  describe "the enable property" do
    before :each do
      allow(@provider.class).to receive(:supports_parameter?).and_return(true)
    end

    it "should support :true as a value" do
      srv = Puppet::Type.type(:service).new(:name => "yay", :enable => :true)
      expect(srv.should(:enable)).to eq(:true)
    end

    it "should support :false as a value" do
      srv = Puppet::Type.type(:service).new(:name => "yay", :enable => :false)
      expect(srv.should(:enable)).to eq(:false)
    end

    it "should support :mask as a value" do
      srv = Puppet::Type.type(:service).new(:name => "yay", :enable => :mask)
      expect(srv.should(:enable)).to eq(:mask)
    end

    it "should support :manual as a value on Windows" do
      allow(Puppet::Util::Platform).to receive(:windows?).and_return(true)
      srv = Puppet::Type.type(:service).new(:name => "yay", :enable => :manual)
      expect(srv.should(:enable)).to eq(:manual)
    end

    it "should support :delayed as a value on Windows" do
      allow(Puppet::Util::Platform).to receive(:windows?).and_return(true)

      srv = Puppet::Type.type(:service).new(:name => "yay", :enable => :delayed)
      expect(srv.should(:enable)).to eq(:delayed)
    end

    it "should not support :manual as a value when not on Windows" do
      allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)

      expect { Puppet::Type.type(:service).new(:name => "yay", :enable => :manual) }.to raise_error(
        Puppet::Error,
        /Setting enable to manual is only supported on Microsoft Windows\./
      )
    end

    it "should not support :delayed as a value when not on Windows" do
      allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)

      expect { Puppet::Type.type(:service).new(:name => "yay", :enable => :delayed) }.to raise_error(
        Puppet::Error,
        /Setting enable to delayed is only supported on Microsoft Windows\./
      )
    end
  end

  describe "the timeout parameter" do
    before do
      provider_class_with_timeout = Puppet::Type.type(:service).provide(:simple) do
        has_features :configurable_timeout
      end
      allow(Puppet::Type.type(:service)).to receive(:defaultprovider).and_return(provider_class_with_timeout)
    end

    it "should fail when timeout is not an integer" do
      expect { Puppet::Type.type(:service).new(:name => "yay", :timeout => 'foobar') }.to raise_error(Puppet::Error)
    end

    [-999, -1, 0].each do |int|
      it "should not support #{int} as a value to :timeout" do
        expect { Puppet::Type.type(:service).new(:name => "yay", :timeout => int) }.to raise_error(Puppet::Error)
      end
    end

    [1, 30, 999].each do |int|
      it "should support #{int} as a value to :timeout" do
        srv = Puppet::Type.type(:service).new(:name => "yay", :timeout => int)
        expect(srv[:timeout]).to eq(int)
      end
    end
  end

  describe "the service logon credentials" do 
    before do
      provider_class_with_logon_credentials = Puppet::Type.type(:service).provide(:simple) do
        has_features :manages_logon_credentials
        def logonpassword=(value) end
      end
      allow(Puppet::Type.type(:service)).to receive(:defaultprovider).and_return(provider_class_with_logon_credentials)
    end

    describe "the 'logonaccount' property" do
      it "should not be munged nor checked when not on Windows" do
        allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)
        service = Puppet::Type.type(:service).new(:name => "yay", :logonaccount => 'NonWindowsUser')

        expect { service }.not_to raise_error
        expect(service[:logonaccount]).to eq('NonWindowsUser')
      end

      context "when on Windows", :if => Puppet::Util::Platform.windows? do
        before do
          allow(Puppet::Util::Windows::ADSI).to receive(:computer_name).and_return("myPC")
          allow(Puppet::Util::Windows::User).to receive(:default_system_account?).and_return(true)
        end

        ['LocalSystem', '.\LocalSystem', 'myPC\LocalSystem', 'lOcALsysTem'].each do |user_input|
          it "should succesfully munge #{user_input} to 'LocalSystem'" do
            service = Puppet::Type.type(:service).new(:name => "yay", :logonaccount => user_input)

            expect { service }.not_to raise_error
            expect(service[:logonaccount]).to eq('LocalSystem')
          end
        end

        it "should succesfully munge local account" do
          allow(Puppet::Util::Windows::SID).to receive(:name_to_principal).and_return(Puppet::Util::Windows::SID::Principal.new("myUser", nil, nil, "myPC", :SidTypeUser))
          service = Puppet::Type.type(:service).new(:name => "yay", :logonaccount => 'myUser')

          expect { service }.not_to raise_error
          expect(service[:logonaccount]).to eq('.\myUser')
        end

        it "should succesfully munge domain account" do
          allow(Puppet::Util::Windows::SID).to receive(:name_to_principal).and_return(Puppet::Util::Windows::SID::Principal.new("DomainUser", nil, nil, "myDomain", :SidTypeUser))
          service = Puppet::Type.type(:service).new(:name => "yay", :logonaccount => 'DomainUser')

          expect { service }.not_to raise_error
          expect(service[:logonaccount]).to eq('myDomain\DomainUser')
        end

        it "should succesfully munge well known user" do
          allow(Puppet::Util::Windows::SID).to receive(:name_to_principal).and_return(Puppet::Util::Windows::SID::Principal.new("LOCAL SERVICE", nil, nil, "NT AUTHORITY", :SidTypeWellKnownGroup))
          service = Puppet::Type.type(:service).new(:name => "yay", :logonaccount => 'LocalService')

          expect { service }.not_to raise_error
          expect(service[:logonaccount]).to eq('NT AUTHORITY\LOCAL SERVICE')
        end

        it "should succesfully munge a SID" do
          allow(Puppet::Util::Windows::SID).to receive(:name_to_principal).and_return(Puppet::Util::Windows::SID::Principal.new("NETWORK SERVICE", nil, nil, "NT AUTHORITY", :SidTypeUser))
          service = Puppet::Type.type(:service).new(:name => "yay", :logonaccount => 'S-1-5-20')

          expect { service }.not_to raise_error
          expect(service[:logonaccount]).to eq('NT AUTHORITY\NETWORK SERVICE')
        end

        it "should fail when account is invalid" do
          allow(Puppet::Util::Windows::SID).to receive(:name_to_principal).and_return(nil)
          expect { Puppet::Type.type(:service).new(:name => "yay", :logonaccount => 'InvalidUser') }.to raise_error(Puppet::Error, /\"InvalidUser\" is not a valid account/)
        end

        it "should fail when sid type is not user or well known user" do
          allow(Puppet::Util::Windows::SID).to receive(:name_to_principal).and_return(Puppet::Util::Windows::SID::Principal.new("Administrators", nil, nil, "BUILTIN", :SidTypeAlias))
          expect { Puppet::Type.type(:service).new(:name => "yay", :logonaccount => 'Administrators') }.to raise_error(Puppet::Error, /\"Administrators\" is not a valid account/)
        end
      end
    end

    describe "the logonpassword parameter" do
      it "should fail when logonaccount is not being managed as well" do
        expect { Puppet::Type.type(:service).new(:name => "yay", :logonpassword => 'myPass') }.to raise_error(Puppet::Error, /The 'logonaccount' parameter is mandatory when setting 'logonpassword'./)
      end

      it "should default to empty string when only logonaccount is being managed" do
        allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)
        service = Puppet::Type.type(:service).new(:name => "yay", :logonaccount => 'myUser')

        expect { service }.not_to raise_error
        expect(service[:logonpassword]).to eq("")
      end

      it "should default to nil when not even logonaccount is being managed" do
        service = Puppet::Type.type(:service).new(:name => "yay")
        expect(service[:logonpassword]).to eq(nil)
      end

      it "should fail when logonpassword includes the ':' character" do
        allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)
        expect { Puppet::Type.type(:service).new(:name => "yay", :logonaccount => 'myUser', :logonpassword => 'my:Pass') }.to raise_error(Puppet::Error, /Passwords cannot include ':'/)
      end

      it "should not further check the password against given account when not on Windows" do
        allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)
        expect { Puppet::Type.type(:service).new(:name => "yay", :logonaccount => 'myUser', :logonpassword => 'myPass') }.not_to raise_error
      end

      context "when on Windows", :if => Puppet::Util::Platform.windows? do
        before do
          allow(Puppet::Util::Windows::ADSI).to receive(:computer_name).and_return("myPC")
          allow(Puppet::Util::Windows::SID).to receive(:name_to_principal).and_return(name_to_principal_result)
        end

        it "should pass validation when given account is 'LocalSystem'" do
          allow(Puppet::Util::Windows::User).to receive(:localsystem?).with('LocalSystem').and_return(true)
          allow(Puppet::Util::Windows::User).to receive(:default_system_account?).with('LocalSystem').and_return(false)

          expect(Puppet::Util::Windows::SID).not_to receive(:name_to_principal)
          expect(Puppet::Util::Windows::User).not_to receive(:password_is?)
          expect { Puppet::Type.type(:service).new(:name => "yay", :logonaccount => 'LocalSystem') }.not_to raise_error
        end

        ['LOCAL SERVICE', 'NETWORK SERVICE', 'SYSTEM'].each do |predefined_local_account|
          describe "when given account is #{predefined_local_account}" do
            let(:name_to_principal_result) do
              Puppet::Util::Windows::SID::Principal.new(predefined_local_account, nil, nil, "NT AUTHORITY", :SidTypeUser)
            end

            it "should pass validation" do
              allow(Puppet::Util::Windows::User).to receive(:localsystem?).with(predefined_local_account).and_return(false)
              expect(Puppet::Util::Windows::User).to receive(:default_system_account?).with("NT AUTHORITY\\#{predefined_local_account}").and_return(true)

              expect(Puppet::Util::Windows::User).not_to receive(:password_is?)
              expect { Puppet::Type.type(:service).new(:name => "yay", :logonaccount => predefined_local_account) }.not_to raise_error
            end
          end
        end

        let(:name_to_principal_result) do
          Puppet::Util::Windows::SID::Principal.new("myUser", nil, nil, "myPC", :SidTypeUser)
        end

        describe "when given logonaccount is not a predefined local account" do
          before do
            allow(Puppet::Util::Windows::User).to receive(:localsystem?).with('myUser').and_return(false)
            allow(Puppet::Util::Windows::User).to receive(:default_system_account?).with('.\\myUser').and_return(false)
          end

          it "should pass validation if password is proven correct" do
            allow(Puppet::Util::Windows::User).to receive(:password_is?).with('myUser', 'myPass', '.').and_return(true)
            expect { Puppet::Type.type(:service).new(:name => "yay", :logonaccount => 'myUser', :logonpassword => 'myPass') }.not_to raise_error
          end

          it "should not pass validation if password check fails" do
            allow(Puppet::Util::Windows::User).to receive(:password_is?).with('myUser', 'myWrongPass', '.').and_return(false)
            expect { Puppet::Type.type(:service).new(:name => "yay", :logonaccount => 'myUser', :logonpassword => 'myWrongPass') }.to raise_error(Puppet::Error, /The given password is invalid for user '.\\myUser'/)
          end
        end
      end
    end
  end

  it "should support :true as a value to :hasstatus" do
    srv = Puppet::Type.type(:service).new(:name => "yay", :hasstatus => :true)
    expect(srv[:hasstatus]).to eq(:true)
  end

  it "should support :false as a value to :hasstatus" do
    srv = Puppet::Type.type(:service).new(:name => "yay", :hasstatus => :false)
    expect(srv[:hasstatus]).to eq(:false)
  end

  it "should specify :true as the default value of hasstatus" do
    srv = Puppet::Type.type(:service).new(:name => "yay")
    expect(srv[:hasstatus]).to eq(:true)
  end

  it "should support :true as a value to :hasrestart" do
    srv = Puppet::Type.type(:service).new(:name => "yay", :hasrestart => :true)
    expect(srv[:hasrestart]).to eq(:true)
  end

  it "should support :false as a value to :hasrestart" do
    srv = Puppet::Type.type(:service).new(:name => "yay", :hasrestart => :false)
    expect(srv[:hasrestart]).to eq(:false)
  end

  it "should allow setting the :enable parameter if the provider has the :enableable feature" do
    allow(Puppet::Type.type(:service).defaultprovider).to receive(:supports_parameter?).and_return(true)
    expect(Puppet::Type.type(:service).defaultprovider).to receive(:supports_parameter?).with(Puppet::Type.type(:service).attrclass(:enable)).and_return(true)
    svc = Puppet::Type.type(:service).new(:name => "yay", :enable => true)
    expect(svc.should(:enable)).to eq(:true)
  end

  it "should not allow setting the :enable parameter if the provider is missing the :enableable feature" do
    allow(Puppet::Type.type(:service).defaultprovider).to receive(:supports_parameter?).and_return(true)
    expect(Puppet::Type.type(:service).defaultprovider).to receive(:supports_parameter?).with(Puppet::Type.type(:service).attrclass(:enable)).and_return(false)
    svc = Puppet::Type.type(:service).new(:name => "yay", :enable => true)
    expect(svc.should(:enable)).to be_nil
  end

  it "should split paths on '#{File::PATH_SEPARATOR}'" do
    allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
    allow(FileTest).to receive(:directory?).and_return(true)
    svc = Puppet::Type.type(:service).new(:name => "yay", :path => "/one/two#{File::PATH_SEPARATOR}/three/four")
    expect(svc[:path]).to eq(%w{/one/two /three/four})
  end

  it "should accept arrays of paths joined by '#{File::PATH_SEPARATOR}'" do
    allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
    allow(FileTest).to receive(:directory?).and_return(true)
    svc = Puppet::Type.type(:service).new(:name => "yay", :path => ["/one#{File::PATH_SEPARATOR}/two", "/three#{File::PATH_SEPARATOR}/four"])
    expect(svc[:path]).to eq(%w{/one /two /three /four})
  end
end

describe test_title, "when setting default attribute values" do
  safely_load_service_type

  it "should default to the provider's default path if one is available" do
    allow(FileTest).to receive(:directory?).and_return(true)
    allow(Puppet::FileSystem).to receive(:exist?).and_return(true)

    allow(Puppet::Type.type(:service).defaultprovider).to receive(:respond_to?).and_return(true)
    allow(Puppet::Type.type(:service).defaultprovider).to receive(:defpath).and_return("testing")
    svc = Puppet::Type.type(:service).new(:name => "other")
    expect(svc[:path]).to eq(["testing"])
  end

  it "should default 'pattern' to the binary if one is provided" do
    svc = Puppet::Type.type(:service).new(:name => "other", :binary => "/some/binary")
    expect(svc[:pattern]).to eq("/some/binary")
  end

  it "should default 'pattern' to the name if no pattern is provided" do
    svc = Puppet::Type.type(:service).new(:name => "other")
    expect(svc[:pattern]).to eq("other")
  end

  it "should default 'control' to the upcased service name with periods replaced by underscores if the provider supports the 'controllable' feature" do
    provider = double('provider', :controllable? => true, :class => Puppet::Type.type(:service).defaultprovider, :clear => nil)
    allow(Puppet::Type.type(:service).defaultprovider).to receive(:new).and_return(provider)
    svc = Puppet::Type.type(:service).new(:name => "nfs.client")
    expect(svc[:control]).to eq("NFS_CLIENT_START")
  end
end

describe test_title, "when retrieving the host's current state" do
  safely_load_service_type

  before do
    @service = Puppet::Type.type(:service).new(:name => "yay")
  end

  it "should use the provider's status to determine whether the service is running" do
    expect(@service.provider).to receive(:status).and_return(:yepper)
    @service[:ensure] = :running
    expect(@service.property(:ensure).retrieve).to eq(:yepper)
  end

  it "should ask the provider whether it is enabled" do
    allow(@service.provider.class).to receive(:supports_parameter?).and_return(true)
    expect(@service.provider).to receive(:enabled?).and_return(:yepper)
    @service[:enable] = true
    expect(@service.property(:enable).retrieve).to eq(:yepper)
  end
end

describe test_title, "when changing the host" do
  safely_load_service_type

  before do
    @service = Puppet::Type.type(:service).new(:name => "yay")
  end

  it "should start the service if it is supposed to be running" do
    @service[:ensure] = :running
    expect(@service.provider).to receive(:start)
    @service.property(:ensure).sync
  end

  it "should stop the service if it is supposed to be stopped" do
    @service[:ensure] = :stopped
    expect(@service.provider).to receive(:stop)
    @service.property(:ensure).sync
  end

  it "should enable the service if it is supposed to be enabled" do
    allow(@service.provider.class).to receive(:supports_parameter?).and_return(true)
    @service[:enable] = true
    expect(@service.provider).to receive(:enable)
    @service.property(:enable).sync
  end

  it "should disable the service if it is supposed to be disabled" do
    allow(@service.provider.class).to receive(:supports_parameter?).and_return(true)
    @service[:enable] = false
    expect(@service.provider).to receive(:disable)
    @service.property(:enable).sync
  end

  it "should let superclass implementation resolve insyncness when provider does not respond to the 'enabled_insync?' method" do
    allow(@service.provider.class).to receive(:supports_parameter?).and_return(true)
    @service[:enable] = true
    allow(@service.provider).to receive(:respond_to?).with(:enabled_insync?).and_return(false)

    expect(@service.property(:enable).insync?(:true)).to eq(true)
  end

  it "insyncness should be resolved by provider instead of superclass implementation when provider responds to the 'enabled_insync?' method" do
    allow(@service.provider.class).to receive(:supports_parameter?).and_return(true)
    @service[:enable] = true
    allow(@service.provider).to receive(:respond_to?).with(:enabled_insync?).and_return(true)
    allow(@service.provider).to receive(:enabled_insync?).and_return(false)

    expect(@service.property(:enable).insync?(:true)).to eq(false)
  end

  it "should sync the service's enable state when changing the state of :ensure if :enable is being managed" do
    allow(@service.provider.class).to receive(:supports_parameter?).and_return(true)
    @service[:enable] = false
    @service[:ensure] = :stopped

    expect(@service.property(:enable)).to receive(:retrieve).and_return("whatever")
    expect(@service.property(:enable)).to receive(:insync?).and_return(false)
    expect(@service.property(:enable)).to receive(:sync)

    allow(@service.provider).to receive(:stop)

    @service.property(:ensure).sync
  end

  it "should sync the service's logonaccount state when changing the state of :ensure if :logonaccount is being managed" do
    allow(@service.provider.class).to receive(:supports_parameter?).and_return(true)
    allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)

    @service[:ensure] = :stopped
    @service[:logonaccount] = 'LocalSystem'

    expect(@service.property(:logonaccount)).to receive(:retrieve).and_return("MyUser")
    expect(@service.property(:logonaccount)).to receive(:insync?).and_return(false)
    expect(@service.property(:logonaccount)).to receive(:sync)

    allow(@service.provider).to receive(:stop)

    @service.property(:ensure).sync
  end
end

describe test_title, "when refreshing the service" do
  safely_load_service_type

  before do
    @service = Puppet::Type.type(:service).new(:name => "yay")
  end

  it "should restart the service if it is running" do
    @service[:ensure] = :running
    expect(@service.provider).to receive(:status).and_return(:running)
    expect(@service.provider).to receive(:restart)
    @service.refresh
  end

  it "should restart the service if it is running, even if it is supposed to stopped" do
    @service[:ensure] = :stopped
    expect(@service.provider).to receive(:status).and_return(:running)
    expect(@service.provider).to receive(:restart)
    @service.refresh
  end

  it "should not restart the service if it is not running" do
    @service[:ensure] = :running
    expect(@service.provider).to receive(:status).and_return(:stopped)
    @service.refresh
  end

  it "should add :ensure as a property if it is not being managed" do
    expect(@service.provider).to receive(:status).and_return(:running)
    expect(@service.provider).to receive(:restart)
    @service.refresh
  end
end
