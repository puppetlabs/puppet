#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

provider = Puppet::Type.type(:package).provider(:pkgutil)

describe provider do
  before(:each) do
    @resource = stub 'resource'
    @resource = Puppet::Type.type(:package).new(:name => "TESTpkg", :ensure => :present)
    @provider = provider.new(@resource)
  end

  it "should have an install method" do
    @provider.should respond_to(:install)
  end

  it "should have a latest method" do
    @provider.should respond_to(:uninstall)
  end

  it "should have an update method" do
    @provider.should respond_to(:update)
  end

  it "should have a latest method" do
    @provider.should respond_to(:latest)
  end

  describe "when installing" do
    it "should use a command without versioned package" do
      @resource[:ensure] = :latest
      @provider.expects(:pkguti).with('-y', '-i', 'TESTpkg')
      @provider.install
    end
  end

  describe "when updating" do
    it "should use a command without versioned package" do
      @provider.expects(:pkguti).with('-y', '-u', 'TESTpkg')
      @provider.update
    end
  end

  describe "when uninstalling" do
    it "should call the remove operation" do
      @provider.expects(:pkguti).with('-y', '-r', 'TESTpkg')
      @provider.uninstall
    end
  end

  describe "when getting latest version" do
    it "should return TESTpkg's version string" do
      fake_data = "
noisy output here
TESTpkg                   1.4.5,REV=2007.11.18      1.4.5,REV=2007.11.20"
      provider.expects(:pkguti).with(['-c', '--single', 'TESTpkg']).returns fake_data
      @provider.latest.should == "1.4.5,REV=2007.11.20"
    end

    it "should handle TESTpkg's 'SAME' version string" do
      fake_data = "
noisy output here
TESTpkg                   1.4.5,REV=2007.11.18      SAME"
      provider.expects(:pkguti).with(['-c', '--single', 'TESTpkg']).returns fake_data
      @provider.latest.should == "1.4.5,REV=2007.11.18"
    end

    it "should handle a non-existent package" do
      fake_data = "noisy output here"
      provider.expects(:pkguti).with(['-c', '--single', 'TESTpkg']).returns fake_data
      @provider.latest.should == nil
    end

    it "should warn on unknown pkgutil noise" do
      provider.expects(:pkguti).returns("testingnoise")
      Puppet.expects(:warning)
      provider.expects(:new).never
      provider.instances.should == []
    end

    it "should ignore pkgutil noise/headers to find TESTpkg" do
      fake_data = "# stuff
=> Fetching new catalog and descriptions (http://mirror.opencsw.org/opencsw/unstable/i386/5.11) if available ...
2011-02-19 23:05:46 URL:http://mirror.opencsw.org/opencsw/unstable/i386/5.11/catalog [534635/534635] -> \"/var/opt/csw/pkgutil/catalog.mirror.opencsw.org_opencsw_unstable_i386_5.11.tmp\" [1]
Checking integrity of /var/opt/csw/pkgutil/catalog.mirror.opencsw.org_opencsw_unstable_i386_5.11 with gpg.
gpg: Signature made February 17, 2011 05:27:53 PM GMT using DSA key ID E12E9D2F
gpg: Good signature from \"Distribution Manager <dm@blastwave.org>\"
==> 2770 packages loaded from /var/opt/csw/pkgutil/catalog.mirror.opencsw.org_opencsw_unstable_i386_5.11
package                   installed                 catalog
TESTpkg                   1.4.5,REV=2007.11.18      1.4.5,REV=2007.11.20"
      provider.expects(:pkguti).with(['-c', '--single', 'TESTpkg']).returns fake_data
      @provider.latest.should == "1.4.5,REV=2007.11.20"
    end
  end

  describe "when querying current version" do
    it "should return TESTpkg's version string" do
      fake_data = "TESTpkg  1.4.5,REV=2007.11.18  1.4.5,REV=2007.11.20"
      provider.expects(:pkguti).with(['-c', '--single', 'TESTpkg']).returns fake_data
      @provider.query[:ensure].should == "1.4.5,REV=2007.11.18"
    end

    it "should handle a package that isn't installed" do
      fake_data = "TESTpkg  notinst  1.4.5,REV=2007.11.20"
      provider.expects(:pkguti).with(['-c', '--single', 'TESTpkg']).returns fake_data
      @provider.query[:ensure].should == :absent
    end

    it "should handle a non-existent package" do
      fake_data = "noisy output here"
      provider.expects(:pkguti).with(['-c', '--single', 'TESTpkg']).returns fake_data
      @provider.query[:ensure].should == :absent
    end
  end

  describe "when querying current instances" do
    it "should return TESTpkg's version string" do
      fake_data = "TESTpkg  1.4.5,REV=2007.11.18  1.4.5,REV=2007.11.20"
      provider.expects(:pkguti).with(['-c']).returns fake_data

      testpkg = mock 'pkg1'
      provider.expects(:new).with(:ensure => "1.4.5,REV=2007.11.18", :name => "TESTpkg", :provider => :pkgutil).returns testpkg
      provider.instances.should == [testpkg]
    end
  end

end
