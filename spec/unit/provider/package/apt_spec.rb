#!/usr/bin/env rspec
require 'spec_helper'

provider = Puppet::Type.type(:package).provider(:apt)

describe provider do
  before do
    @resource = stub 'resource', :[] => "asdf"
    @provider = provider.new(@resource)

    @fakeresult = "install ok installed asdf 1.0\n"
  end

  it "should be versionable" do
    provider.should be_versionable
  end

  it "should use :install to update" do
    @provider.expects(:install)
    @provider.update
  end

  it "should use 'apt-get remove' to uninstall" do
    @provider.expects(:aptget).with("-y", "-q", :remove, "asdf")

    @provider.uninstall
  end

  it "should use 'apt-get purge' and 'dpkg purge' to purge" do
    @provider.expects(:aptget).with("-y", "-q", :remove, "--purge", "asdf")
    @provider.expects(:dpkg).with("--purge", "asdf")

    @provider.purge
  end

  it "should use 'apt-cache policy' to determine the latest version of a package" do
    @provider.expects(:aptcache).with(:policy, "asdf").returns "asdf:
Installed: 1:1.0
Candidate: 1:1.1
Version table:
1:1.0
  650 http://ftp.osuosl.org testing/main Packages
*** 1:1.1
  100 /var/lib/dpkg/status"

    @provider.latest.should == "1:1.1"
  end

  it "should print and error and return nil if no policy is found" do
    @provider.expects(:aptcache).with(:policy, "asdf").returns "asdf:"

    @provider.expects(:err)
    @provider.latest.should be_nil
  end

  it "should be able to preseed" do
    @provider.should respond_to(:run_preseed)
  end

  it "should preseed with the provided responsefile when preseeding is called for" do
    @resource.expects(:[]).with(:responsefile).returns "/my/file"
    FileTest.expects(:exist?).with("/my/file").returns true

    @provider.expects(:info)
    @provider.expects(:preseed).with("/my/file")

    @provider.run_preseed
  end

  it "should not preseed if no responsefile is provided" do
    @resource.expects(:[]).with(:responsefile).returns nil

    @provider.expects(:info)
    @provider.expects(:preseed).never

    @provider.run_preseed
  end

  it "should fail if a cdrom is listed in the sources list and :allowcdrom is not specified"

  describe "when installing" do
    it "should preseed if a responsefile is provided" do
      @resource.expects(:[]).with(:responsefile).returns "/my/file"
      @provider.expects(:run_preseed)

      @provider.stubs(:aptget)
      @provider.install
    end

    it "should check for a cdrom" do
      @provider.expects(:checkforcdrom)

      @provider.stubs(:aptget)
      @provider.install
    end

    it "should use 'apt-get install' with the package name if no version is asked for" do
      @resource.expects(:[]).with(:ensure).returns :installed
      @provider.expects(:aptget).with { |*command| command[-1] == "asdf" and command[-2] == :install }

      @provider.install
    end

    it "should specify the package version if one is asked for" do
      @resource.expects(:[]).with(:ensure).returns "1.0"
      @provider.expects(:aptget).with { |*command| command[-1] == "asdf=1.0" }

      @provider.install
    end

    it "should use --force-yes if a package version is specified" do
      @resource.expects(:[]).with(:ensure).returns "1.0"
      @provider.expects(:aptget).with { |*command| command.include?("--force-yes") }

      @provider.install
    end

    it "should do a quiet install" do
      @provider.expects(:aptget).with { |*command| command.include?("-q") }

      @provider.install
    end

    it "should default to 'yes' for all questions" do
      @provider.expects(:aptget).with { |*command| command.include?("-y") }

      @provider.install
    end

    it "should keep config files if asked" do
      @resource.expects(:[]).with(:configfiles).returns :keep
      @provider.expects(:aptget).with { |*command| command.include?("DPkg::Options::=--force-confold") }

      @provider.install
    end

    it "should replace config files if asked" do
      @resource.expects(:[]).with(:configfiles).returns :replace
      @provider.expects(:aptget).with { |*command| command.include?("DPkg::Options::=--force-confnew") }

      @provider.install
    end
  end
end
