#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:nim)

describe provider_class do

  before(:each) do
    # Create a mock resource
    @resource = stub 'resource'

    # A catch all; no parameters set
    @resource.stubs(:[]).returns(nil)

    # But set name and source
    @resource.stubs(:[]).with(:name).returns "mypackage.foo"
    @resource.stubs(:[]).with(:source).returns "mysource"
    @resource.stubs(:[]).with(:ensure).returns :installed

    @provider = provider_class.new
    @provider.resource = @resource
  end

  it "should have an install method" do
    @provider = provider_class.new
    expect(@provider).to respond_to(:install)
  end

  let(:bff_showres_output) {
    <<END
mypackage.foo                                                           ALL  @@I:mypackage.foo _all_filesets
 @ 1.2.3.1  MyPackage Runtime Environment                       @@I:mypackage.foo 1.2.3.1
 + 1.2.3.4  MyPackage Runtime Environment                       @@I:mypackage.foo 1.2.3.4
 + 1.2.3.8  MyPackage Runtime Environment                       @@I:mypackage.foo 1.2.3.8

END
  }

  let(:rpm_showres_output) {
    <<END
mypackage.foo                                                                ALL  @@R:mypackage.foo _all_filesets
 @@R:mypackage.foo-1.2.3-1 1.2.3-1
 @@R:mypackage.foo-1.2.3-4 1.2.3-4
 @@R:mypackage.foo-1.2.3-8 1.2.3-8

END
  }

  context "when installing" do
    it "should install a package" do

      @resource.stubs(:should).with(:ensure).returns(:installed)
      Puppet::Util::Execution.expects(:execute).with("/usr/sbin/nimclient -o showres -a resource=mysource |/usr/bin/grep -p -E 'mypackage\\.foo'").returns(bff_showres_output)
      @provider.expects(:nimclient).with("-o", "cust", "-a", "installp_flags=acgwXY", "-a", "lpp_source=mysource", "-a", "filesets=mypackage.foo 1.2.3.8")
      @provider.install
    end

    context "when installing versioned packages" do

      it "should fail if the package is not available on the lpp source" do
        nimclient_showres_output = ""

        @resource.stubs(:should).with(:ensure).returns("1.2.3.4")
        Puppet::Util::Execution.expects(:execute).with("/usr/sbin/nimclient -o showres -a resource=mysource |/usr/bin/grep -p -E 'mypackage\\.foo( |-)1\\.2\\.3\\.4'").returns(nimclient_showres_output)
        expect {
          @provider.install
        }.to raise_error(Puppet::Error, "Unable to find package 'mypackage.foo' with version '1.2.3.4' on lpp_source 'mysource'")
      end

      it "should succeed if a BFF/installp package is available on the lpp source" do
        nimclient_sequence = sequence('nimclient')

        @resource.stubs(:should).with(:ensure).returns("1.2.3.4")
        Puppet::Util::Execution.expects(:execute).with("/usr/sbin/nimclient -o showres -a resource=mysource |/usr/bin/grep -p -E 'mypackage\\.foo( |-)1\\.2\\.3\\.4'").returns(bff_showres_output).in_sequence(nimclient_sequence)
        @provider.expects(:nimclient).with("-o", "cust", "-a", "installp_flags=acgwXY", "-a", "lpp_source=mysource", "-a", "filesets=mypackage.foo 1.2.3.4").in_sequence(nimclient_sequence)
        @provider.install
      end

      it "should fail if the specified version of a BFF package is superseded" do
        nimclient_sequence = sequence('nimclient')

        install_output = <<OUTPUT
+-----------------------------------------------------------------------------+
                    Pre-installation Verification...
+-----------------------------------------------------------------------------+
Verifying selections...done
Verifying requisites...done
Results...

WARNINGS
--------
  Problems described in this section are not likely to be the source of any
  immediate or serious failures, but further actions may be necessary or
  desired.

  Already Installed
  -----------------
  The number of selected filesets that are either already installed
  or effectively installed through superseding filesets is 1.  See
  the summaries at the end of this installation for details.

  NOTE:  Base level filesets may be reinstalled using the "Force"
  option (-F flag), or they may be removed, using the deinstall or
  "Remove Software Products" facility (-u flag), and then reinstalled.

  << End of Warning Section >>

+-----------------------------------------------------------------------------+
                   BUILDDATE Verification ...
+-----------------------------------------------------------------------------+
Verifying build dates...done
FILESET STATISTICS
------------------
    1  Selected to be installed, of which:
        1  Already installed (directly or via superseding filesets)
  ----
    0  Total to be installed


