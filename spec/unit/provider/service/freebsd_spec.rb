#!/usr/bin/env rspec
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

  it "should find the right rcvar_value for FreeBSD < 7" do
    @provider.stubs(:rcvar).returns(['# ntpd', 'ntpd_enable=YES'])

    @provider.rcvar_value.should == "YES"
  end

  it "should find the right rcvar_value for FreeBSD >= 7" do
    @provider.stubs(:rcvar).returns(['# ntpd', 'ntpd_enable="YES"', '#   (default: "")'])

    @provider.rcvar_value.should == "YES"
  end
end
