require 'spec_helper'

RSpec::Matchers.define_negated_matcher :excluding, :include

describe Puppet::Type.type(:group).provider(:groupadd) do
  before do
    allow(described_class).to receive(:command).with(:add).and_return('/usr/sbin/groupadd')
    allow(described_class).to receive(:command).with(:delete).and_return('/usr/sbin/groupdel')
    allow(described_class).to receive(:command).with(:modify).and_return('/usr/sbin/groupmod')
    allow(described_class).to receive(:command).with(:localadd).and_return('/usr/sbin/lgroupadd')
    allow(described_class).to receive(:command).with(:localdelete).and_return('/usr/sbin/lgroupdel')
    allow(described_class).to receive(:command).with(:localmodify).and_return('/usr/sbin/lgroupmod')
  end

  let(:resource) { Puppet::Type.type(:group).new(:name => 'mygroup', :provider => provider) }
  let(:provider) { described_class.new(:name => 'mygroup') }
  let(:members) { ['user2', 'user1', 'user3'] }

  describe "#create" do
    before do
      allow(provider).to receive(:exists?).and_return(false)
    end

    it "should add -o when allowdupe is enabled and the group is being created" do
      resource[:allowdupe] = :true
      expect(provider).to receive(:execute).with(['/usr/sbin/groupadd', '-o', 'mygroup'], kind_of(Hash))
      provider.create
    end

    describe "on system that feature system_groups", :if => described_class.system_groups? do
      it "should add -r when system is enabled and the group is being created" do
        resource[:system] = :true
        expect(provider).to receive(:execute).with(['/usr/sbin/groupadd', '-r', 'mygroup'], kind_of(Hash))
        provider.create
      end
    end

    describe "on system that do not feature system_groups", :unless => described_class.system_groups? do
      it "should not add -r when system is enabled and the group is being created" do
        resource[:system] = :true
        expect(provider).to receive(:execute).with(['/usr/sbin/groupadd', 'mygroup'], kind_of(Hash))
        provider.create
      end
    end

    describe "on systems with libuser" do
      describe "with forcelocal=true" do
        before do
          described_class.has_feature(:manages_local_users_and_groups)
          resource[:forcelocal] = :true
        end

        it "should use lgroupadd instead of groupadd" do
          expect(provider).to receive(:execute).with(including('/usr/sbin/lgroupadd'), hash_including(:custom_environment => hash_including('LIBUSER_CONF')))
          provider.create
        end

        it "should NOT pass -o to lgroupadd" do
          resource[:allowdupe] = :true
          expect(provider).to receive(:execute).with(excluding('-o'), hash_including(:custom_environment => hash_including('LIBUSER_CONF')))
          provider.create
        end

        it "should raise an exception for duplicate GID if allowdupe is not set and duplicate GIDs exist" do
          resource[:gid] = 505
          allow(provider).to receive(:findgroup).and_return(true)
          expect { provider.create }.to raise_error(Puppet::Error, "GID 505 already exists, use allowdupe to force group creation")
        end
      end

      describe "with a list of members" do
        before do
          members.each { |m| allow(Etc).to receive(:getpwnam).with(m).and_return(true) }

          described_class.has_feature(:manages_members)
          resource[:forcelocal] = false
          resource[:members] = members
        end

        it "should use lgroupmod to add the members" do
          allow(provider).to receive(:execute).with(['/usr/sbin/groupadd', 'mygroup'], hash_including({:failonfail => true, :combine => true, :custom_environment => {}})).and_return(true)
          expect(provider).to receive(:execute).with(['/usr/sbin/lgroupmod', '-M', members.join(','), 'mygroup'], hash_including(:custom_environment => hash_including('LIBUSER_CONF')))
          provider.create
        end
      end
    end
  end

  describe "#modify" do
    before do
      allow(provider).to receive(:exists?).and_return(true)
    end

    describe "on systems with libuser" do
      describe "with forcelocal=false" do
        before do
          described_class.has_feature(:manages_local_users_and_groups)
          resource[:forcelocal] = :false
        end

        it "should use groupmod" do
          expect(provider).to receive(:execute).with(['/usr/sbin/groupmod', '-g', 150, 'mygroup'], hash_including({:failonfail => true, :combine => true, :custom_environment => {}}))
          provider.gid = 150
        end

        it "should pass -o to groupmod" do
          resource[:allowdupe] = :true
          expect(provider).to receive(:execute).with(['/usr/sbin/groupmod', '-g', 150, '-o', 'mygroup'], hash_including({:failonfail => true, :combine => true, :custom_environment => {}}))
          provider.gid = 150
        end
      end

      describe "with forcelocal=true" do
        before do
          described_class.has_feature(:manages_local_users_and_groups)
          resource[:forcelocal] = :true
        end

        it "should use lgroupmod instead of groupmod" do
          expect(provider).to receive(:execute).with(['/usr/sbin/lgroupmod', '-g', 150, 'mygroup'], hash_including(:custom_environment => hash_including('LIBUSER_CONF')))
          provider.gid = 150
        end

        it "should NOT pass -o to lgroupmod" do
          resource[:allowdupe] = :true
          expect(provider).to receive(:execute).with(['/usr/sbin/lgroupmod', '-g', 150, 'mygroup'], hash_including(:custom_environment => hash_including('LIBUSER_CONF')))
          provider.gid = 150
        end

        it "should raise an exception for duplicate GID if allowdupe is not set and duplicate GIDs exist" do
          resource[:gid] = 150
          resource[:allowdupe] = :false
          allow(provider).to receive(:findgroup).and_return(true)
          expect { provider.gid = 150 }.to raise_error(Puppet::Error, "GID 150 already exists, use allowdupe to force group creation")
        end
      end

      describe "with members=something" do
        before do
          described_class.has_feature(:manages_members)
          allow(Etc).to receive(:getpwnam).and_return(true)
          resource[:members] = members
        end

        describe "with auth_membership on" do
          before { resource[:auth_membership] = true }

          it "should purge existing users before adding" do
            allow(provider).to receive(:members).and_return(members)
            expect(provider).to receive(:localmodify).with('-m', members.join(','), 'mygroup')
            provider.modifycmd(:members, ['user1'])
          end
        end

        describe "with auth_membership off" do
          before { resource[:auth_membership] = false }

          it "should add to the existing users" do
            new_members = ['user1', 'user2', 'user3', 'user4']
            allow(provider).to receive(:members).and_return(members)
            expect(provider).not_to receive(:localmodify).with('-m', members.join(','), 'mygroup')
            expect(provider).to receive(:execute).with(['/usr/sbin/lgroupmod', '-M', new_members.join(','), 'mygroup'], kind_of(Hash))
            provider.members = new_members
          end
        end

        it "should validate members" do
          expect(Etc).to receive(:getpwnam).with('user3').and_return(true)
          provider.modifycmd(:members, ['user3'])
        end

        it "should validate members list " do
          expect(Etc).to receive(:getpwnam).with('user3').and_return(true)
          expect(Etc).to receive(:getpwnam).with('user4').and_return(true)
          provider.modifycmd(:members, ['user3', 'user4'])
        end

        it "should validate members list separated by commas" do
          expect(Etc).to receive(:getpwnam).with('user3').and_return(true)
          expect(Etc).to receive(:getpwnam).with('user4').and_return(true)
          provider.modifycmd(:members, ['user3, user4'])
        end

        it "should raise is validation fails" do
          expect(Etc).to receive(:getpwnam).with('user3').and_throw(ArgumentError)
          expect { provider.modifycmd(:members, ['user3']) }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe "#gid=" do
    it "should add -o when allowdupe is enabled and the gid is being modified" do
      resource[:allowdupe] = :true
      expect(provider).to receive(:execute).with(['/usr/sbin/groupmod', '-g', 150, '-o', 'mygroup'], hash_including({:failonfail => true, :combine => true, :custom_environment => {}}))
      provider.gid = 150
    end
  end

  describe "#findgroup" do
    before { allow(File).to receive(:read).with('/etc/group').and_return(content) }

    let(:content) { "sample_group_name:sample_password:sample_gid:sample_user_list" }
    let(:output) do
      {
        group_name: 'sample_group_name',
        password: 'sample_password',
        gid: 'sample_gid',
        user_list: 'sample_user_list',
      }
    end

    [:group_name, :password, :gid, :user_list].each do |key|
      it "finds a group by #{key} when asked" do
        expect(provider.send(:findgroup, key, "sample_#{key}")).to eq(output)
      end
    end

    it "returns false when specified key/value pair is not found" do
      expect(provider.send(:findgroup, :group_name, 'invalid_group_name')).to eq(false)
    end

    it "reads the group file only once per resource" do
      expect(File).to receive(:read).with('/etc/group').once
      5.times { provider.send(:findgroup, :group_name, 'sample_group_name') }
    end
  end

  describe "#delete" do
    before do
      allow(provider).to receive(:exists?).and_return(true)
    end

    describe "on systems with the libuser and forcelocal=false" do
      before do
        described_class.has_feature(:manages_local_users_and_groups)
        resource[:forcelocal] = :false
      end

      it "should use groupdel" do
        expect(provider).to receive(:execute).with(['/usr/sbin/groupdel', 'mygroup'], hash_including({:failonfail => true, :combine => true, :custom_environment => {}}))
        provider.delete
      end
    end

    describe "on systems with the libuser and forcelocal=true" do
      before do
        described_class.has_feature(:manages_local_users_and_groups)
        resource[:forcelocal] = :true
      end

      it "should use lgroupdel instead of groupdel" do
        expect(provider).to receive(:execute).with(['/usr/sbin/lgroupdel', 'mygroup'], hash_including(:custom_environment => hash_including('LIBUSER_CONF')))
        provider.delete
      end
    end
  end

  describe "group type :members property helpers" do
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
