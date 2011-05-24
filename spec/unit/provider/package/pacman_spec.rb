#!/usr/bin/env rspec
require 'spec_helper'

provider = Puppet::Type.type(:package).provider(:pacman)

describe provider do
  before do
    provider.stubs(:command).with(:pacman).returns('/usr/bin/pacman')
    @resource = stub 'resource'
    @resource.stubs(:[]).returns("package")
    @resource.stubs(:name).returns("name")
    @provider = provider.new(@resource)
  end

  describe "when installing" do
    before do
      @provider.stubs(:query).returns({
        :ensure => '1.0'
      })
    end

    it "should call pacman" do
      provider.
        expects(:execute).
        at_least_once.
        with { |args|
          args[0] == "/usr/bin/pacman"
        }.
        returns ""

      @provider.install
    end

    it "should be quiet" do
      provider.
        expects(:execute).
        with { |args|
          args[1,2] == ["--noconfirm", "--noprogressbar"]
        }.
        returns("")

      @provider.install
    end

    it "should install the right package" do
      provider.
        expects(:execute).
        with { |args|
          args[3,4] == ["-Sy", @resource[0]]
        }.
        returns("")

      @provider.install
    end

    it "should raise an ExecutionFailure if the installation failed" do
      provider.stubs(:execute).returns("")
      @provider.expects(:query).returns(nil)

      lambda { @provider.install }.should raise_exception(Puppet::ExecutionFailure)
    end
  end

  describe "when updating" do
    it "should call install" do
      @provider.expects(:install).returns("install return value")
      @provider.update.should == "install return value"
    end
  end

  describe "when uninstalling" do
    it "should call pacman" do
      provider.
        expects(:execute).
        with { |args|
          args[0] == "/usr/bin/pacman"
        }.
        returns ""

      @provider.uninstall
    end

    it "should be quiet" do
      provider.
        expects(:execute).
        with { |args|
          args[1,2] == ["--noconfirm", "--noprogressbar"]
        }.
        returns("")

      @provider.uninstall
    end

    it "should remove the right package" do
      provider.
        expects(:execute).
        with { |args|
          args[3,4] == ["-R", @resource[0]]
        }.
        returns("")

      @provider.uninstall
    end
  end

  describe "when querying" do
    it "should query pacman" do
      provider.
        expects(:execute).
        with(["/usr/bin/pacman", "-Qi", @resource[0]])
      @provider.query
    end

    it "should return the version" do
      query_output = <<EOF
Name           : package
Version        : 1.01.3-2
URL            : http://www.archlinux.org/pacman/
Licenses       : GPL
Groups         : base
Provides       : None
Depends On     : bash  libarchive>=2.7.1  libfetch>=2.25  pacman-mirrorlist
Optional Deps  : fakeroot: for makepkg usage as normal user
                 curl: for rankmirrors usage
Required By    : None
Conflicts With : None
Replaces       : None
Installed Size : 2352.00 K
Packager       : Dan McGee <dan@archlinux.org>
Architecture   : i686
Build Date     : Sat 22 Jan 2011 03:56:41 PM EST
Install Date   : Thu 27 Jan 2011 06:45:49 AM EST
Install Reason : Explicitly installed
Install Script : Yes
Description    : A library-based package manager with dependency support
EOF

      provider.expects(:execute).returns(query_output)
      @provider.query.should == {:ensure => "1.01.3-2"}
    end

    it "should return a nil if the package isn't found" do
      provider.expects(:execute).returns("")
      @provider.query.should be_nil
    end

    it "should return a hash indicating that the package is missing on error" do
      provider.expects(:execute).raises(Puppet::ExecutionFailure.new("ERROR!"))
      @provider.query.should == {
        :ensure => :purged,
        :status => 'missing',
        :name => @resource[0],
        :error => 'ok',
      }
    end
  end

  describe "when fetching a package list" do
    it "should query pacman" do
      provider.expects(:execpipe).with(["/usr/bin/pacman", ' -Q'])
      provider.instances
    end

    it "should return installed packages with their versions" do
      provider.expects(:execpipe).yields("package1 1.23-4\npackage2 2.00\n")
      packages = provider.instances

      packages.length.should == 2

      packages[0].properties.should == {
        :provider => :pacman,
        :ensure => '1.23-4',
        :name => 'package1'
      }

      packages[1].properties.should == {
        :provider => :pacman,
        :ensure => '2.00',
        :name => 'package2'
      }
    end

    it "should return nil on error" do
      provider.expects(:execpipe).raises(Puppet::ExecutionFailure.new("ERROR!"))
      provider.instances.should be_nil
    end

    it "should warn on invalid input" do
      provider.expects(:execpipe).yields("blah")
      provider.expects(:warning).with("Failed to match line blah")
      provider.instances.should == []
    end
  end

  describe "when determining the latest version" do
    it "should refresh package list" do
      refreshed = states('refreshed').starts_as('unrefreshed')
      provider.
        expects(:execute).
        when(refreshed.is('unrefreshed')).
        with(['/usr/bin/pacman', '-Sy']).
        then(refreshed.is('refreshed'))

      provider.
        stubs(:execute).
        when(refreshed.is('refreshed')).
        returns("")

      @provider.latest
    end

    it "should get query pacman for the latest version" do
      refreshed = states('refreshed').starts_as('unrefreshed')
      provider.
        stubs(:execute).
        when(refreshed.is('unrefreshed')).
        then(refreshed.is('refreshed'))

      provider.
        expects(:execute).
        when(refreshed.is('refreshed')).
        with(['/usr/bin/pacman', '-Sp', '--print-format', '%v', @resource[0]]).
        returns("")

      @provider.latest
    end

    it "should return the version number from pacman" do
      provider.
        expects(:execute).
        at_least_once().
        returns("1.00.2-3\n")

      @provider.latest.should == "1.00.2-3"
    end
  end
end
