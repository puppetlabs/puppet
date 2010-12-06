#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppet'
require 'puppettest'
require 'test/unit'
require 'mocha'

class TestSUIDManager < Test::Unit::TestCase
  include PuppetTest

  def setup
    the_id = 42
    Puppet::Util::SUIDManager.stubs(:convert_xid).returns(the_id)
    Puppet::Util::SUIDManager.stubs(:initgroups)
    @user = stub('user', :uid => the_id, :gid => the_id, :name => 'name')
    super
  end

  def test_metaprogramming_function_additions
    # NOTE: the way that we are dynamically generating the methods in
    # SUIDManager for the UID/GID calls was causing problems due to the
    # modification of a closure. Should the bug rear itself again, this
    # test will fail.
    Process.expects(:uid).times(2)

    assert_nothing_raised do
      Puppet::Util::SUIDManager.uid
      Puppet::Util::SUIDManager.uid
    end
  end

  def test_id_set
    Process.expects(:euid=).with(@user.uid)
    Process.expects(:egid=).with(@user.gid)

    assert_nothing_raised do
      Puppet::Util::SUIDManager.egid = @user.gid
      Puppet::Util::SUIDManager.euid = @user.uid
    end
  end

  def test_utiluid
    assert_not_equal(nil, Puppet::Util.uid(nonrootuser.name))
  end

  def test_asuser_as_root
    Process.stubs(:uid).returns(0)
    expects_id_set_and_revert @user.uid, @user.gid
    Puppet::Util::SUIDManager.asuser @user.uid, @user.gid do end
  rescue Errno::EPERM
  end

  def test_asuser_as_nonroot
    Process.stubs(:uid).returns(1)
    expects_no_id_set
    Puppet::Util::SUIDManager.asuser @user.uid, @user.gid do end
  end


  def test_system_as_root
    Process.stubs(:uid).returns(0)
    set_exit_status!
    expects_id_set_and_revert @user.uid, @user.gid
    Kernel.expects(:system).with('blah')
    Puppet::Util::SUIDManager.system('blah', @user.uid, @user.gid)
  end

  def test_system_as_nonroot
    Process.stubs(:uid).returns(1)
    set_exit_status!
    expects_no_id_set
    Kernel.expects(:system).with('blah')
    Puppet::Util::SUIDManager.system('blah', @user.uid, @user.gid)
  end

  def test_run_and_capture
    if (RUBY_VERSION <=> "1.8.4") < 0
      warn "Cannot run this test on ruby < 1.8.4"
    else
      set_exit_status!
      Puppet::Util.
        expects(:execute).
        with('yay',:combine => true, :failonfail => false, :uid => @user.uid, :gid => @user.gid).
        returns('output')
      output = Puppet::Util::SUIDManager.run_and_capture 'yay', @user.uid, @user.gid

      assert_equal 'output', output.first
      assert_kind_of Process::Status, output.last
    end
  end

  private

  def expects_id_set_and_revert(uid, gid)
    Process.stubs(:groups=)
    Process.expects(:euid).returns(99997)
    Process.expects(:egid).returns(99996)

    Process.expects(:euid=).with(uid)
    Process.expects(:egid=).with(gid)

    Process.expects(:euid=).with(99997)
    Process.expects(:egid=).with(99996)
  end

  def expects_no_id_set
    Process.expects(:egid).never
    Process.expects(:euid).never
    Process.expects(:egid=).never
    Process.expects(:euid=).never
  end

  def set_exit_status!
    # We want to make sure $CHILD_STATUS is set, this is the only way I know how.
    Kernel.system '' if $CHILD_STATUS.nil?
  end
end

