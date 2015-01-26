#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:selboolean).provider(:getsetsebool)

describe provider_class do
  before :each do
    @resource = stub("resource", :name => "foo")
    @resource.stubs(:[]).returns "foo"
    @provider = provider_class.new(@resource)
  end

  it "should return :on when getsebool returns on" do
    @provider.expects(:getsebool).with("foo").returns "foo --> on\n"
    expect(@provider.value).to eq(:on)
  end

  it "should return :off when getsebool returns on" do
    @provider.expects(:getsebool).with("foo").returns "foo --> off\n"
    expect(@provider.value).to eq(:off)
  end

  it "should call execpipe when updating boolean setting" do
    @provider.expects(:command).with(:setsebool).returns "/usr/sbin/setsebool"
    @provider.expects(:execpipe).with("/usr/sbin/setsebool  foo off")
    @provider.value = :off
  end

  it "should call execpipe with -P when updating persistent boolean setting" do
    @resource.stubs(:[]).with(:persistent).returns :true
    @provider.expects(:command).with(:setsebool).returns "/usr/sbin/setsebool"
    @provider.expects(:execpipe).with("/usr/sbin/setsebool -P foo off")
    @provider.value = :off
  end

end
