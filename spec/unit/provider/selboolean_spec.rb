require 'spec_helper'

provider_class = Puppet::Type.type(:selboolean).provider(:getsetsebool)

describe provider_class do
  before :each do
    @resource = double("resource", :name => "foo")
    allow(@resource).to receive(:[]).and_return("foo")
    @provider = provider_class.new(@resource)
  end

  it "should return :on when getsebool returns on" do
    expect(@provider).to receive(:getsebool).with("foo").and_return("foo --> on\n")
    expect(@provider.value).to eq(:on)
  end

  it "should return :off when getsebool returns on" do
    expect(@provider).to receive(:getsebool).with("foo").and_return("foo --> off\n")
    expect(@provider.value).to eq(:off)
  end

  it "should call execpipe when updating boolean setting" do
    expect(@provider).to receive(:command).with(:setsebool).and_return("/usr/sbin/setsebool")
    expect(@provider).to receive(:execpipe).with("/usr/sbin/setsebool  foo off")
    @provider.value = :off
  end

  it "should call execpipe with -P when updating persistent boolean setting" do
    allow(@resource).to receive(:[]).with(:persistent).and_return(:true)
    expect(@provider).to receive(:command).with(:setsebool).and_return("/usr/sbin/setsebool")
    expect(@provider).to receive(:execpipe).with("/usr/sbin/setsebool -P foo off")
    @provider.value = :off
  end
end
