if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = ".."
end

require 'puppet'
require 'puppettest'
require 'test/unit'

class TestPuppetUtil < Test::Unit::TestCase
    include TestPuppet
    unless Process.uid == 0
        $stderr.puts "Run as root to perform Utility tests"
    else

    def mknverify(file, user, group = nil, id = false)
        if File.exists?(file)
            File.unlink(file)
        end
        args = []
        unless user or group
            args << nil
        end
        if user
            if id
                args << user.uid
            else
                args << user.name
            end
        end

        if group
            if id
                args << group.gid
            else
                args << group.name
            end
        end

        gid = nil
        if group
            gid = group.gid
        else
            gid = Process.gid
        end

        uid = nil
        if user
            uid = user.uid
        else
            uid = Process.uid
        end

        assert_nothing_raised {
            Puppet::Util.asuser(*args) {
                assert_equal(Process.euid, uid, "UID is %s instead of %s" %
                    [Process.euid, uid]
                )
                assert_equal(Process.egid, gid, "GID is %s instead of %s" %
                    [Process.egid, gid]
                )
                system("touch %s" % file)
            }
        }
        if uid == 0
            #Puppet.warning "Not testing user"
        else
            #Puppet.warning "Testing user %s" % uid
            assert(File.exists?(file), "File does not exist")
            assert_equal(File.stat(file).uid, uid,
                "File is owned by %s instead of %s" %
                [File.stat(file).uid, uid]
            )
            #system("ls -l %s" % file)
        end
        if gid == 0
            #Puppet.warning "Not testing group"
        else
            #Puppet.warning "Testing group %s" % gid
            assert_equal(File.stat(file).gid, gid,
                "File group is %s instead of %s" %
                [File.stat(file).gid, gid]
            )
            #system("ls -l %s" % file)
        end
        assert_nothing_raised {
            File.unlink(file)
        }
    end

    def test_asuser
        file = File.join(tmpdir, "asusertest")
        @@tmpfiles << file
        [
            [nil], # Nothing
            [nonrootuser()], # just user, by name
            [nonrootuser(), nil, true], # user, by uid
            [nonrootuser(), nonrootgroup()], # user and group, by name
            [nonrootuser(), nonrootgroup(), true], # user and group, by id
        ].each { |ary|
            mknverify(file, *ary)
        }
    end

    # Verify that we get reset back to the right user
    def test_asuser_recovery
        begin
            Puppet::Util.asuser(nonrootuser()) {
                raise "an error"
            }
        rescue
        end

        assert(Process.euid == 0, "UID did not get reset")
    end
    end
end

# $Id$
