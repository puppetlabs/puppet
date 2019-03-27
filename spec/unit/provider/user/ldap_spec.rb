require 'spec_helper'

describe Puppet::Type.type(:user).provider(:ldap) do
  it "should have the Ldap provider class as its baseclass" do
    expect(described_class.superclass).to equal(Puppet::Provider::Ldap)
  end

  it "should manage :posixAccount and :person objectclasses" do
    expect(described_class.manager.objectclasses).to eq([:posixAccount, :person])
  end

  it "should use 'ou=People' as its relative base" do
    expect(described_class.manager.location).to eq("ou=People")
  end

  it "should use :uid as its rdn" do
    expect(described_class.manager.rdn).to eq(:uid)
  end

  it "should be able to manage passwords" do
    expect(described_class).to be_manages_passwords
  end

  {:name => "uid",
    :password => "userPassword",
    :comment => "cn",
    :uid => "uidNumber",
    :gid => "gidNumber",
    :home => "homeDirectory",
    :shell => "loginShell"
  }.each do |puppet, ldap|
    it "should map :#{puppet.to_s} to '#{ldap}'" do
      expect(described_class.manager.ldap_name(puppet)).to eq(ldap)
    end
  end

  context "when being created" do
    before do
      # So we don't try to actually talk to ldap
      @connection = double('connection')
      allow(described_class.manager).to receive(:connect).and_yield(@connection)
    end

    it "should generate the sn as the last field of the cn" do
      expect(Puppet::Type.type(:group).provider(:ldap)).to receive(:name2id).with(["whatever"]).and_return([123])

      resource = double('resource', :should => %w{whatever})
      allow(resource).to receive(:should).with(:comment).and_return(["Luke Kanies"])
      allow(resource).to receive(:should).with(:ensure).and_return(:present)
      instance = described_class.new(:name => "luke", :ensure => :absent)

      allow(instance).to receive(:resource).and_return(resource)

      expect(@connection).to receive(:add).with(anything, hash_including("sn" => ["Kanies"]))

      instance.create
      instance.flush
    end

    it "should translate a group name to the numeric id" do
      expect(Puppet::Type.type(:group).provider(:ldap)).to receive(:name2id).with("bar").and_return(101)

      resource = double('resource', :should => %w{whatever})
      allow(resource).to receive(:should).with(:gid).and_return('bar')
      allow(resource).to receive(:should).with(:ensure).and_return(:present)
      instance = described_class.new(:name => "luke", :ensure => :absent)
      allow(instance).to receive(:resource).and_return(resource)

      expect(@connection).to receive(:add).with(anything, hash_including("gidNumber" => ["101"]))

      instance.create
      instance.flush
    end

    context "with no uid specified" do
      it "should pick the first available UID after the largest existing UID" do
        expect(Puppet::Type.type(:group).provider(:ldap)).to receive(:name2id).with(["whatever"]).and_return([123])

        low = {:name=>["luke"], :shell=>:absent, :uid=>["600"], :home=>["/h"], :gid=>["1000"], :password=>["blah"], :comment=>["l k"]}
        high = {:name=>["testing"], :shell=>:absent, :uid=>["640"], :home=>["/h"], :gid=>["1000"], :password=>["blah"], :comment=>["t u"]}
        expect(described_class.manager).to receive(:search).and_return([low, high])

        resource = double('resource', :should => %w{whatever})
        allow(resource).to receive(:should).with(:uid).and_return(nil)
        allow(resource).to receive(:should).with(:ensure).and_return(:present)
        instance = described_class.new(:name => "luke", :ensure => :absent)
        allow(instance).to receive(:resource).and_return(resource)

        expect(@connection).to receive(:add).with(anything, hash_including("uidNumber" => ["641"]))

        instance.create
        instance.flush
      end

      it "should pick 501 of no users exist" do
        expect(Puppet::Type.type(:group).provider(:ldap)).to receive(:name2id).with(["whatever"]).and_return([123])

        expect(described_class.manager).to receive(:search).and_return(nil)

        resource = double('resource', :should => %w{whatever})
        allow(resource).to receive(:should).with(:uid).and_return(nil)
        allow(resource).to receive(:should).with(:ensure).and_return(:present)
        instance = described_class.new(:name => "luke", :ensure => :absent)
        allow(instance).to receive(:resource).and_return(resource)

        expect(@connection).to receive(:add).with(anything, hash_including("uidNumber" => ["501"]))

        instance.create
        instance.flush
      end
    end
  end

  context "when flushing" do
    before do
      allow(described_class).to receive(:suitable?).and_return(true)

      @instance = described_class.new(:name => "myname", :groups => %w{whatever}, :uid => "400")
    end

    it "should remove the :groups value before updating" do
      expect(@instance.class.manager).to receive(:update).with(anything, anything, hash_excluding(:groups))

      @instance.flush
    end

    it "should empty the property hash" do
      allow(@instance.class.manager).to receive(:update)

      @instance.flush

      expect(@instance.uid).to eq(:absent)
    end

    it "should empty the ldap property hash" do
      allow(@instance.class.manager).to receive(:update)

      @instance.flush

      expect(@instance.ldap_properties[:uid]).to be_nil
    end
  end

  context "when checking group membership" do
    before do
      @groups = Puppet::Type.type(:group).provider(:ldap)
      @group_manager = @groups.manager
      allow(described_class).to receive(:suitable?).and_return(true)

      @instance = described_class.new(:name => "myname")
    end

    it "should show its group membership as the sorted list of all groups returned by an ldap query of group memberships" do
      one = {:name => "one"}
      two = {:name => "two"}
      expect(@group_manager).to receive(:search).with("memberUid=myname").and_return([two, one])

      expect(@instance.groups).to eq("one,two")
    end

    it "should show its group membership as :absent if no matching groups are found in ldap" do
      expect(@group_manager).to receive(:search).with("memberUid=myname").and_return(nil)

      expect(@instance.groups).to eq(:absent)
    end

    it "should cache the group value" do
      expect(@group_manager).to receive(:search).with("memberUid=myname").once.and_return(nil)

      @instance.groups
      expect(@instance.groups).to eq(:absent)
    end
  end

  context "when modifying group membership" do
    before do
      @groups = Puppet::Type.type(:group).provider(:ldap)
      @group_manager = @groups.manager
      allow(described_class).to receive(:suitable?).and_return(true)

      @one = {:name => "one", :gid => "500"}
      allow(@group_manager).to receive(:find).with("one").and_return(@one)

      @two = {:name => "one", :gid => "600"}
      allow(@group_manager).to receive(:find).with("two").and_return(@two)

      @instance = described_class.new(:name => "myname")

      allow(@instance).to receive(:groups).and_return(:absent)
    end

    it "should fail if the group does not exist" do
      expect(@group_manager).to receive(:find).with("mygroup").and_return(nil)

      expect { @instance.groups = "mygroup" }.to raise_error(Puppet::Error)
    end

    it "should only pass the attributes it cares about to the group manager" do
      expect(@group_manager).to receive(:update).with(anything, hash_excluding(:gid), anything)

      @instance.groups = "one"
    end

    it "should always include :ensure => :present in the current values" do
      expect(@group_manager).to receive(:update).with(anything, hash_including(ensure: :present), anything)

      @instance.groups = "one"
    end

    it "should always include :ensure => :present in the desired values" do
      expect(@group_manager).to receive(:update).with(anything, anything, hash_including(ensure: :present))

      @instance.groups = "one"
    end

    it "should always pass the group's original member list" do
      @one[:members] = %w{yay ness}
      expect(@group_manager).to receive(:update).with(anything, hash_including(members: %w{yay ness}), anything)

      @instance.groups = "one"
    end

    it "should find the group again when resetting its member list, so it has the full member list" do
      expect(@group_manager).to receive(:find).with("one").and_return(@one)

      allow(@group_manager).to receive(:update)

      @instance.groups = "one"
    end

    context "for groups that have no members" do
      it "should create a new members attribute with its value being the user's name" do
        expect(@group_manager).to receive(:update).with(anything, anything, hash_including(members: %w{myname}))

        @instance.groups = "one"
      end
    end

    context "for groups it is being removed from" do
      it "should replace the group's member list with one missing the user's name" do
        @one[:members] = %w{myname a}
        @two[:members] = %w{myname b}

        expect(@group_manager).to receive(:update).with("two", anything, hash_including(members: %w{b}))

        allow(@instance).to receive(:groups).and_return("one,two")
        @instance.groups = "one"
      end

      it "should mark the member list as empty if there are no remaining members" do
        @one[:members] = %w{myname}
        @two[:members] = %w{myname b}

        expect(@group_manager).to receive(:update).with("one", anything, hash_including(members: :absent))

        allow(@instance).to receive(:groups).and_return("one,two")
        @instance.groups = "two"
      end
    end

    context "for groups that already have members" do
      it "should replace each group's member list with a new list including the user's name" do
        @one[:members] = %w{a b}
        expect(@group_manager).to receive(:update).with(anything, anything, hash_including(members: %w{a b myname}))
        @two[:members] = %w{b c}
        expect(@group_manager).to receive(:update).with(anything, anything, hash_including(members: %w{b c myname}))

        @instance.groups = "one,two"
      end
    end

    context "for groups of which it is a member" do
      it "should do nothing" do
        @one[:members] = %w{a b}
        expect(@group_manager).to receive(:update).with(anything, anything, hash_including(members: %w{a b myname}))

        @two[:members] = %w{c myname}
        expect(@group_manager).not_to receive(:update).with("two", any_args)

        allow(@instance).to receive(:groups).and_return("two")

        @instance.groups = "one,two"
      end
    end
  end
end
