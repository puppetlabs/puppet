#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppettest'
require 'test/unit'

class TestSUIDManager < Test::Unit::TestCase
    include PuppetTest

    def setup
        if Process.uid != 0
            warn "Process tests must be run as root"
            @run = false
        else 
            @run = true
        end
        super
    end

    def test_metaprogramming_function_additions
        # NOTE: the way that we are dynamically generating the methods in
        # SUIDManager for the UID/GID calls was causing problems due to the
        # modification of a closure. Should the bug rear itself again, this
        # test will fail.
        assert_nothing_raised do
            Puppet::SUIDManager.uid
            Puppet::SUIDManager.uid
        end
    end

    def test_id_set
        if @run
            user = nonrootuser
            assert_nothing_raised do
                Puppet::SUIDManager.egid = user.gid
                Puppet::SUIDManager.euid = user.uid
            end
            
            assert_equal(Puppet::SUIDManager.euid, Process.euid)
            assert_equal(Puppet::SUIDManager.egid, Process.egid)

            assert_nothing_raised do
                Puppet::SUIDManager.euid = 0
                Puppet::SUIDManager.egid = 0
            end
        end
    end

    def test_utiluid
        user = nonrootuser.name
        if @run
            assert_not_equal(nil, Puppet::Util.uid(user))
        end
    end

    def test_asuser
        if @run
            user = nonrootuser
            uid, gid = [nil, nil]

            assert_nothing_raised do
                Puppet::SUIDManager.asuser(user.uid, user.gid) do 
                    uid = Process.euid
                    gid = Process.egid
                end
            end
            assert_equal(user.uid, uid)
            assert_equal(user.gid, gid)
        end
    end

    def test_system
        # NOTE: not sure what shells this will work on..
        if @run 
            user = nonrootuser
            status = Puppet::SUIDManager.system("exit $EUID", user.uid, user.gid)
            assert_equal(user.uid, status.exitstatus)
        end
    end

    def test_run_and_capture
        if (RUBY_VERSION <=> "1.8.4") < 0
            warn "Cannot run this test on ruby < 1.8.4"
        else
            # NOTE: because of the way that run_and_capture currently 
            # works, we cannot just blindly echo to stderr. This little
            # hack gets around our problem, but the real problem is the
            # way that run_and_capture works.
            user = nil
            uid = nil
            if Puppet::SUIDManager.uid == 0
                userobj = nonrootuser()
                user = userobj.name
                uid = userobj.uid
            else
                uid = Process.uid
            end
            cmd = [%{/bin/echo $EUID}]
            output = Puppet::SUIDManager.run_and_capture(cmd, uid)[0].chomp
            assert_equal(uid.to_s, output)
        end
    end
end

# $Id$
