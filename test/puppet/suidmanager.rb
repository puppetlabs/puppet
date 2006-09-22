require 'test/unit'
require 'puppettest'

class TestProcess < Test::Unit::TestCase
    def setup
        if Process.uid != 0
            $stderr.puts "Process tests must be run as root"
            @run = false
        else 
            @run = true
        end
    end

    def test_id_set
        if @run
            # FIXME: use the test framework uid finder
            assert_nothing_raised do
                Puppet::SUIDManager.egid = 501
                Puppet::SUIDManager.euid = 501
            end
            
            assert_equal(Puppet::SUIDManager.euid, Process.euid)
            assert_equal(Puppet::SUIDManager.egid, Process.egid)

            assert_nothing_raised do
                Puppet::SUIDManager.euid = 0
                Puppet::SUIDManager.egid = 0
            end

            assert_uid_gid(501, 501)
        end
    end

    def test_asuser
        if @run
            uid, gid = [nil, nil]

            assert_nothing_raised do
                Puppet::SUIDManager.asuser(501, 501) do 
                    uid = Puppet::SUIDManager.euid
                    gid = Puppet::SUIDManager.egid
                end
            end

            assert_equal(501, uid)
            assert_equal(501, gid)
        end
    end

    def test_system
        # NOTE: not sure what shells this will work on..
        # FIXME: use the test framework uid finder, however the uid needs to be < 255
        if @run 
            Puppet::SUIDManager.system("exit $EUID", 10, 10)
            assert_equal($?.exitstatus, 10)
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
            output = Puppet::SUIDManager.run_and_capture("ruby -e '$stderr.puts \"foo\"'")[0].chomp
            assert_equal(output, 'foo')
        end
    end
end
