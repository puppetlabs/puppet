#! /usr/bin/env ruby
#
# Unit testing for the Init service Provider
#

require 'spec_helper'

describe Puppet::Type.type(:service).provider(:init) do
  before do
    Puppet::Type.type(:service).defaultprovider = described_class
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

  describe "when getting all service instances" do
    before :each do
      described_class.stubs(:defpath).returns('tmp')

      @services = ['one', 'two', 'three', 'four', 'umountfs']
      Dir.stubs(:entries).with('tmp').returns @services
      FileTest.expects(:directory?).with('tmp').returns(true)
      FileTest.stubs(:executable?).returns(true)
    end

    it "should return instances for all services" do
      expect(described_class.instances.map(&:name)).to eq(@services)
    end

    it "should omit an array of services from exclude list" do
      exclude = ['two', 'four']
      expect(described_class.get_services(described_class.defpath, exclude).map(&:name)).to eq(@services - exclude)
    end

    it "should omit a single service from the exclude list" do
      exclude = 'two'
      expect(described_class.get_services(described_class.defpath, exclude).map(&:name)).to eq(@services - [exclude])
    end

    it "should omit Yocto services on cisco-wrlinux" do
      Facter.stubs(:value).with(:osfamily).returns 'cisco-wrlinux'
      exclude = 'umountfs'
      expect(described_class.get_services(described_class.defpath).map(&:name)).to eq(@services - [exclude])
    end

    it "should not omit Yocto services on non cisco-wrlinux platforms" do
      expect(described_class.get_services(described_class.defpath).map(&:name)).to eq(@services)
    end

    it "should use defpath" do
      expect(described_class.instances).to be_all { |provider| provider.get(:path) == described_class.defpath }
    end

    it "should set hasstatus to true for providers" do
      expect(described_class.instances).to be_all { |provider| provider.get(:hasstatus) == true }
    end

    it "should discard upstart jobs", :if => Puppet.features.manages_symlinks? do
      not_init_service, *valid_services = @services
      path = "tmp/#{not_init_service}"
      Puppet::FileSystem.expects(:symlink?).at_least_once.returns false
      Puppet::FileSystem.expects(:symlink?).with(Puppet::FileSystem.pathname(path)).returns(true)
      Puppet::FileSystem.expects(:readlink).with(Puppet::FileSystem.pathname(path)).returns("/lib/init/upstart-job")
      expect(described_class.instances.map(&:name)).to eq(valid_services)
    end

    it "should discard non-initscript scripts" do
      valid_services = @services
      all_services = valid_services + excludes
      Dir.expects(:entries).with('tmp').returns all_services
      expect(described_class.instances.map(&:name)).to match_array(valid_services)
    end
  end

  describe "when checking valid paths" do
    it "should discard paths that do not exist" do
      File.expects(:directory?).with(paths[0]).returns false
      Puppet::FileSystem.expects(:exist?).with(paths[0]).returns false
      File.expects(:directory?).with(paths[1]).returns true

      expect(provider.paths).to eq([paths[1]])
    end

    it "should discard paths that are not directories" do
      paths.each do |path|
        Puppet::FileSystem.expects(:exist?).with(path).returns true
        File.expects(:directory?).with(path).returns false
      end
      expect(provider.paths).to be_empty
    end
  end

  describe "when searching for the init script" do
    before :each do
      paths.each {|path| File.expects(:directory?).with(path).returns true }
    end

    it "should be able to find the init script in the service path" do
      Puppet::FileSystem.expects(:exist?).with("#{paths[0]}/myservice").returns true
      Puppet::FileSystem.expects(:exist?).with("#{paths[1]}/myservice").never # first one wins
      expect(provider.initscript).to eq("/service/path/myservice")
    end

    it "should be able to find the init script in an alternate service path" do
      Puppet::FileSystem.expects(:exist?).with("#{paths[0]}/myservice").returns false
      Puppet::FileSystem.expects(:exist?).with("#{paths[1]}/myservice").returns true
      expect(provider.initscript).to eq("/alt/service/path/myservice")
    end

    it "should be able to find the init script if it ends with .sh" do
      Puppet::FileSystem.expects(:exist?).with("#{paths[0]}/myservice").returns false
      Puppet::FileSystem.expects(:exist?).with("#{paths[1]}/myservice").returns false
      Puppet::FileSystem.expects(:exist?).with("#{paths[0]}/myservice.sh").returns true
      expect(provider.initscript).to eq("/service/path/myservice.sh")
    end

    it "should fail if the service isn't there" do
      paths.each do |path|
        Puppet::FileSystem.expects(:exist?).with("#{path}/myservice").returns false
        Puppet::FileSystem.expects(:exist?).with("#{path}/myservice.sh").returns false
      end
      expect { provider.initscript }.to raise_error(Puppet::Error, "Could not find init script for 'myservice'")
    end
  end

  describe "if the init script is present" do
    before :each do
      File.stubs(:directory?).with("/service/path").returns true
      File.stubs(:directory?).with("/alt/service/path").returns true
      Puppet::FileSystem.stubs(:exist?).with("/service/path/myservice").returns true
    end

    [:start, :stop, :status, :restart].each do |method|
      it "should have a #{method} method" do
        expect(provider).to respond_to(method)
      end
      describe "when running #{method}" do
        before :each do
          $CHILD_STATUS.stubs(:exitstatus).returns(0)
        end

        it "should use any provided explicit command" do
          resource[method] = "/user/specified/command"
          provider.expects(:execute).with { |command, *args| command == ["/user/specified/command"] }

          provider.send(method)
        end

        it "should pass #{method} to the init script when no explicit command is provided" do
          resource[:hasrestart] = :true
          resource[:hasstatus] = :true
          provider.expects(:execute).with { |command, *args| command ==  ["/service/path/myservice",method]}

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
          provider.expects(:texecute).with(:status, ['/service/path/myservice', :status], false).returns("")
          $CHILD_STATUS.stubs(:exitstatus).returns(0)
          provider.status
        end
        it "should consider the process running if the command returns 0" do
          provider.expects(:texecute).with(:status, ['/service/path/myservice', :status], false).returns("")
          $CHILD_STATUS.stubs(:exitstatus).returns(0)
          expect(provider.status).to eq(:running)
        end
        [-10,-1,1,10].each { |ec|
          it "should consider the process stopped if the command returns something non-0" do
            provider.expects(:texecute).with(:status, ['/service/path/myservice', :status], false).returns("")
            $CHILD_STATUS.stubs(:exitstatus).returns(ec)
            expect(provider.status).to eq(:stopped)
          end
        }
      end
      describe "when hasstatus is not :true" do
        before :each do
          resource[:hasstatus] = :false
        end

        it "should consider the service :running if it has a pid" do
          provider.expects(:getpid).returns "1234"
          expect(provider.status).to eq(:running)
        end
        it "should consider the service :stopped if it doesn't have a pid" do
          provider.expects(:getpid).returns nil
          expect(provider.status).to eq(:stopped)
        end
      end
    end

    describe "when restarting and hasrestart is not :true" do
      before :each do
        resource[:hasrestart] = :false
      end

      it "should stop and restart the process" do
        provider.expects(:texecute).with(:stop, ['/service/path/myservice', :stop ], true).returns("")
        provider.expects(:texecute).with(:start,['/service/path/myservice', :start], true).returns("")
        $CHILD_STATUS.stubs(:exitstatus).returns(0)
        provider.restart
      end
    end

    describe "when starting a service on Solaris" do
      it "should use ctrun" do
        Facter.stubs(:value).with(:osfamily).returns 'Solaris'
        provider.expects(:execute).with('/usr/bin/ctrun -l none /service/path/myservice start', {:failonfail => true, :override_locale => false, :squelch => false, :combine => true}).returns("")
        $CHILD_STATUS.stubs(:exitstatus).returns(0)
        provider.start
      end
    end

    describe "when starting a service on RedHat" do
      it "should not use ctrun" do
        Facter.stubs(:value).with(:osfamily).returns 'RedHat'
        provider.expects(:execute).with(['/service/path/myservice', :start], {:failonfail => true, :override_locale => false, :squelch => false, :combine => true}).returns("")
        $CHILD_STATUS.stubs(:exitstatus).returns(0)
        provider.start
      end
    end
  end
end
