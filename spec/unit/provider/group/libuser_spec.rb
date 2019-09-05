require 'spec_helper'

RSpec::Matchers.define_negated_matcher :excluding, :include

describe Puppet::Type.type(:group).provider(:libuser) do
  before do
    allow(described_class).to receive(:command).with(:add).and_return('/usr/sbin/lgroupadd')
    allow(described_class).to receive(:command).with(:delete).and_return('/usr/sbin/lgroupdel')
    allow(described_class).to receive(:command).with(:modify).and_return('/usr/sbin/lgroupmod')
  end

  let!(:resource) { Puppet::Type.type(:group).new(:name => 'mygroup', :provider => provider) }
  let(:provider) { described_class.new(:name => 'mygroup') }

  describe "#create" do
    before do
       allow(provider).to receive(:exists?).and_return(false)
       allow(provider).to receive(:member_valid?).and_return(true)
    end

    it "should support allowdupe when the group is being created" do
      resource[:allowdupe] = :true
      expect(provider).to receive(:execute).with(['/usr/sbin/lgroupadd', 'mygroup'], kind_of(Hash))
      provider.create
    end

    it "should execute both add and modify when a list of members is passed and the group is being created" do
      resource[:members] = ['user1', 'user2', 'user3']
      expect(provider).to receive(:execute).with(['/usr/sbin/lgroupadd', 'mygroup'], kind_of(Hash))
      expect(provider).to receive(:execute).with(['/usr/sbin/lgroupmod', '-M', 'user1,user2,user3', 'mygroup'], kind_of(Hash))
      provider.create
    end

    it "should add -r when system_groups is enabled and the group is being created" do
      resource[:system] = :true
      expect(provider).to receive(:execute).with(['/usr/sbin/lgroupadd', '-r', 'mygroup'], kind_of(Hash))
      provider.create
    end

    it "should raise an exception for duplicate GID if allowdupe is not set and duplicate GIDs exist" do
      resource[:gid] = 505
      allow(provider).to receive(:gid_exists?).and_return(true)
      expect { provider.create }.to raise_error(Puppet::Error, "GID 505 already exists, use allowdupe to force this change")
    end
  end

  describe "#modify" do
    before do
       allow(provider).to receive(:exists?).and_return(true)
    end

    it "should raise an exception for duplicate GID if allowdupe is not set and duplicate GIDs exist" do
      resource[:gid] = 150
      allow(provider).to receive(:gid_exists?).and_return(true)
      expect { provider.gid = 150 }.to raise_error(Puppet::Error, "GID 150 already exists, use allowdupe to force this change")
    end

    describe "if auth_membership is true" do
      before :each do
        resource[:auth_membership] = true
      end

      it "should execute purge_members if the group has members" do
        allow(provider).to receive(:members).and_return(['user1', 'user2'])
        expect(provider).to receive(:purge_members).and_return(true)
        provider.modifycmd(:members, ['user3'])
      end

      it "should not execute purge_members if the group has no members" do
        allow(provider).to receive(:members).and_return([])
        expect(provider).not_to receive(:purge_members)
        provider.modifycmd(:members, ['user3'])
      end
    end

    describe "if auth_membership is false" do
      before :each do
        resource[:auth_membership] = false
      end

      it "should not execute purge_members" do
        allow(provider).to receive(:members).and_return(['user1', 'user2'])
        expect(provider).not_to receive(:purge_members)
        provider.modifycmd(:members, ['user3'])
      end

      it "should add an user to the existing ones" do
        allow(provider).to receive(:members).and_return(['user1', 'user2'])
        expect(provider).to receive(:modifycmd).with(:members, ['user3']).and_return(['/usr/sbin/lgroupmod', '-M', 'user3', 'mygroup'])
        provider.modifycmd(:members, ['user3'])
      end
    end
  end

  describe "#delete" do
    before do
      allow(provider).to receive(:exists?).and_return(true)
    end

    it "should remove a group" do
      expect(provider).to receive(:execute).with(['/usr/sbin/lgroupdel', 'mygroup'], kind_of(Hash))
      provider.delete
    end
  end

  describe "group type :members property helpers" do
    describe "#member_valid?" do
      it "should return true if a member exists" do
        passwd = Struct::Passwd.new('existinguser', nil, 1100)
        allow(Etc).to receive(:getpwnam).with('existinguser').and_return(passwd)
        expect(provider.member_valid?('existinguser')).to eq(true)
      end

      it "should raise an exception if a member does not exist" do
        allow(Etc).to receive(:getpwnam).with('invaliduser').and_raise(ArgumentError)
        expect { provider.member_valid?('invaliduser') }.to raise_error(Puppet::Error, "User invaliduser does not exist")
      end
    end

    describe "#members_to_s" do
      it "should return an empty string on non-array input" do
        [Object.new, {}, 1, :symbol, ''].each do |input|
          expect(provider.members_to_s(input)).to be_empty
        end
      end

      it "should return an empty string on empty or nil users" do
        expect(provider.members_to_s([])).to be_empty
        expect(provider.members_to_s(nil)).to be_empty
      end

      it "should return a user string for a single user" do
        expect(provider.members_to_s(['user1'])).to eq('user1')
      end

      it "should return a user string for multiple users" do
        expect(provider.members_to_s(['user1', 'user2'])).to eq('user1,user2')
      end
    end
  end
end
