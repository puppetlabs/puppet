#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:service).provider(:freebsd)

describe provider_class do
  before :each do
    @provider = provider_class.new
    @provider.stubs(:initscript)
  end

  it "should correctly parse rcvar for FreeBSD < 7" do
    @provider.stubs(:execute).returns <<OUTPUT
# ntpd
$ntpd_enable=YES
OUTPUT
    @provider.rcvar.should == ['# ntpd', 'ntpd_enable=YES']
  end

  it "should correctly parse rcvar for FreeBSD 7 to 8" do
    @provider.stubs(:execute).returns <<OUTPUT
# ntpd
ntpd_enable=YES
OUTPUT
    @provider.rcvar.should == ['# ntpd', 'ntpd_enable=YES']
  end

  it "should correctly parse rcvar for FreeBSD >= 8.1" do
    @provider.stubs(:execute).returns <<OUTPUT
# ntpd
#
ntpd_enable="YES"
#   (default: "")
OUTPUT
    @provider.rcvar.should == ['# ntpd', 'ntpd_enable="YES"', '#   (default: "")']
  end

  it "should correctly parse rcvar for DragonFly BSD" do
    @provider.stubs(:execute).returns <<OUTPUT
# ntpd
$ntpd=YES
OUTPUT
    @provider.rcvar.should == ['# ntpd', 'ntpd=YES']
  end

  it "should find the right rcvar_value for FreeBSD < 7" do
    @provider.stubs(:rcvar).returns(['# ntpd', 'ntpd_enable=YES'])

    @provider.rcvar_value.should == "YES"
  end

  it "should find the right rcvar_value for FreeBSD >= 7" do
    @provider.stubs(:rcvar).returns(['# ntpd', 'ntpd_enable="YES"', '#   (default: "")'])

    @provider.rcvar_value.should == "YES"
  end

  it "should find the right rcvar_name" do
    @provider.stubs(:rcvar).returns(['# ntpd', 'ntpd_enable="YES"'])

    @provider.rcvar_name.should == "ntpd"
  end

  it "should enable only the selected service" do
    Puppet::FileSystem.stubs(:exist?).with('/etc/rc.conf').returns(true)
    File.stubs(:read).with('/etc/rc.conf').returns("openntpd_enable=\"NO\"\nntpd_enable=\"NO\"\n")
    fh = stub 'fh'
    File.stubs(:open).with('/etc/rc.conf', File::WRONLY).yields(fh)
    fh.expects(:<<).with("openntpd_enable=\"NO\"\nntpd_enable=\"YES\"\n")
    Puppet::FileSystem.stubs(:exist?).with('/etc/rc.conf.local').returns(false)
    Puppet::FileSystem.stubs(:exist?).with('/etc/rc.conf.d/ntpd').returns(false)

    @provider.rc_replace('ntpd', 'ntpd', 'YES')
  end
end
