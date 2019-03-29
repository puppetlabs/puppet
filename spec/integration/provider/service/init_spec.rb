require 'spec_helper'

provider = Puppet::Type.type(:service).provider(:init)

describe provider do
  describe "when running on FreeBSD" do
    before :each do
      allow(Facter).to receive(:value).with(:operatingsystem).and_return('FreeBSD')
    end

    it "should set its default path to include /etc/rc.d and /usr/local/etc/rc.d" do
      expect(provider.defpath).to eq(["/etc/rc.d", "/usr/local/etc/rc.d"])
    end
  end

  describe "when running on HP-UX" do
    before :each do
      allow(Facter).to receive(:value).with(:operatingsystem).and_return('HP-UX')
    end

    it "should set its default path to include /sbin/init.d" do
      expect(provider.defpath).to eq("/sbin/init.d")
    end
  end

  describe "when running on Archlinux" do
    before :each do
      allow(Facter).to receive(:value).with(:operatingsystem).and_return('Archlinux')
    end

    it "should set its default path to include /etc/rc.d" do
      expect(provider.defpath).to eq("/etc/rc.d")
    end
  end

  describe "when not running on FreeBSD, HP-UX or Archlinux" do
    before :each do
      allow(Facter).to receive(:value).with(:operatingsystem).and_return('RedHat')
    end

    it "should set its default path to include /etc/init.d" do
      expect(provider.defpath).to eq("/etc/init.d")
    end
  end
end
