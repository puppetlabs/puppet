#! /usr/bin/env ruby
require 'spec_helper'

provider = Puppet::Type.type(:package).provider(:opkg)

describe provider do

  before do
    Puppet::Util.stubs(:which).with("opkg").returns("/bin/opkg")
    Dir.stubs(:entries).with('/var/opkg-lists/').returns ['.', '..', 'packages']
    @resource = Puppet::Type.type(:package).new(:name => 'package')
    @provider = provider.new(@resource)
  end

  describe "when installing" do
    before do
      @provider.stubs(:query).returns({ :ensure => '1.0' })
    end
     
    context "when the package list is absent" do
      before do
        Dir.stubs(:entries).with('/var/opkg-lists/').returns ['.', '..']  #empty, no package list
      end
    
      it "fetches the package list when installing" do
        @provider.expects(:opkg).with('update')
        @provider.expects(:opkg).with("--force-overwrite", "install", @resource[:name])
    
        @provider.install
      end
    end
    
    context "when the package list is present" do
      before do
        Dir.stubs(:entries).with('/var/opkg-lists/').returns ['.', '..', 'lists']  # With a pre-downloaded package list
      end
    
      it "fetches the package list when installing" do
        @provider.expects(:opkg).with('update').never
        @provider.expects(:opkg).with("--force-overwrite", "install", @resource[:name])
    
        @provider.install
      end
    end

    it "should call opkg install" do
      Puppet::Util::Execution.expects(:execute).with(["/bin/opkg", "--force-overwrite", "install", @resource[:name]], {:failonfail => true, :combine => true, :custom_environment => {}})
      @provider.install
    end

    context "when :source is specified" do
      before :each do
        @install = sequence("install")
      end

      context "works on valid urls" do
        %w{
          /some/package/file
          http://some.package.in/the/air
          ftp://some.package.in/the/air
        }.each do |source|
          it "should install #{source} directly" do
            @resource[:source] = source
            Puppet::Util::Execution.expects(:execute).with(["/bin/opkg", "--force-overwrite", "install", @resource[:source]], {:failonfail => true, :combine => true, :custom_environment => {}})
            @provider.install
          end
        end
      end

      context "as a file:// URL" do
        before do
          @package_file = "file:///some/package/file"
          @actual_file_path = "/some/package/file"
          @resource[:source] = @package_file
        end

        it "should install from the path segment of the URL" do
          Puppet::Util::Execution.expects(:execute).in_sequence(@install).returns("")
          @provider.install
        end
      end

      context "as a puppet URL" do
        before do
          @resource[:source] = "puppet://server/whatever"
        end

        it "should fail" do
          lambda { @provider.install }.should raise_error(Puppet::Error)
        end
      end

      context "as a malformed URL" do
        before do
          @resource[:source] = "blah://"
        end

        it "should fail" do
          lambda { @provider.install }.should raise_error(Puppet::Error)
        end
      end
    end # end when source is specified
    
    context "when the opkg install command fails" do
      before do
        Dir.stubs(:entries).returns ['.', '..', 'file'] # Ensure opkg('update') doesn't run
      end

      it "raises an error" do
        Puppet::Util::Execution.expects(:execute).raises Puppet::ExecutionFailure
        expect { @provider.install }.to raise_error, "Puppet::ExecutionFailure"
      end
    end
  end # end when installing

  describe "when updating" do
    it "should call install" do
      @provider.expects(:install).returns("install return value")
      @provider.update.should == "install return value"
    end
  end

  describe "when uninstalling" do
    it "should run opkg remove bla" do
      Puppet::Util::Execution.expects(:execute).with(["/bin/opkg", "remove", @resource[:name]], {:failonfail => true, :combine => true, :custom_environment => {}})
      @provider.uninstall
    end
  end

  describe "when querying" do
  
    describe "self.instances" do
      let (:packages) do
        <<-OPKG_OUTPUT
dropbear - 2011.54-2
kernel - 3.3.8-1-ba5cdb2523b4fc7722698b4a7ece6702
uhttpd - 2012-10-30-e57bf6d8bfa465a50eea2c30269acdfe751a46fd
OPKG_OUTPUT
      end
      it "returns an array of packages" do
        Puppet::Util.stubs(:which).with("opkg").returns("/bin/opkg")
        provider.stubs(:which).with("opkg").returns("/bin/opkg")
        provider.expects(:execpipe).with("/bin/opkg list-installed").yields(packages)

        installed_packages = provider.instances
        installed_packages.length.should == 3
  
        installed_packages[0].properties.should ==
          {
            :provider => :opkg,
            :name => "dropbear",
            :ensure => "2011.54-2"
          }
        installed_packages[1].properties.should ==
          {
            :provider => :opkg,
            :name => "kernel",
            :ensure => "3.3.8-1-ba5cdb2523b4fc7722698b4a7ece6702"
          }
        installed_packages[2].properties.should ==
          {
            :provider => :opkg,
            :name => "uhttpd",
            :ensure => "2012-10-30-e57bf6d8bfa465a50eea2c30269acdfe751a46fd"
          }
      end
    end

    it "should return a nil if the package isn't found" do
      Puppet::Util::Execution.expects(:execute).returns("")
      @provider.query.should be_nil
    end

    it "should return a hash indicating that the package is missing on error" do
      Puppet::Util::Execution.expects(:execute).raises(Puppet::ExecutionFailure.new("ERROR!"))
      @provider.query.should == {
        :ensure => :purged,
        :status => 'missing',
        :name => @resource[:name],
        :error => 'ok',
      }
    end
  end #end when querying

end # end describe provider
