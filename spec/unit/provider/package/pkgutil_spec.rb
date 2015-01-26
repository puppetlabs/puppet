#! /usr/bin/env ruby
require 'spec_helper'

provider = Puppet::Type.type(:package).provider(:pkgutil)

describe provider do
  before(:each) do
    @resource = Puppet::Type.type(:package).new(
      :name     => "TESTpkg",
      :ensure   => :present,
      :provider => :pkgutil
    )
    @provider = provider.new(@resource)

    # Stub all file and config tests
    provider.stubs(:healthcheck)
  end

  it "should have an install method" do
    expect(@provider).to respond_to(:install)
  end

  it "should have a latest method" do
    expect(@provider).to respond_to(:uninstall)
  end

  it "should have an update method" do
    expect(@provider).to respond_to(:update)
  end

  it "should have a latest method" do
    expect(@provider).to respond_to(:latest)
  end

  describe "when installing" do
    it "should use a command without versioned package" do
      @resource[:ensure] = :latest
      @provider.expects(:pkguti).with('-y', '-i', 'TESTpkg')
      @provider.install
    end

    it "should support a single temp repo URL" do
      @resource[:ensure] = :latest
      @resource[:source] = "http://example.net/repo"
      @provider.expects(:pkguti).with('-t', 'http://example.net/repo', '-y', '-i', 'TESTpkg')
      @provider.install
    end

    it "should support multiple temp repo URLs as array" do
      @resource[:ensure] = :latest
      @resource[:source] = [ 'http://example.net/repo', 'http://example.net/foo' ]
      @provider.expects(:pkguti).with('-t', 'http://example.net/repo', '-t', 'http://example.net/foo', '-y', '-i', 'TESTpkg')
      @provider.install
    end
  end

  describe "when updating" do
    it "should use a command without versioned package" do
      @provider.expects(:pkguti).with('-y', '-u', 'TESTpkg')
      @provider.update
    end

    it "should support a single temp repo URL" do
      @resource[:source] = "http://example.net/repo"
      @provider.expects(:pkguti).with('-t', 'http://example.net/repo', '-y', '-u', 'TESTpkg')
      @provider.update
    end

    it "should support multiple temp repo URLs as array" do
      @resource[:source] = [ 'http://example.net/repo', 'http://example.net/foo' ]
      @provider.expects(:pkguti).with('-t', 'http://example.net/repo', '-t', 'http://example.net/foo', '-y', '-u', 'TESTpkg')
      @provider.update
    end
  end

  describe "when uninstalling" do
    it "should call the remove operation" do
      @provider.expects(:pkguti).with('-y', '-r', 'TESTpkg')
      @provider.uninstall
    end

    it "should support a single temp repo URL" do
      @resource[:source] = "http://example.net/repo"
      @provider.expects(:pkguti).with('-t', 'http://example.net/repo', '-y', '-r', 'TESTpkg')
      @provider.uninstall
    end

    it "should support multiple temp repo URLs as array" do
      @resource[:source] = [ 'http://example.net/repo', 'http://example.net/foo' ]
      @provider.expects(:pkguti).with('-t', 'http://example.net/repo', '-t', 'http://example.net/foo', '-y', '-r', 'TESTpkg')
      @provider.uninstall
    end
  end

  describe "when getting latest version" do
    it "should return TESTpkg's version string" do
      fake_data = "
noisy output here
TESTpkg                   1.4.5,REV=2007.11.18      1.4.5,REV=2007.11.20"
      provider.expects(:pkguti).with('-c', '--single', 'TESTpkg').returns fake_data
      expect(@provider.latest).to eq("1.4.5,REV=2007.11.20")
    end

    it "should support a temp repo URL" do
      @resource[:source] = "http://example.net/repo"
      fake_data = "
noisy output here
TESTpkg                   1.4.5,REV=2007.11.18      1.4.5,REV=2007.11.20"
      provider.expects(:pkguti).with('-t', 'http://example.net/repo', '-c', '--single', 'TESTpkg').returns fake_data
      expect(@provider.latest).to eq("1.4.5,REV=2007.11.20")
    end

    it "should handle TESTpkg's 'SAME' version string" do
      fake_data = "
noisy output here
TESTpkg                   1.4.5,REV=2007.11.18      SAME"
      provider.expects(:pkguti).with('-c', '--single', 'TESTpkg').returns fake_data
      expect(@provider.latest).to eq("1.4.5,REV=2007.11.18")
    end

    it "should handle a non-existent package" do
      fake_data = "noisy output here
