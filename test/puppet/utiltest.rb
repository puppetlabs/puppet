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

    # we're getting corrupt files, probably because multiple processes
    # are reading or writing the file at once
    # so we need to test that
    def test_multiwrite
        file = tempfile()
        File.open(file, "w") { |f| f.puts "starting" }

        value = {:a => :b}
        threads = []
        sync = Sync.new
        9.times { |a|
            threads << Thread.new {
                9.times { |b|
                    assert_nothing_raised {
                        sync.synchronize(Sync::SH) {
                            Puppet::Util.readlock(file) { |f|
                                f.read
                            }
                        }
                        sleep 0.01
                        sync.synchronize(Sync::EX) {
                            Puppet::Util.writelock(file) { |f|
                                f.puts "%s %s" % [a, b]
                            }
                        }
                    }
                }
            }
        }
        threads.each { |th| th.join }
    end

    # First verify we can convert a known user
    def test_gidbyname
        %x{groups}.split(" ").each { |group|
            gid = nil
            assert_nothing_raised {
                gid = Puppet::Util.gid(group)
            }

            assert(gid, "Could not retrieve gid for %s" % group)

            assert(Puppet.type(:group)[group], "Util did not create %s" % group)
        }
    end

    # Then verify we can retrieve a known group by gid
    def test_gidbyid
        %x{groups}.split(" ").each { |group|
            obj = Puppet.type(:group).create(
                :name => group,
                :check => [:gid]
            )
            obj.retrieve
            id = obj.is(:gid)
            gid = nil
            assert_nothing_raised {
                gid = Puppet::Util.gid(id)
            }

            assert(gid, "Could not retrieve gid for %s" % group)
            assert_equal(id, gid, "Got mismatched ids")
        }
    end

    # Finally, verify that we can find groups by id even if we don't
    # know them
    def test_gidbyunknownid
        gid = nil
        group = Process.gid
        assert_nothing_raised {
            gid = Puppet::Util.gid(group)
        }

        assert(gid, "Could not retrieve gid for %s" % group)
        assert_equal(group, gid, "Got mismatched ids")
    end

    def user
        require 'etc'
        unless defined? @user
            obj = Etc.getpwuid(Process.uid)
            @user = obj.name
        end
        return @user
    end

    # And do it all over again for users
    # First verify we can convert a known user
    def test_uidbyname
        user = user()
        uid = nil
        assert_nothing_raised {
            uid = Puppet::Util.uid(user)
        }

        assert(uid, "Could not retrieve uid for %s" % user)
        assert_equal(Process.uid, uid, "UIDs did not match")
        assert(Puppet.type(:user)[user], "Util did not create %s" % user)
    end

    # Then verify we can retrieve a known user by uid
    def test_uidbyid
        user = user()
        obj = Puppet.type(:user).create(
            :name => user,
            :check => [:uid]
        )
        obj.retrieve
        id = obj.is(:uid)
        uid = nil
        assert_nothing_raised {
            uid = Puppet::Util.uid(id)
        }

        assert(uid, "Could not retrieve uid for %s" % user)
        assert_equal(id, uid, "Got mismatched ids")
    end

    # Finally, verify that we can find users by id even if we don't
    # know them
    def test_uidbyunknownid
        uid = nil
        user = Process.uid
        assert_nothing_raised {
            uid = Puppet::Util.uid(user)
        }

        assert(uid, "Could not retrieve uid for %s" % user)
        assert_equal(user, uid, "Got mismatched ids")
    end

    def test_withumask
        File.umask(022)

        path = tempfile()
        Puppet::Util.withumask(000) do
            Dir.mkdir(path, 01777)
        end

        assert(File.stat(path).mode & 007777 == 01777)
        assert_equal(022, File.umask)
    end

    unless Process.uid == 0
        $stderr.puts "Run as root to perform Utility tests"
        def test_nothing
        end
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
        # I'm skipping these, because it seems so system dependent.
        #if gid == 0
        #    #Puppet.warning "Not testing group"
        #else
        #    Puppet.warning "Testing group %s" % gid.inspect
        #    system("ls -l %s" % file)
        #    assert_equal(gid, File.stat(file).gid,
        #        "File group is %s instead of %s" %
        #        [File.stat(file).gid, gid]
        #    )
        #end
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
