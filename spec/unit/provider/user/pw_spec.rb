require 'spec_helper'
require 'open3'

RSpec::Matchers.define_negated_matcher :excluding, :include

describe Puppet::Type.type(:user).provider(:pw) do
  let :resource do
    Puppet::Type.type(:user).new(:name => "testuser", :provider => :pw)
  end

  context "when creating users" do
    let :provider do
      prov = resource.provider
      expect(prov).to receive(:exists?).and_return(nil)
      prov
    end

    it "should run pw with no additional flags when no properties are given" do
      expect(provider.addcmd).to eq([described_class.command(:pw), "useradd", "testuser"])
      expect(provider).to receive(:execute).with([described_class.command(:pw), "useradd", "testuser"], kind_of(Hash))
      provider.create
    end

    it "should use -o when allowdupe is enabled" do
      resource[:allowdupe] = true
      expect(provider).to receive(:execute).with(include("-o"), kind_of(Hash))
      provider.create
    end

    it "should use -c with the correct argument when the comment property is set" do
      resource[:comment] = "Testuser Name"
      expect(provider).to receive(:execute).with(include("-c").and(include("Testuser Name")), kind_of(Hash))
      provider.create
    end

    it "should use -e with the correct argument when the expiry property is set" do
      resource[:expiry] = "2010-02-19"
      expect(provider).to receive(:execute).with(include("-e").and(include("19-02-2010")), kind_of(Hash))
      provider.create
    end

    it "should use -e 00-00-0000 if the expiry property has to be removed" do
      resource[:expiry] = :absent
      expect(provider).to receive(:execute).with(include("-e").and(include("00-00-0000")), kind_of(Hash))
      provider.create
    end

    it "should use -g with the correct argument when the gid property is set" do
      resource[:gid] = 12345
      expect(provider).to receive(:execute).with(include("-g").and(include(12345)), kind_of(Hash))
      provider.create
    end

    it "should use -G with the correct argument when the groups property is set" do
      resource[:groups] = "group1"
      allow(Puppet::Util::POSIX).to receive(:groups_of).with('testuser').and_return([])
      expect(provider).to receive(:execute).with(include("-G").and(include("group1")), kind_of(Hash))
      provider.create
    end

    it "should use -G with all the given groups when the groups property is set to an array" do
      resource[:groups] = ["group1", "group2"]
      allow(Puppet::Util::POSIX).to receive(:groups_of).with('testuser').and_return([])
      expect(provider).to receive(:execute).with(include("-G").and(include("group1,group2")), kind_of(Hash))
      provider.create
    end

    it "should use -d with the correct argument when the home property is set" do
      resource[:home] = "/home/testuser"
      expect(provider).to receive(:execute).with(include("-d").and(include("/home/testuser")), kind_of(Hash))
      provider.create
    end

    it "should use -m when the managehome property is enabled" do
      resource[:managehome] = true
      expect(provider).to receive(:execute).with(include("-m"), kind_of(Hash))
      provider.create
    end

    it "should call the password set function with the correct argument when the password property is set" do
      resource[:password] = "*"
      expect(provider).to receive(:execute)
      expect(provider).to receive(:password=).with("*")
      provider.create
    end

    it "should call execute with sensitive true when the password property is set" do
      Puppet::Util::Log.level = :debug
      resource[:password] = "abc123"
      expect(provider).to receive(:execute).with(kind_of(Array), hash_including(sensitive: true))
      popen = double("popen", :puts => nil, :close => nil)
      expect(Open3).to receive(:popen3).and_return(popen)
      expect(popen).to receive(:puts).with("abc123")
      provider.create
      expect(@logs).not_to be_any {|log| log.level == :debug and log.message =~ /abc123/}
    end

    it "should call execute with sensitive false when a non-sensitive property is set" do
      resource[:managehome] = true
      expect(provider).to receive(:execute).with(kind_of(Array), hash_including(sensitive: false))
      provider.create
    end

    it "should use -s with the correct argument when the shell property is set" do
      resource[:shell] = "/bin/sh"
      expect(provider).to receive(:execute).with(include("-s").and(include("/bin/sh")), kind_of(Hash))
      provider.create
    end

    it "should use -u with the correct argument when the uid property is set" do
      resource[:uid] = 12345
      expect(provider).to receive(:execute).with(include("-u").and(include(12345)), kind_of(Hash))
      provider.create
    end

    # (#7500) -p should not be used to set a password (it means something else)
    it "should not use -p when a password is given" do
      resource[:password] = "*"
      expect(provider.addcmd).not_to include("-p")
      expect(provider).to receive(:password=)
      expect(provider).to receive(:execute).with(excluding("-p"), kind_of(Hash))
      provider.create
    end
  end

  context "when deleting users" do
    it "should run pw with no additional flags" do
      provider = resource.provider
      expect(provider).to receive(:exists?).and_return(true)
      expect(provider.deletecmd).to eq([described_class.command(:pw), "userdel", "testuser"])
      expect(provider).to receive(:execute).with([described_class.command(:pw), "userdel", "testuser"], hash_including(custom_environment: {}))
      provider.delete
    end

    # The above test covers this, but given the consequences of
    # accidentally deleting a user's home directory it seems better to
    # have an explicit test.
    it "should not use -r when managehome is not set" do
      provider = resource.provider
      expect(provider).to receive(:exists?).and_return(true)
      resource[:managehome] = false
      expect(provider).to receive(:execute).with(excluding("-r"), hash_including(custom_environment: {}))
      provider.delete
    end

    it "should use -r when managehome is set" do
      provider = resource.provider
      expect(provider).to receive(:exists?).and_return(true)
      resource[:managehome] = true
      expect(provider).to receive(:execute).with(include("-r"), hash_including(custom_environment: {}))
      provider.delete
    end
  end

  context "when modifying users" do
    let :provider do
      resource.provider
    end

    it "should run pw with the correct arguments" do
      expect(provider.modifycmd("uid", 12345)).to eq([described_class.command(:pw), "usermod", "testuser", "-u", 12345])
      expect(provider).to receive(:execute).with([described_class.command(:pw), "usermod", "testuser", "-u", 12345], hash_including(custom_environment: {}))
      provider.uid = 12345
    end

    it "should use -c with the correct argument when the comment property is changed" do
      resource[:comment] = "Testuser Name"
      expect(provider).to receive(:execute).with(include("-c").and(include("Testuser New Name")), hash_including(custom_environment: {}))
      provider.comment = "Testuser New Name"
    end

    it "should use -e with the correct argument when the expiry property is changed" do
      resource[:expiry] = "2010-02-19"
      expect(provider).to receive(:execute).with(include("-e").and(include("19-02-2011")), hash_including(custom_environment: {}))
      provider.expiry = "2011-02-19"
    end

    it "should use -e with the correct argument when the expiry property is removed" do
      resource[:expiry] = :absent
      expect(provider).to receive(:execute).with(include("-e").and(include("00-00-0000")), hash_including(custom_environment: {}))
      provider.expiry = :absent
    end

    it "should use -g with the correct argument when the gid property is changed" do
      resource[:gid] = 12345
      expect(provider).to receive(:execute).with(include("-g").and(include(54321)), hash_including(custom_environment: {}))
      provider.gid = 54321
    end

    it "should use -G with the correct argument when the groups property is changed" do
      resource[:groups] = "group1"
      expect(provider).to receive(:execute).with(include("-G").and(include("group2")), hash_including(custom_environment: {}))
      provider.groups = "group2"
    end

    it "should use -G with all the given groups when the groups property is changed with an array" do
      resource[:groups] = ["group1", "group2"]
      expect(provider).to receive(:execute).with(include("-G").and(include("group3,group4")), hash_including(custom_environment: {}))
      provider.groups = "group3,group4"
    end

    it "should use -d with the correct argument when the home property is changed" do
      resource[:home] = "/home/testuser"
      expect(provider).to receive(:execute).with(include("-d").and(include("/newhome/testuser")), hash_including(custom_environment: {}))
      provider.home = "/newhome/testuser"
    end

    it "should use -m and -d with the correct argument when the home property is changed and managehome is enabled" do
      resource[:home] = "/home/testuser"
      resource[:managehome] = true
      expect(provider).to receive(:execute).with(include("-d").and(include("/newhome/testuser")).and(include("-m")), hash_including(custom_environment: {}))
      provider.home = "/newhome/testuser"
    end

    it "should call the password set function with the correct argument when the password property is changed" do
      resource[:password] = "*"
      expect(provider).to receive(:password=).with("!")
      provider.password = "!"
    end

    it "should use -s with the correct argument when the shell property is changed" do
      resource[:shell] = "/bin/sh"
      expect(provider).to receive(:execute).with(include("-s").and(include("/bin/tcsh")), hash_including(custom_environment: {}))
      provider.shell = "/bin/tcsh"
    end

    it "should use -u with the correct argument when the uid property is changed" do
      resource[:uid] = 12345
      expect(provider).to receive(:execute).with(include("-u").and(include(54321)), hash_including(custom_environment: {}))
      provider.uid = 54321
    end

    it "should print a debug message with sensitive data redacted when the password property is set" do
      Puppet::Util::Log.level = :debug
      resource[:password] = "*"
      popen = double("popen", :puts => nil, :close => nil)
      expect(Open3).to receive(:popen3).and_return(popen)
      expect(popen).to receive(:puts).with("abc123")
      provider.password = "abc123"

      expect(@logs).not_to be_any {|log| log.level == :debug and log.message =~ /abc123/}
     end

    it "should call execute with sensitive false when a non-sensitive property is set" do
      Puppet::Util::Log.level = :debug
      resource[:home] = "/home/testuser"
      resource[:managehome] = true
      expect(provider).to receive(:execute).with(kind_of(Array), hash_including(sensitive: false))
      provider.home = "/newhome/testuser"
    end
  end
end