Pre-installation Failure/Warning Summary
----------------------------------------
Name                      Level           Pre-installation Failure/Warning
-------------------------------------------------------------------------------
mypackage.foo              1.2.3.1         Already superseded by 1.2.3.4
OUTPUT

        @resource.stubs(:should).with(:ensure).returns("1.2.3.1")
        Puppet::Util::Execution.expects(:execute).with("/usr/sbin/nimclient -o showres -a resource=mysource |/usr/bin/grep -p -E 'mypackage\\.foo( |-)1\\.2\\.3\\.1'").returns(bff_showres_output).in_sequence(nimclient_sequence)
        @provider.expects(:nimclient).with("-o", "cust", "-a", "installp_flags=acgwXY", "-a", "lpp_source=mysource", "-a", "filesets=mypackage.foo 1.2.3.1").in_sequence(nimclient_sequence).returns(install_output)

        expect { @provider.install }.to raise_error(Puppet::Error, "NIM package provider is unable to downgrade packages")
    end


    it "should succeed if an RPM package is available on the lpp source" do
        nimclient_sequence = sequence('nimclient')

        @resource.stubs(:should).with(:ensure).returns("1.2.3-4")
        Puppet::Util::Execution.expects(:execute).with("/usr/sbin/nimclient -o showres -a resource=mysource |/usr/bin/grep -p -E 'mypackage\\.foo( |-)1\\.2\\.3\\-4'").returns(rpm_showres_output).in_sequence(nimclient_sequence)
        @provider.expects(:nimclient).with("-o", "cust", "-a", "installp_flags=acgwXY", "-a", "lpp_source=mysource", "-a", "filesets=mypackage.foo-1.2.3-4").in_sequence(nimclient_sequence)
        @provider.install
      end
    end

    it "should fail if the specified version of a RPM package is superseded" do
      nimclient_sequence = sequence('nimclient')

      install_output = <<OUTPUT


Validating RPM package selections ...

Please wait...
+-----------------------------------------------------------------------------+
                          RPM  Error Summary:
+-----------------------------------------------------------------------------+
The following RPM packages were requested for installation
but they are already installed or superseded by a package installed
at a higher level:
mypackage.foo-1.2.3-1 is superseded by mypackage.foo-1.2.3-4


OUTPUT

      @resource.stubs(:should).with(:ensure).returns("1.2.3-1")
      Puppet::Util::Execution.expects(:execute).with("/usr/sbin/nimclient -o showres -a resource=mysource |/usr/bin/grep -p -E 'mypackage\\.foo( |-)1\\.2\\.3\\-1'").returns(rpm_showres_output).in_sequence(nimclient_sequence)
      @provider.expects(:nimclient).with("-o", "cust", "-a", "installp_flags=acgwXY", "-a", "lpp_source=mysource", "-a", "filesets=mypackage.foo-1.2.3-1").in_sequence(nimclient_sequence).returns(install_output)

      expect { @provider.install }.to raise_error(Puppet::Error, "NIM package provider is unable to downgrade packages")
    end



  end

  context "when uninstalling" do
    it "should call installp to uninstall a bff package" do
      @provider.expects(:lslpp).with("-qLc", "mypackage.foo").returns("#bos.atm:bos.atm.atmle:7.1.2.0: : :C: :ATM LAN Emulation Client Support : : : : : : :0:0:/:1241")
      @provider.expects(:installp).with("-gu", "mypackage.foo")
      @provider.class.expects(:pkglist).with(:pkgname => 'mypackage.foo').returns(nil)
      @provider.uninstall
    end

    it "should call rpm to uninstall an rpm package" do
      @provider.expects(:lslpp).with("-qLc", "mypackage.foo").returns("cdrecord:cdrecord-1.9-6:1.9-6: : :C:R:A command line CD/DVD recording program.: :/bin/rpm -e cdrecord: : : : :0: :/opt/freeware:Wed Jun 29 09:41:32 PDT 2005")
      @provider.expects(:rpm).with("-e", "mypackage.foo")
      @provider.class.expects(:pkglist).with(:pkgname => 'mypackage.foo').returns(nil)
      @provider.uninstall
    end

  end


  context "when parsing nimclient showres output" do
    describe "#parse_showres_output" do
      it "should be able to parse installp/BFF package listings" do
        packages = subject.send(:parse_showres_output, bff_showres_output)
        expect(Set.new(packages.keys)).to eq(Set.new(['mypackage.foo']))
        versions = packages['mypackage.foo']
        ['1.2.3.1', '1.2.3.4', '1.2.3.8'].each do |version|
          expect(versions.has_key?(version)).to eq(true)
          expect(versions[version]).to eq(:installp)
        end
      end

      it "should be able to parse RPM package listings" do
        packages = subject.send(:parse_showres_output, rpm_showres_output)
        expect(Set.new(packages.keys)).to eq(Set.new(['mypackage.foo']))
        versions = packages['mypackage.foo']
        ['1.2.3-1', '1.2.3-4', '1.2.3-8'].each do |version|
          expect(versions.has_key?(version)).to eq(true)
          expect(versions[version]).to eq(:rpm)
        end
      end
    end

    describe "#determine_latest_version" do
      context "when there are multiple versions" do
        it "should return the latest version" do
          expect(subject.send(:determine_latest_version, rpm_showres_output, 'mypackage.foo')).to eq([:rpm, '1.2.3-8'])
        end
      end

      context "when there is only one version" do
        it "should return the type specifier and `nil` for the version number" do
          nimclient_showres_output = <<END
mypackage.foo                                                                ALL  @@R:mypackage.foo _all_filesets
 @@R:mypackage.foo-1.2.3-4 1.2.3-4

END
          expect(subject.send(:determine_latest_version, nimclient_showres_output, 'mypackage.foo')).to eq([:rpm, nil])
        end
      end

    end

    describe "#determine_package_type" do
      it "should return :rpm for rpm packages" do
        expect(subject.send(:determine_package_type, rpm_showres_output, 'mypackage.foo', '1.2.3-4')).to eq(:rpm)
      end

      it "should return :installp for installp/bff packages" do
        expect(subject.send(:determine_package_type, bff_showres_output, 'mypackage.foo', '1.2.3.4')).to eq(:installp)
      end
    end
  end



end
