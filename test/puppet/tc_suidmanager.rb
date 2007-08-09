#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppettest'
require 'test/unit'
require 'mocha'

class TestSUIDManager < Test::Unit::TestCase
    include PuppetTest

    def setup
        @user = nonrootuser
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
        assert_not_equal(nil, Puppet::Util.uid(@user.name))
    end

    def test_asuser
        expects_id_set_and_revert @user.uid, @user.gid
        Puppet::Util::SUIDManager.asuser @user.uid, @user.gid do end
    end


    def test_system
        expects_id_set_and_revert @user.uid, @user.gid
        Kernel.expects(:system).with('blah')
        Puppet::Util::SUIDManager.system('blah', @user.uid, @user.gid)
    end

    def test_run_and_capture
        if (RUBY_VERSION <=> "1.8.4") < 0
            warn "Cannot run this test on ruby < 1.8.4"
        else
            Puppet::Util.expects(:execute).with( 'yay',
                                                 { :failonfail => false,
                                                   :uid => @user.uid,
                                                   :gid => @user.gid }
                                               ).returns('output')


            output = Puppet::Util::SUIDManager.run_and_capture 'yay', 
                                                               @user.uid,
                                                               @user.gid

            assert_equal 'output', output.first
            assert_kind_of Process::Status, output.last
        end
    end

    private
    def expects_id_set_and_revert uid, gid
        Process.expects(:uid).returns(99999)
        Process.expects(:gid).returns(99998)
        Process.expects(:euid).returns(99997)
        Process.expects(:egid).returns(99996)

        Process.expects(:uid=).with(uid)
        Process.expects(:gid=).with(gid)
        Process.expects(:euid=).with(uid)
        Process.expects(:egid=).with(gid)

        Process.expects(:uid=).with(99999)
        Process.expects(:gid=).with(99998)
        Process.expects(:euid=).with(99997)
        Process.expects(:egid=).with(99996)
    end
end

# $Id$
