require 'spec_helper'

describe Puppet::Util::SUIDManager do
  let :user do
    Puppet::Type.type(:user).new(:name => 'name', :uid => 42, :gid => 42)
  end

  let :xids do
    Hash.new {|h,k| 0}
  end

  before :each do
    allow(Puppet::Util::SUIDManager).to receive(:convert_xid).and_return(42)
    pwent = double('pwent', :name => 'fred', :uid => 42, :gid => 42)
    allow(Etc).to receive(:getpwuid).with(42).and_return(pwent)

    unless Puppet::Util::Platform.windows?
      [:euid, :egid, :uid, :gid, :groups].each do |id|
        allow(Process).to receive("#{id}=") {|value| xids[id] = value}
      end
    end
  end

  describe "#initgroups", unless: Puppet::Util::Platform.windows? do
    it "should use the primary group of the user as the 'basegid'" do
      expect(Process).to receive(:initgroups).with('fred', 42)
      described_class.initgroups(42)
    end
  end

  describe "#uid" do
    it "should allow setting euid/egid", unless: Puppet::Util::Platform.windows? do
      Puppet::Util::SUIDManager.egid = user[:gid]
      Puppet::Util::SUIDManager.euid = user[:uid]

      expect(xids[:egid]).to eq(user[:gid])
      expect(xids[:euid]).to eq(user[:uid])
    end
  end

  describe "#asuser" do
    it "should not get or set euid/egid when not root", unless: Puppet::Util::Platform.windows? do
      allow(Process).to receive(:uid).and_return(1)

      allow(Process).to receive(:egid).and_return(51)
      allow(Process).to receive(:euid).and_return(50)

      Puppet::Util::SUIDManager.asuser(user[:uid], user[:gid]) {}

      expect(xids).to be_empty
    end

    context "when root and not Windows" do
      before :each do
        allow(Process).to receive(:uid).and_return(0)
      end

      it "should set euid/egid", unless: Puppet::Util::Platform.windows? do
        allow(Process).to receive(:egid).and_return(51, 51, user[:gid])
        allow(Process).to receive(:euid).and_return(50, 50, user[:uid])

        allow(Puppet::Util::SUIDManager).to receive(:convert_xid).with(:gid, 51).and_return(51)
        allow(Puppet::Util::SUIDManager).to receive(:convert_xid).with(:uid, 50).and_return(50)
        allow(Puppet::Util::SUIDManager).to receive(:initgroups).and_return([])

        yielded = false
        Puppet::Util::SUIDManager.asuser(user[:uid], user[:gid]) do
          expect(xids[:egid]).to eq(user[:gid])
          expect(xids[:euid]).to eq(user[:uid])
          yielded = true
        end

        expect(xids[:egid]).to eq(51)
        expect(xids[:euid]).to eq(50)

        # It's possible asuser could simply not yield, so the assertions in the
        # block wouldn't fail. So verify those actually got checked.
        expect(yielded).to be_truthy
      end

      it "should just yield if user and group are nil" do
        expect { |b| Puppet::Util::SUIDManager.asuser(nil, nil, &b) }.to yield_control
        expect(xids).to eq({})
      end

      it "should just change group if only group is given", unless: Puppet::Util::Platform.windows? do
        expect { |b| Puppet::Util::SUIDManager.asuser(nil, 42, &b) }.to yield_control
        expect(xids).to eq({ :egid => 42 })
      end

      it "should change gid to the primary group of uid by default", unless: Puppet::Util::Platform.windows? do
        allow(Process).to receive(:initgroups)

        expect { |b| Puppet::Util::SUIDManager.asuser(42, nil, &b) }.to yield_control
        expect(xids).to eq({ :euid => 42, :egid => 42 })
      end

      it "should change both uid and gid if given", unless: Puppet::Util::Platform.windows? do
        # I don't like the sequence, but it is the only way to assert on the
        # internal behaviour in a reliable fashion, given we need multiple
        # sequenced calls to the same methods. --daniel 2012-02-05
        expect(Puppet::Util::SUIDManager).to receive(:change_group).with(43, false).ordered()
        expect(Puppet::Util::SUIDManager).to receive(:change_user).with(42, false).ordered()
        expect(Puppet::Util::SUIDManager).to receive(:change_group).with(Puppet::Util::SUIDManager.egid, false).ordered()
        expect(Puppet::Util::SUIDManager).to receive(:change_user).with(Puppet::Util::SUIDManager.euid, false).ordered()

        expect { |b| Puppet::Util::SUIDManager.asuser(42, 43, &b) }.to yield_control
      end
    end

    it "should just yield on Windows", if: Puppet::Util::Platform.windows? do
      expect { |b| Puppet::Util::SUIDManager.asuser(1, 2, &b) }.to yield_control
    end
  end

  describe "#change_group" do
    it "raises on Windows", if: Puppet::Util::Platform.windows? do
      expect {
        Puppet::Util::SUIDManager.change_group(42, true)
      }.to raise_error(NotImplementedError, /change_privilege\(\) function is unimplemented/)
    end

    describe "when changing permanently", unless: Puppet::Util::Platform.windows? do
      it "should change_privilege" do
        expect(Process::GID).to receive(:change_privilege) do |gid|
          Process.gid = gid
          Process.egid = gid
        end

        Puppet::Util::SUIDManager.change_group(42, true)

        expect(xids[:egid]).to eq(42)
        expect(xids[:gid]).to eq(42)
      end

      it "should not change_privilege when gid already matches" do
        expect(Process::GID).to receive(:change_privilege) do |gid|
          Process.gid = 42
          Process.egid = 42
        end

        Puppet::Util::SUIDManager.change_group(42, true)

        expect(xids[:egid]).to eq(42)
        expect(xids[:gid]).to eq(42)
      end
    end

    describe "when changing temporarily", unless: Puppet::Util::Platform.windows? do
      it "should change only egid" do
        Puppet::Util::SUIDManager.change_group(42, false)

        expect(xids[:egid]).to eq(42)
        expect(xids[:gid]).to eq(0)
      end
    end
  end

  describe "#change_user" do
    it "raises on Windows", if: Puppet::Util::Platform.windows? do
      expect {
        Puppet::Util::SUIDManager.change_user(42, true)
      }.to raise_error(NotImplementedError, /initgroups\(\) function is unimplemented/)
    end

    describe "when changing permanently", unless: Puppet::Util::Platform.windows? do
      it "should change_privilege" do
        expect(Process::UID).to receive(:change_privilege) do |uid|
          Process.uid = uid
          Process.euid = uid
        end

        expect(Puppet::Util::SUIDManager).to receive(:initgroups).with(42)

        Puppet::Util::SUIDManager.change_user(42, true)

        expect(xids[:euid]).to eq(42)
        expect(xids[:uid]).to eq(42)
      end

      it "should not change_privilege when uid already matches" do
        expect(Process::UID).to receive(:change_privilege) do |uid|
          Process.uid = 42
          Process.euid = 42
        end

        expect(Puppet::Util::SUIDManager).to receive(:initgroups).with(42)

        Puppet::Util::SUIDManager.change_user(42, true)

        expect(xids[:euid]).to eq(42)
        expect(xids[:uid]).to eq(42)
      end
    end

    describe "when changing temporarily", unless: Puppet::Util::Platform.windows? do
      it "should change only euid and groups" do
        allow(Puppet::Util::SUIDManager).to receive(:initgroups).and_return([])
        Puppet::Util::SUIDManager.change_user(42, false)

        expect(xids[:euid]).to eq(42)
        expect(xids[:uid]).to eq(0)
      end

      it "should set euid before groups if changing to root" do
        allow(Process).to receive(:euid).and_return(50)

        expect(Process).to receive(:euid=).ordered()
        expect(Puppet::Util::SUIDManager).to receive(:initgroups).ordered()

        Puppet::Util::SUIDManager.change_user(0, false)
      end

      it "should set groups before euid if changing from root" do
        allow(Process).to receive(:euid).and_return(0)

        expect(Puppet::Util::SUIDManager).to receive(:initgroups).ordered()
        expect(Process).to receive(:euid=).ordered()

        Puppet::Util::SUIDManager.change_user(50, false)
      end
    end
  end

  describe "#root?" do
    describe "on POSIX systems", unless: Puppet::Util::Platform.windows? do
      it "should be root if uid is 0" do
        allow(Process).to receive(:uid).and_return(0)

        expect(Puppet::Util::SUIDManager).to be_root
      end

      it "should not be root if uid is not 0" do
        allow(Process).to receive(:uid).and_return(1)

        expect(Puppet::Util::SUIDManager).not_to be_root
      end
    end

    describe "on Windows", :if => Puppet::Util::Platform.windows? do
      it "should be root if user is privileged" do
        allow(Puppet::Util::Windows::User).to receive(:admin?).and_return(true)

        expect(Puppet::Util::SUIDManager).to be_root
      end

      it "should not be root if user is not privileged" do
        allow(Puppet::Util::Windows::User).to receive(:admin?).and_return(false)

        expect(Puppet::Util::SUIDManager).not_to be_root
      end
    end
  end
end

describe 'Puppet::Util::SUIDManager#groups=' do
  subject do
    Puppet::Util::SUIDManager
  end

  it "raises on Windows", if: Puppet::Util::Platform.windows? do
    expect {
      subject.groups = []
    }.to raise_error(NotImplementedError, /groups=\(\) function is unimplemented/)
  end

  it "(#3419) should rescue Errno::EINVAL on OS X", unless: Puppet::Util::Platform.windows? do
    expect(Process).to receive(:groups=).and_raise(Errno::EINVAL, 'blew up')
    expect(subject).to receive(:osx_maj_ver).and_return('10.7').twice
    subject.groups = ['list', 'of', 'groups']
  end

  it "(#3419) should fail if an Errno::EINVAL is raised NOT on OS X", unless: Puppet::Util::Platform.windows? do
    expect(Process).to receive(:groups=).and_raise(Errno::EINVAL, 'blew up')
    expect(subject).to receive(:osx_maj_ver).and_return(false)
    expect { subject.groups = ['list', 'of', 'groups'] }.to raise_error(Errno::EINVAL)
  end
end
