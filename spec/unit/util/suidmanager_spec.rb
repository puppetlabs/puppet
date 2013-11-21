#! /usr/bin/env ruby

require 'spec_helper'

describe Puppet::Util::SUIDManager do
  let :user do
    Puppet::Type.type(:user).new(:name => 'name', :uid => 42, :gid => 42)
  end

  let :xids do
    Hash.new {|h,k| 0}
  end

  before :each do
    Puppet::Util::SUIDManager.stubs(:convert_xid).returns(42)
    pwent = stub('pwent', :name => 'fred', :uid => 42, :gid => 42)
    Etc.stubs(:getpwuid).with(42).returns(pwent)

    [:euid, :egid, :uid, :gid, :groups].each do |id|
      Process.stubs("#{id}=").with {|value| xids[id] = value }
    end
  end

  describe "#initgroups" do
    it "should use the primary group of the user as the 'basegid'" do
      Process.expects(:initgroups).with('fred', 42)
      described_class.initgroups(42)
    end
  end

  describe "#uid" do
    it "should allow setting euid/egid" do
      Puppet::Util::SUIDManager.egid = user[:gid]
      Puppet::Util::SUIDManager.euid = user[:uid]

      xids[:egid].should == user[:gid]
      xids[:euid].should == user[:uid]
    end
  end

  describe "#asuser" do
    it "should not get or set euid/egid when not root" do
      Puppet.features.stubs(:microsoft_windows?).returns(false)
      Process.stubs(:uid).returns(1)

      Process.stubs(:egid).returns(51)
      Process.stubs(:euid).returns(50)

      Puppet::Util::SUIDManager.asuser(user[:uid], user[:gid]) {}

      xids.should be_empty
    end

    context "when root and not windows" do
      before :each do
        Process.stubs(:uid).returns(0)
        Puppet.features.stubs(:microsoft_windows?).returns(false)
      end

      it "should set euid/egid when root" do
        Process.stubs(:uid).returns(0)

        Process.stubs(:egid).returns(51)
        Process.stubs(:euid).returns(50)

        Puppet::Util::SUIDManager.stubs(:convert_xid).with(:gid, 51).returns(51)
        Puppet::Util::SUIDManager.stubs(:convert_xid).with(:uid, 50).returns(50)
        Puppet::Util::SUIDManager.stubs(:initgroups).returns([])

        yielded = false
        Puppet::Util::SUIDManager.asuser(user[:uid], user[:gid]) do
          xids[:egid].should == user[:gid]
          xids[:euid].should == user[:uid]
          yielded = true
        end

        xids[:egid].should == 51
        xids[:euid].should == 50

        # It's possible asuser could simply not yield, so the assertions in the
        # block wouldn't fail. So verify those actually got checked.
        yielded.should be_true
      end

      it "should just yield if user and group are nil" do
        yielded = false
        Puppet::Util::SUIDManager.asuser(nil, nil) { yielded = true }
        yielded.should be_true
        xids.should == {}
      end

      it "should just change group if only group is given" do
        yielded = false
        Puppet::Util::SUIDManager.asuser(nil, 42) { yielded = true }
        yielded.should be_true
        xids.should == { :egid => 42 }
      end

      it "should change gid to the primary group of uid by default" do
        Process.stubs(:initgroups)

        yielded = false
        Puppet::Util::SUIDManager.asuser(42) { yielded = true }
        yielded.should be_true
        xids.should == { :euid => 42, :egid => 42 }
      end

      it "should change both uid and gid if given" do
        # I don't like the sequence, but it is the only way to assert on the
        # internal behaviour in a reliable fashion, given we need multiple
        # sequenced calls to the same methods. --daniel 2012-02-05
        horror = sequence('of user and group changes')
        Puppet::Util::SUIDManager.expects(:change_group).with(43, false).in_sequence(horror)
        Puppet::Util::SUIDManager.expects(:change_user).with(42, false).in_sequence(horror)
        Puppet::Util::SUIDManager.expects(:change_group).
          with(Puppet::Util::SUIDManager.egid, false).in_sequence(horror)
        Puppet::Util::SUIDManager.expects(:change_user).
          with(Puppet::Util::SUIDManager.euid, false).in_sequence(horror)

        yielded = false
        Puppet::Util::SUIDManager.asuser(42, 43) { yielded = true }
        yielded.should be_true
      end
    end

    it "should not get or set euid/egid on Windows" do
      Puppet.features.stubs(:microsoft_windows?).returns true

      Puppet::Util::SUIDManager.asuser(user[:uid], user[:gid]) {}

      xids.should be_empty
    end
  end

  describe "#change_group" do
    describe "when changing permanently" do
      it "should change_privilege" do
        Process::GID.expects(:change_privilege).with do |gid|
          Process.gid = gid
          Process.egid = gid
        end

        Puppet::Util::SUIDManager.change_group(42, true)

        xids[:egid].should == 42
        xids[:gid].should == 42
      end
    end

    describe "when changing temporarily" do
      it "should change only egid" do
        Puppet::Util::SUIDManager.change_group(42, false)

        xids[:egid].should == 42
        xids[:gid].should == 0
      end
    end
  end

  describe "#change_user" do
    describe "when changing permanently" do
      it "should change_privilege" do
        Process::UID.expects(:change_privilege).with do |uid|
          Process.uid = uid
          Process.euid = uid
        end

        Puppet::Util::SUIDManager.expects(:initgroups).with(42)

        Puppet::Util::SUIDManager.change_user(42, true)

        xids[:euid].should == 42
        xids[:uid].should == 42
      end
    end

    describe "when changing temporarily" do
      it "should change only euid and groups" do
        Puppet::Util::SUIDManager.stubs(:initgroups).returns([])
        Puppet::Util::SUIDManager.change_user(42, false)

        xids[:euid].should == 42
        xids[:uid].should == 0
      end

      it "should set euid before groups if changing to root" do
        Process.stubs(:euid).returns 50

        when_not_root = sequence 'when_not_root'

        Process.expects(:euid=).in_sequence(when_not_root)
        Puppet::Util::SUIDManager.expects(:initgroups).in_sequence(when_not_root)

        Puppet::Util::SUIDManager.change_user(0, false)
      end

      it "should set groups before euid if changing from root" do
        Process.stubs(:euid).returns 0

        when_root = sequence 'when_root'

        Puppet::Util::SUIDManager.expects(:initgroups).in_sequence(when_root)
        Process.expects(:euid=).in_sequence(when_root)

        Puppet::Util::SUIDManager.change_user(50, false)
      end
    end
  end

  describe "when running commands" do
    before :each do
      # We want to make sure $CHILD_STATUS is set
      Kernel.system '' if $CHILD_STATUS.nil?
    end

    describe "with #run_and_capture" do
      it "should capture the output and return process status" do
        Puppet::Util::Execution.
          expects(:execute).with() do |*args|
              args[0] == 'yay' &&
              args[1][:combine] == true &&
              args[1][:failonfail] == false &&
              args[1][:uid] == user[:uid] &&
              args[1][:gid] == user[:gid] &&
              args[1][:override_locale] == true &&
              args[1].has_key?(:custom_environment)
        end .
          returns('output')
        output = Puppet::Util::SUIDManager.run_and_capture 'yay', user[:uid], user[:gid]

        output.first.should == 'output'
        output.last.should be_a(Process::Status)
      end

      it "should log a deprecation notice" do
        Puppet::Util::Execution.stubs(:execute).returns("success")
        Puppet.expects(:deprecation_warning).with('Puppet::Util::SUIDManager.run_and_capture is deprecated; please use Puppet::Util::Execution.execute instead.')

        output = Puppet::Util::SUIDManager.run_and_capture 'yay', user[:uid], user[:gid]
      end
    end
  end

  describe "#root?" do
    describe "on POSIX systems" do
      before :each do
        Puppet.features.stubs(:posix?).returns(true)
        Puppet.features.stubs(:microsoft_windows?).returns(false)
      end

      it "should be root if uid is 0" do
        Process.stubs(:uid).returns(0)

        Puppet::Util::SUIDManager.should be_root
      end

      it "should not be root if uid is not 0" do
        Process.stubs(:uid).returns(1)

        Puppet::Util::SUIDManager.should_not be_root
      end
    end

    describe "on Microsoft Windows", :if => Puppet.features.microsoft_windows? do
      it "should be root if user is privileged" do
        Puppet::Util::Windows::User.stubs(:admin?).returns true

        Puppet::Util::SUIDManager.should be_root
      end

      it "should not be root if user is not privileged" do
        Puppet::Util::Windows::User.stubs(:admin?).returns false

        Puppet::Util::SUIDManager.should_not be_root
      end
    end
  end
end

describe 'Puppet::Util::SUIDManager#groups=' do
  subject do
    Puppet::Util::SUIDManager
  end


  it "(#3419) should rescue Errno::EINVAL on OS X" do
    Process.expects(:groups=).raises(Errno::EINVAL, 'blew up')
    subject.expects(:osx_maj_ver).returns('10.7').twice
    subject.groups = ['list', 'of', 'groups']
  end

  it "(#3419) should fail if an Errno::EINVAL is raised NOT on OS X" do
    Process.expects(:groups=).raises(Errno::EINVAL, 'blew up')
    subject.expects(:osx_maj_ver).returns(false)
    expect { subject.groups = ['list', 'of', 'groups'] }.to raise_error(Errno::EINVAL)
  end
end
