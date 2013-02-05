#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:nim)

describe provider_class do
  context "when parsing nimclient showres output" do
    describe "#parse_showres_output" do
      it "should be able to parse installp/BFF package listings" do
        nimclient_showres_output = <<END
mypackage.foo                                                           ALL  @@I:mypackage.foo _all_filesets
 @ 1.2.3.1  MyPackage Runtime Environment                       @@I:mypackage.foo 1.2.3.1
 + 1.2.3.4  MyPackage Runtime Environment                       @@I:mypackage.foo 1.2.3.4
 + 1.2.3.8  MyPackage Runtime Environment                       @@I:mypackage.foo 1.2.3.8

END

        packages = subject.send(:parse_showres_output, nimclient_showres_output)
        Set.new(packages.keys).should == Set.new(['mypackage.foo'])
        versions = packages['mypackage.foo']
        ['1.2.3.1', '1.2.3.4', '1.2.3.8'].each do |version|
          versions.has_key?(version).should == true
          versions[version].should == :installp
        end
      end

      it "should be able to parse RPM package listings" do
        nimclient_showres_output = <<END
mypackage.foo                                                                ALL  @@R:mypackage.foo _all_filesets
 @@R:mypackage.foo-1.2.3-1 1.2.3-1
 @@R:mypackage.foo-1.2.3-4 1.2.3-4
 @@R:mypackage.foo-1.2.3-8 1.2.3-8

END

        packages = subject.send(:parse_showres_output, nimclient_showres_output)
        Set.new(packages.keys).should == Set.new(['mypackage.foo'])
        versions = packages['mypackage.foo']
        ['1.2.3-1', '1.2.3-4', '1.2.3-8'].each do |version|
          versions.has_key?(version).should == true
          versions[version].should == :rpm
        end
      end
    end
  end

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
    @provider.should respond_to(:install)
  end

  context "when installing" do
    it "should install a package" do
      @resource.stubs(:should).with(:ensure).returns(:installed)
      @provider.expects(:nimclient).with("-o", "cust", "-a", "installp_flags=acgwXY", "-a", "lpp_source=mysource", "-a", "filesets=mypackage.foo")
      @provider.install
    end

    context "when installing versioned packages" do

      it "should fail if the package is not available on the lpp source" do
        nimclient_showres_output = ""

        @resource.stubs(:should).with(:ensure).returns("1.2.3.4")
        Puppet::Util.expects(:execute).with("nimclient -o showres -a resource=mysource |grep -p -E 'mypackage\\.foo( |-)1\\.2\\.3\\.4'").returns(nimclient_showres_output)
        expect {
          @provider.install
        }.to raise_error(Puppet::Error, "Unable to find package 'mypackage.foo' with version '1.2.3.4' on lpp_source 'mysource'")
      end

      it "should succeed if a BFF/installp package is available on the lpp source" do
          nimclient_sequence = sequence('nimclient')

          nimclient_showres_output = <<END
mypackage.foo                                                           ALL  @@I:mypackage.foo _all_filesets
 @ 1.2.3.1  MyPackage Runtime Environment                       @@I:mypackage.foo 1.2.3.1
 + 1.2.3.4  MyPackage Runtime Environment                       @@I:mypackage.foo 1.2.3.4
 + 1.2.3.8  MyPackage Runtime Environment                       @@I:mypackage.foo 1.2.3.8

END

          @resource.stubs(:should).with(:ensure).returns("1.2.3.4")
          Puppet::Util.expects(:execute).with("nimclient -o showres -a resource=mysource |grep -p -E 'mypackage\\.foo( |-)1\\.2\\.3\\.4'").returns(nimclient_showres_output).in_sequence(nimclient_sequence)
          @provider.expects(:nimclient).with("-o", "cust", "-a", "installp_flags=acgwXY", "-a", "lpp_source=mysource", "-a", "filesets=mypackage.foo 1.2.3.4").in_sequence(nimclient_sequence)
          @provider.install
        end

      it "should succeed if an RPM package is available on the lpp source" do
        nimclient_sequence = sequence('nimclient')

        nimclient_showres_output = <<END
mypackage.foo                                                                ALL  @@R:mypackage.foo _all_filesets
 @@R:mypackage.foo-1.2.3-1 1.2.3-1
 @@R:mypackage.foo-1.2.3-4 1.2.3-4
 @@R:mypackage.foo-1.2.3-8 1.2.3-8

END

        @resource.stubs(:should).with(:ensure).returns("1.2.3-4")
        Puppet::Util.expects(:execute).with("nimclient -o showres -a resource=mysource |grep -p -E 'mypackage\\.foo( |-)1\\.2\\.3\\-4'").returns(nimclient_showres_output).in_sequence(nimclient_sequence)
        @provider.expects(:nimclient).with("-o", "cust", "-a", "installp_flags=acgwXY", "-a", "lpp_source=mysource", "-a", "filesets=mypackage.foo-1.2.3-4").in_sequence(nimclient_sequence)
        @provider.install
      end

    end
  end

  context "when uninstalling" do
    it "should call installp to uninstall a bff package" do
      #@resource.stubs(:should).with(:ensure).returns(:installed)
      @provider.expects(:lslpp).with("-qLc", "mypackage.foo").returns("#bos.atm:bos.atm.atmle:7.1.2.0: : :C: :ATM LAN Emulation Client Support : : : : : : :0:0:/:1241")
      @provider.expects(:installp).with("-gu", "mypackage.foo")
      @provider.uninstall
    end

    it "should call rpm to uninstall an rpm package" do
      @provider.expects(:lslpp).with("-qLc", "mypackage.foo").returns("cdrecord:cdrecord-1.9-6:1.9-6: : :C:R:A command line CD/DVD recording program.: :/bin/rpm -e cdrecord: : : : :0: :/opt/freeware:Wed Jun 29 09:41:32 PDT 2005")
      @provider.expects(:rpm).with("-e", "mypackage.foo")
      @provider.uninstall
    end

  end
end
