if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

# $Id$

require 'etc'
require 'puppet/type'
require 'puppettest'
require 'test/unit'

class TestUser < TestPuppet
    def setup
        @@tmpusers = []
        Puppet[:loglevel] = :debug if __FILE__ == $0
        super
    end

    def teardown
        @@tmpusers.each { |user|
            begin
                obj = Etc.getpwnam(user)
                system("userdel %s" % user)
            rescue ArgumentError => detail
                # no such user, so we're fine
            end
        }
        super
    end

    def attrtest_comment(user)
        old = user.is(:comment)
        user[:comment] = "A different comment"

        comp = newcomp("commenttest", user)

        trans = assert_events(comp, [:user_modified], "user")

        obj = nil
        assert_nothing_raised {
            obj = Etc.getpwnam(user[:name])
        }

        assert_equal("A different comment", obj.gecos, "Comment was not changed")

        assert_rollback_events(trans, [:user_modified], "user")

        assert_nothing_raised {
            obj = Etc.getpwnam(user[:name])
        }

        assert_equal(old, obj.gecos, "Comment was not reverted")
    end

    def attrtest_home(user)
        obj = nil
        assert_nothing_raised {
            obj = Etc.getpwnam(user[:name])
        }
        old = obj.dir
        comp = newcomp("hometest", user)

        user[:home] = old

        trans = assert_events(comp, [], "user")

        user[:home] = "/tmp"

        trans = assert_events(comp, [:user_modified], "user")

        obj = nil
        assert_nothing_raised {
            obj = Etc.getpwnam(user[:name])
        }

        assert_equal("/tmp", obj.dir, "Home was not changed")

        assert_rollback_events(trans, [:user_modified], "user")

        assert_nothing_raised {
            obj = Etc.getpwnam(user[:name])
        }

        assert_equal(old, obj.dir, "Home was not reverted")
    end

    def attrtest_shell(user)
        obj = nil
        assert_nothing_raised {
            obj = Etc.getpwnam(user[:name])
        }
        old = obj.shell
        comp = newcomp("shelltest", user)

        user[:shell] = old

        trans = assert_events(comp, [], "user")

        newshell = %w{/bin/sh /bin/bash /sbin/sh /bin/ksh /bin/zsh /bin/csh /bin/tcsh
            /usr/bin/sh /usr/bin/bash /usr/bin/ksh /usr/bin/zsh /usr/bin/csh
            /usr/bin/tcsh}.find { |shell|
                FileTest.exists?(shell) and shell != old
        }

        unless newshell
            $stderr.puts "Cannot find alternate shell; skipping shell test"
            return
        end

        user[:shell] = newshell

        trans = assert_events(comp, [:user_modified], "user")

        obj = nil
        assert_nothing_raised {
            obj = Etc.getpwnam(user[:name])
        }

        assert_equal(newshell, obj.shell, "Shell was not changed")

        assert_rollback_events(trans, [:user_modified], "user")

        assert_nothing_raised {
            obj = Etc.getpwnam(user[:name])
        }

        assert_equal(old, obj.shell, "Shell was not reverted")
    end

    def attrtest_gid(user)
        obj = nil
        assert_nothing_raised {
            obj = Etc.getpwnam(user[:name])
        }
        old = obj.gid
        comp = newcomp("gidtest", user)

        user[:gid] = old

        trans = assert_events(comp, [], "user")

        newgid = %w{nogroup nobody staff users daemon}.find { |gid|
                begin
                    group = Etc.getgrnam(gid)
                rescue ArgumentError => detail
                    false
                end
                old != group.gid
        }

        unless newgid
            $stderr.puts "Cannot find alternate group; skipping gid test"
            return
        end

        # first test by name
        assert_nothing_raised("Failed to specify group by name") {
            user[:gid] = newgid
        }

        trans = assert_events(comp, [:user_modified], "user")

        # then by id
        newgid = Etc.getgrnam(newgid).gid

        assert_nothing_raised("Failed to specify group by id") {
            user[:gid] = newgid
        }

        assert_events(comp, [], "user")

        obj = nil
        assert_nothing_raised {
            obj = Etc.getpwnam(user[:name])
        }

        assert_equal(newgid, obj.gid, "GID was not changed")

        assert_rollback_events(trans, [:user_modified], "user")

        assert_nothing_raised {
            obj = Etc.getpwnam(user[:name])
        }

        assert_equal(old, obj.gid, "GID was not reverted")
    end

    def attrtest_uid(user)
        obj = nil
        assert_nothing_raised {
            obj = Etc.getpwnam(user[:name])
        }
        old = obj.uid
        comp = newcomp("uidtest", user)

        user[:uid] = old

        trans = assert_events(comp, [], "user")

        newuid = old
        while true
            newuid += 1

            if newuid - old > 1000
                $stderr.puts "Could not find extra test UID"
                return
            end
            begin
                newuser = Etc.getpwuid(newuid)
            rescue ArgumentError => detail
                break
            end
        end

        assert_nothing_raised("Failed to change user id") {
            user[:uid] = newuid
        }

        trans = assert_events(comp, [:user_modified], "user")

        obj = nil
        assert_nothing_raised {
            obj = Etc.getpwnam(user[:name])
        }

        assert_equal(newuid, obj.uid, "UID was not changed")

        assert_rollback_events(trans, [:user_modified], "user")

        assert_nothing_raised {
            obj = Etc.getpwnam(user[:name])
        }

        assert_equal(old, obj.uid, "UID was not reverted")
    end

    def test_eachmethod
        obj = Etc.getpwuid(Process.uid)

        assert(obj, "Could not retrieve test group object")

        Puppet::Type::User.validstates.each { |name, state|
            assert_nothing_raised {
                method = state.infomethod
                assert(method, "State %s has no infomethod" % name)
                assert(obj.respond_to?(method), "State %s has an invalid method %s" %
                    [name, method])
            }
        }
    end

    if Process.uid == 0
        def test_simpleuser
            user = nil
            name = "pptest"

            assert_raise(ArgumentError) {
                Etc.getpwnam(name)
            }

            assert_nothing_raised {
                user = Puppet::Type::User.new(
                    :name => name,
                    :comment => "Puppet Testing User"
                )
            }

            comp = newcomp("usercomp", user)

            trans = assert_events(comp, [:user_created], "user")

            @@tmpusers << name

            obj = nil
            assert_nothing_raised {
                obj = Etc.getpwnam(name)
            }

            assert_equal("Puppet Testing User", obj.gecos, "Comment was not set")

            tests = Puppet::Type::User.validstates.collect { |name, state|
                state.name
            }

            user.retrieve
            tests.each { |test|
                if self.respond_to?("attrtest_%s" % test)
                    self.send("attrtest_%s" % test, user)
                else
                    $stderr.puts "Not testing attr %s of user" % test
                end
            }

            assert_rollback_events(trans, [:user_deleted], "user")

            assert_raise(ArgumentError) {
                Etc.getpwnam(user[:name])
            }
        end
    else
        $stderr.puts "Not root; skipping user creation/modification tests"
    end
end
