require 'spec_helper'
if Puppet::Util::Platform.windows?
  require 'puppet/util/windows'
  class WindowsSecurity
    extend Puppet::Util::Windows::Security
  end
end

describe Puppet::Type.type(:file).provider(:windows), :if => Puppet::Util::Platform.windows? do
  include PuppetSpec::Files

  let(:path) { tmpfile('windows_file_spec') }
  let(:resource) { Puppet::Type.type(:file).new :path => path, :mode => '0777', :provider => described_class.name }
  let(:provider) { resource.provider }
  let(:sid)      { 'S-1-1-50' }
  let(:account)  { 'quinn' }

  describe "#mode" do
    it "should return a string representing the mode in 4-digit octal notation" do
      FileUtils.touch(path)
      WindowsSecurity.set_mode(0644, path)

      expect(provider.mode).to eq('0644')
    end

    it "should return absent if the file doesn't exist" do
      expect(provider.mode).to eq(:absent)
    end
  end

  describe "#mode=" do
    it "should chmod the file to the specified value" do
      FileUtils.touch(path)
      WindowsSecurity.set_mode(0644, path)

      provider.mode = '0755'

      expect(provider.mode).to eq('0755')
    end

    it "should pass along any errors encountered" do
      expect do
        provider.mode = '0644'
      end.to raise_error(Puppet::Error, /failed to set mode/)
    end
  end

  describe "#id2name" do
    it "should return the name of the user identified by the sid" do
      expect(Puppet::Util::Windows::SID).to receive(:valid_sid?).with(sid).and_return(true)
      expect(Puppet::Util::Windows::SID).to receive(:sid_to_name).with(sid).and_return(account)

      expect(provider.id2name(sid)).to eq(account)
    end

    it "should return the argument if it's already a name" do
      expect(Puppet::Util::Windows::SID).to receive(:valid_sid?).with(account).and_return(false)
      expect(Puppet::Util::Windows::SID).not_to receive(:sid_to_name)

      expect(provider.id2name(account)).to eq(account)
    end

    it "should return nil if the user doesn't exist" do
      expect(Puppet::Util::Windows::SID).to receive(:valid_sid?).with(sid).and_return(true)
      expect(Puppet::Util::Windows::SID).to receive(:sid_to_name).with(sid).and_return(nil)

      expect(provider.id2name(sid)).to eq(nil)
    end
  end

  describe "#name2id" do
    it "should delegate to name_to_sid" do
      expect(Puppet::Util::Windows::SID).to receive(:name_to_sid).with(account).and_return(sid)

      expect(provider.name2id(account)).to eq(sid)
    end
  end

  describe "#owner" do
    it "should return the sid of the owner if the file does exist" do
      FileUtils.touch(resource[:path])
      allow(provider).to receive(:get_owner).with(resource[:path]).and_return(sid)

      expect(provider.owner).to eq(sid)
    end

    it "should return absent if the file doesn't exist" do
      expect(provider.owner).to eq(:absent)
    end
  end

  describe "#owner=" do
    it "should set the owner to the specified value" do
      expect(provider).to receive(:set_owner).with(sid, resource[:path])
      provider.owner = sid
    end

    it "should propagate any errors encountered when setting the owner" do
      allow(provider).to receive(:set_owner).and_raise(ArgumentError)

      expect {
        provider.owner = sid
      }.to raise_error(Puppet::Error, /Failed to set owner/)
    end
  end

  describe "#group" do
    it "should return the sid of the group if the file does exist" do
      FileUtils.touch(resource[:path])
      allow(provider).to receive(:get_group).with(resource[:path]).and_return(sid)

      expect(provider.group).to eq(sid)
    end

    it "should return absent if the file doesn't exist" do
      expect(provider.group).to eq(:absent)
    end
  end

  describe "#group=" do
    it "should set the group to the specified value" do
      expect(provider).to receive(:set_group).with(sid, resource[:path])
      provider.group = sid
    end

    it "should propagate any errors encountered when setting the group" do
      allow(provider).to receive(:set_group).and_raise(ArgumentError)

      expect {
        provider.group = sid
      }.to raise_error(Puppet::Error, /Failed to set group/)
    end
  end

  describe "when validating" do
    {:owner => 'foo', :group => 'foo', :mode => '0777'}.each do |k,v|
      it "should fail if the filesystem doesn't support ACLs and we're managing #{k}" do
        allow_any_instance_of(described_class).to receive(:supports_acl?).and_return(false)

        expect {
          Puppet::Type.type(:file).new :path => path, k => v
        }.to raise_error(Puppet::Error, /Can only manage owner, group, and mode on filesystems that support Windows ACLs, such as NTFS/)
      end
    end

    it "should not fail if the filesystem doesn't support ACLs and we're not managing permissions" do
      allow_any_instance_of(described_class).to receive(:supports_acl?).and_return(false)

      Puppet::Type.type(:file).new :path => path
    end
  end
end