Not in catalog"
      provider.expects(:pkguti).with('-c', '--single', 'TESTpkg').returns fake_data
      expect(@provider.latest).to eq(nil)
    end

    it "should warn on unknown pkgutil noise" do
      provider.expects(:pkguti).with('-c', '--single', 'TESTpkg').returns("testingnoise")
      expect(@provider.latest).to eq(nil)
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
      provider.expects(:pkguti).with('-c', '--single', 'TESTpkg').returns fake_data
      expect(@provider.latest).to eq("1.4.5,REV=2007.11.20")
    end

    it "should find REALpkg via an alias (TESTpkg)" do
      fake_data = "
noisy output here
REALpkg                   1.4.5,REV=2007.11.18      1.4.5,REV=2007.11.20"
      provider.expects(:pkguti).with('-c', '--single', 'TESTpkg').returns fake_data
      expect(@provider.query[:name]).to eq("TESTpkg")
    end
  end

  describe "when querying current version" do
    it "should return TESTpkg's version string" do
      fake_data = "TESTpkg  1.4.5,REV=2007.11.18  1.4.5,REV=2007.11.20"
      provider.expects(:pkguti).with('-c', '--single', 'TESTpkg').returns fake_data
      expect(@provider.query[:ensure]).to eq("1.4.5,REV=2007.11.18")
    end

    it "should handle a package that isn't installed" do
      fake_data = "TESTpkg  notinst  1.4.5,REV=2007.11.20"
      provider.expects(:pkguti).with('-c', '--single', 'TESTpkg').returns fake_data
      expect(@provider.query[:ensure]).to eq(:absent)
    end

    it "should handle a non-existent package" do
      fake_data = "noisy output here
Not in catalog"
      provider.expects(:pkguti).with('-c', '--single', 'TESTpkg').returns fake_data
      expect(@provider.query[:ensure]).to eq(:absent)
    end

    it "should support a temp repo URL" do
      @resource[:source] = "http://example.net/repo"
      fake_data = "TESTpkg  1.4.5,REV=2007.11.18  1.4.5,REV=2007.11.20"
      provider.expects(:pkguti).with('-t', 'http://example.net/repo', '-c', '--single', 'TESTpkg').returns fake_data
      expect(@provider.query[:ensure]).to eq("1.4.5,REV=2007.11.18")
    end
  end

  describe "when querying current instances" do
    it "should warn on unknown pkgutil noise" do
      provider.expects(:pkguti).with(['-a']).returns("testingnoise")
      provider.expects(:pkguti).with(['-c']).returns("testingnoise")
      Puppet.expects(:warning).times(2)
      provider.expects(:new).never
      expect(provider.instances).to eq([])
    end

    it "should return TESTpkg's version string" do
      fake_data = "TESTpkg  TESTpkg  1.4.5,REV=2007.11.20"
      provider.expects(:pkguti).with(['-a']).returns fake_data

      fake_data = "TESTpkg  1.4.5,REV=2007.11.18  1.4.5,REV=2007.11.20"
      provider.expects(:pkguti).with(['-c']).returns fake_data

      testpkg = mock 'pkg1'
      provider.expects(:new).with(:ensure => "1.4.5,REV=2007.11.18", :name => "TESTpkg", :provider => :pkgutil).returns testpkg
      expect(provider.instances).to eq([testpkg])
    end

    it "should also return both TESTpkg and mypkg alias instances" do
      fake_data = "mypkg  TESTpkg  1.4.5,REV=2007.11.20"
      provider.expects(:pkguti).with(['-a']).returns fake_data

      fake_data = "TESTpkg  1.4.5,REV=2007.11.18  1.4.5,REV=2007.11.20"
      provider.expects(:pkguti).with(['-c']).returns fake_data

      testpkg = mock 'pkg1'
      provider.expects(:new).with(:ensure => "1.4.5,REV=2007.11.18", :name => "TESTpkg", :provider => :pkgutil).returns testpkg

      aliaspkg = mock 'pkg2'
      provider.expects(:new).with(:ensure => "1.4.5,REV=2007.11.18", :name => "mypkg", :provider => :pkgutil).returns aliaspkg

      expect(provider.instances).to eq([testpkg,aliaspkg])
    end

    it "shouldn't mind noise in the -a output" do
      fake_data = "noisy output here"
      provider.expects(:pkguti).with(['-a']).returns fake_data

      fake_data = "TESTpkg  1.4.5,REV=2007.11.18  1.4.5,REV=2007.11.20"
      provider.expects(:pkguti).with(['-c']).returns fake_data

      testpkg = mock 'pkg1'
      provider.expects(:new).with(:ensure => "1.4.5,REV=2007.11.18", :name => "TESTpkg", :provider => :pkgutil).returns testpkg

      expect(provider.instances).to eq([testpkg])
    end
  end

end
