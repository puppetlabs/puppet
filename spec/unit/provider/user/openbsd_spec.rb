require 'spec_helper'

describe Puppet::Type.type(:user).provider(:openbsd) do
  before :each do
    allow(described_class).to receive(:command).with(:password).and_return('/usr/sbin/passwd')
    allow(described_class).to receive(:command).with(:add).and_return('/usr/sbin/useradd')
    allow(described_class).to receive(:command).with(:modify).and_return('/usr/sbin/usermod')
    allow(described_class).to receive(:command).with(:delete).and_return('/usr/sbin/userdel')
  end

  let(:resource) do
    Puppet::Type.type(:user).new(
      :name       => 'myuser',
      :managehome => :false,
      :system     => :false,
      :loginclass => 'staff',
      :provider   => provider
    )
  end

  let(:provider) { described_class.new(:name => 'myuser') }

  let(:shadow_entry) {
    return unless Puppet.features.libshadow?
    entry = Etc::PasswdEntry.new
    entry[:sp_namp]   = 'myuser' # login name
    entry[:sp_loginclass] = 'staff' # login class
    entry
  }

  describe "#expiry=" do
    it "should pass expiry to usermod as MM/DD/YY" do
      resource[:expiry] = '2014-11-05'
      expect(provider).to receive(:execute).with(['/usr/sbin/usermod', '-e', 'November 05 2014', 'myuser'], hash_including(custom_environment: {}))
      provider.expiry = '2014-11-05'
    end

    it "should use -e with an empty string when the expiry property is removed" do
      resource[:expiry] = :absent
      expect(provider).to receive(:execute).with(['/usr/sbin/usermod', '-e', '', 'myuser'], hash_including(custom_environment: {}))
      provider.expiry = :absent
    end
  end

  describe "#addcmd" do
    it "should return an array with the full command and expiry as MM/DD/YY" do
      allow(Facter).to receive(:value).with('os.family').and_return('OpenBSD')
      allow(Facter).to receive(:value).with('os.release.major')
      resource[:expiry] = "1997-06-01"
      expect(provider.addcmd).to eq(['/usr/sbin/useradd', '-e', 'June 01 1997', 'myuser'])
    end
  end

  describe "#loginclass" do
    before :each do
      resource
    end

    it "should return the loginclass if set", :if => Puppet.features.libshadow? do
      expect(Shadow::Passwd).to receive(:getspnam).with('myuser').and_return(shadow_entry)
      provider.send(:loginclass).should == 'staff'
    end

    it "should return the empty string when loginclass isn't set", :if => Puppet.features.libshadow? do
      shadow_entry[:sp_loginclass] = ''
      expect(Shadow::Passwd).to receive(:getspnam).with('myuser').and_return(shadow_entry)
      provider.send(:loginclass).should == ''
    end

    it "should return nil when loginclass isn't available", :if => Puppet.features.libshadow? do
      shadow_entry[:sp_loginclass] = nil
      expect(Shadow::Passwd).to receive(:getspnam).with('myuser').and_return(shadow_entry)
      provider.send(:loginclass).should be_nil
    end
  end
end
