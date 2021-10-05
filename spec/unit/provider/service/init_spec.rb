require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Init',
         unless: Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:init) }

  before :all do
    `exit 0`
  end

  before do
    Puppet::Type.type(:service).defaultprovider = provider_class
  end

  after do
    Puppet::Type.type(:service).defaultprovider = nil
  end

  let :provider do
    resource.provider
  end

  let :resource do
    Puppet::Type.type(:service).new(
      :name     => 'myservice',
      :ensure   => :running,
      :path     => paths
    )
  end

  let :paths do
    ["/service/path","/alt/service/path"]
  end

  let :excludes do
    # Taken from redhat, gentoo, and debian
    %w{functions.sh reboot.sh shutdown.sh functions halt killall single linuxconf reboot boot wait-for-state rcS module-init-tools}
  end

  describe "when running on FreeBSD" do
    before :each do
      allow(Facter).to receive(:value).with(:operatingsystem).and_return('FreeBSD')
      allow(Facter).to receive(:value).with(:osfamily).and_return('FreeBSD')
    end

    it "should set its default path to include /etc/rc.d and /usr/local/etc/rc.d" do
      expect(provider_class.defpath).to eq(["/etc/rc.d", "/usr/local/etc/rc.d"])
    end
  end

  describe "when running on HP-UX" do
    before :each do
      allow(Facter).to receive(:value).with(:operatingsystem).and_return('HP-UX')
    end

    it "should set its default path to include /sbin/init.d" do
      expect(provider_class.defpath).to eq("/sbin/init.d")
    end
  end

  describe "when running on Archlinux" do
    before :each do
      allow(Facter).to receive(:value).with(:operatingsystem).and_return('Archlinux')
    end

    it "should set its default path to include /etc/rc.d" do
      expect(provider_class.defpath).to eq("/etc/rc.d")
    end
  end

  describe "when not running on FreeBSD, HP-UX or Archlinux" do
    before :each do
      allow(Facter).to receive(:value).with(:operatingsystem).and_return('RedHat')
    end

    it "should set its default path to include /etc/init.d" do
      expect(provider_class.defpath).to eq("/etc/init.d")
    end
  end

  describe "when getting all service instances" do
    before :each do
      allow(provider_class).to receive(:defpath).and_return('tmp')

      @services = ['one', 'two', 'three', 'four', 'umountfs']
      allow(Dir).to receive(:entries).and_call_original
      allow(Dir).to receive(:entries).with('tmp').and_return(@services)
      allow(FileTest).to receive(:directory?).and_call_original
      allow(FileTest).to receive(:directory?).with('tmp').and_return(true)
      allow(FileTest).to receive(:executable?).and_return(true)
    end

    it "should return instances for all services" do
      expect(provider_class.instances.map(&:name)).to eq(@services)
    end

    it "should omit directories from the service list" do
      expect(FileTest).to receive(:directory?).with('tmp/four').and_return(true)
      expect(provider_class.instances.map(&:name)).to eq(@services - ['four'])
    end

    it "should omit an array of services from exclude list" do
      exclude = ['two', 'four']
      expect(provider_class.get_services(provider_class.defpath, exclude).map(&:name)).to eq(@services - exclude)
    end

    it "should omit a single service from the exclude list" do
      exclude = 'two'
      expect(provider_class.get_services(provider_class.defpath, exclude).map(&:name)).to eq(@services - [exclude])
    end

    it "should omit Yocto services on cisco-wrlinux" do
      allow(Facter).to receive(:value).with(:osfamily).and_return('cisco-wrlinux')
      exclude = 'umountfs'
      expect(provider_class.get_services(provider_class.defpath).map(&:name)).to eq(@services - [exclude])
    end

    it "should not omit Yocto services on non cisco-wrlinux platforms" do
      expect(provider_class.get_services(provider_class.defpath).map(&:name)).to eq(@services)
    end

    it "should use defpath" do
      expect(provider_class.instances).to be_all { |provider| provider.get(:path) == provider_class.defpath }
    end

    it "should set hasstatus to true for providers" do
      expect(provider_class.instances).to be_all { |provider| provider.get(:hasstatus) == true }
    end

    it "should discard upstart jobs", :if => Puppet.features.manages_symlinks? do
      not_init_service, *valid_services = @services
      path = "tmp/#{not_init_service}"
      allow(Puppet::FileSystem).to receive(:symlink?).at_least(:once).and_return(false)
      allow(Puppet::FileSystem).to receive(:symlink?).with(Puppet::FileSystem.pathname(path)).and_return(true)
      allow(Puppet::FileSystem).to receive(:readlink).with(Puppet::FileSystem.pathname(path)).and_return("/lib/init/upstart-job")
      expect(provider_class.instances.map(&:name)).to eq(valid_services)
    end

    it "should discard non-initscript scripts" do
      valid_services = @services
      all_services = valid_services + excludes
      expect(Dir).to receive(:entries).with('tmp').and_return(all_services)
      expect(provider_class.instances.map(&:name)).to match_array(valid_services)
    end
  end

  describe "when checking valid paths" do
    it "should discard paths that do not exist" do
      expect(File).to receive(:directory?).with(paths[0]).and_return(false)
      expect(Puppet::FileSystem).to receive(:exist?).with(paths[0]).and_return(false)
      expect(File).to receive(:directory?).with(paths[1]).and_return(true)

      expect(provider.paths).to eq([paths[1]])
    end

    it "should discard paths that are not directories" do
      paths.each do |path|
        expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(true)
        expect(File).to receive(:directory?).with(path).and_return(false)
      end
      expect(provider.paths).to be_empty
    end
  end

  describe "when searching for the init script" do
    before :each do
      paths.each {|path| expect(File).to receive(:directory?).with(path).and_return(true) }
    end

    it "should be able to find the init script in the service path" do
      expect(Puppet::FileSystem).to receive(:exist?).with("#{paths[0]}/myservice").and_return(true)
      expect(Puppet::FileSystem).not_to receive(:exist?).with("#{paths[1]}/myservice") # first one wins
      expect(provider.initscript).to eq("/service/path/myservice")
    end

    it "should be able to find the init script in an alternate service path" do
      expect(Puppet::FileSystem).to receive(:exist?).with("#{paths[0]}/myservice").and_return(false)
      expect(Puppet::FileSystem).to receive(:exist?).with("#{paths[1]}/myservice").and_return(true)
      expect(provider.initscript).to eq("/alt/service/path/myservice")
    end

    it "should be able to find the init script if it ends with .sh" do
      expect(Puppet::FileSystem).to receive(:exist?).with("#{paths[0]}/myservice").and_return(false)
      expect(Puppet::FileSystem).to receive(:exist?).with("#{paths[1]}/myservice").and_return(false)
      expect(Puppet::FileSystem).to receive(:exist?).with("#{paths[0]}/myservice.sh").and_return(true)
      expect(provider.initscript).to eq("/service/path/myservice.sh")
    end

    it "should fail if the service isn't there" do
      paths.each do |path|
        expect(Puppet::FileSystem).to receive(:exist?).with("#{path}/myservice").and_return(false)
        expect(Puppet::FileSystem).to receive(:exist?).with("#{path}/myservice.sh").and_return(false)
      end
      expect { provider.initscript }.to raise_error(Puppet::Error, "Could not find init script for 'myservice'")
    end
  end

  describe "if the init script is present" do
    before :each do
      allow(File).to receive(:directory?).and_call_original
      allow(File).to receive(:directory?).with("/service/path").and_return(true)
      allow(File).to receive(:directory?).with("/alt/service/path").and_return(true)
      allow(Puppet::FileSystem).to receive(:exist?).with("/service/path/myservice").and_return(true)
    end

    [:start, :stop, :status, :restart].each do |method|
      it "should have a #{method} method" do
        expect(provider).to respond_to(method)
      end

      describe "when running #{method}" do
        before :each do
          allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
        end

        it "should use any provided explicit command" do
          resource[method] = "/user/specified/command"
          expect(provider).to receive(:execute).with(["/user/specified/command"], any_args)

          provider.send(method)
        end

        it "should pass #{method} to the init script when no explicit command is provided" do
          resource[:hasrestart] = :true
          resource[:hasstatus] = :true
          expect(provider).to receive(:execute).with(["/service/path/myservice", method], any_args)

          provider.send(method)
        end
      end
    end

    describe "when checking status" do
      describe "when hasstatus is :true" do
        before :each do
          resource[:hasstatus] = :true
        end

        it "should execute the command" do
          expect(provider).to receive(:texecute).with(:status, ['/service/path/myservice', :status], false).and_return("")
          allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
          provider.status
        end

        it "should consider the process running if the command returns 0" do
          expect(provider).to receive(:texecute).with(:status, ['/service/path/myservice', :status], false).and_return("")
          allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
          expect(provider.status).to eq(:running)
        end

        [-10,-1,1,10].each { |ec|
          it "should consider the process stopped if the command returns something non-0" do
            expect(provider).to receive(:texecute).with(:status, ['/service/path/myservice', :status], false).and_return("")
            allow($CHILD_STATUS).to receive(:exitstatus).and_return(ec)
            expect(provider.status).to eq(:stopped)
          end
        }
      end

      describe "when hasstatus is not :true" do
        before :each do
          resource[:hasstatus] = :false
        end

        it "should consider the service :running if it has a pid" do
          expect(provider).to receive(:getpid).and_return("1234")
          expect(provider.status).to eq(:running)
        end

        it "should consider the service :stopped if it doesn't have a pid" do
          expect(provider).to receive(:getpid).and_return(nil)
          expect(provider.status).to eq(:stopped)
        end
      end
    end

    describe "when restarting and hasrestart is not :true" do
      before :each do
        resource[:hasrestart] = :false
      end

      it "should stop and restart the process" do
        expect(provider).to receive(:texecute).with(:stop,  ['/service/path/myservice', :stop ], true).and_return("")
        expect(provider).to receive(:texecute).with(:start, ['/service/path/myservice', :start], true).and_return("")
        allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
        provider.restart
      end
    end

    describe "when starting a service on Solaris" do
      it "should use ctrun" do
        allow(Facter).to receive(:value).with(:osfamily).and_return('Solaris')
        expect(provider).to receive(:execute).with('/usr/bin/ctrun -l child /service/path/myservice start', {:failonfail => true, :override_locale => false, :squelch => false, :combine => true}).and_return("")
        allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
        provider.start
      end
    end

    describe "when starting a service on RedHat" do
      it "should not use ctrun" do
        allow(Facter).to receive(:value).with(:osfamily).and_return('RedHat')
        expect(provider).to receive(:execute).with(['/service/path/myservice', :start], {:failonfail => true, :override_locale => false, :squelch => false, :combine => true}).and_return("")
        allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
        provider.start
      end
    end
  end
end
