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

class TestUser < Test::Unit::TestCase
	include TestPuppet
    def setup
        @@tmpusers = []
        Puppet[:loglevel] = :debug if __FILE__ == $0
        super
    end

    def teardown
        @@tmpusers.each { |user|
            unless missing?(user)
                remove(user)
            end
        }
        super
    end

    case Facter["operatingsystem"].value
    when "Darwin":
        def missing?(user)
            output = %x{nidump -r /users/#{user} / 2>/dev/null}.chomp

            if output == ""
                return true
            else
                return false
            end

            assert_equal("", output, "User %s is present:\n%s" % [user, output])
        end

        def current?(param, name)
            state = Puppet::Type::User.states.find { |st|
                st.name == param
            }

            output = %x{nireport / /users name #{state.netinfokey}}
            output.split("\n").each { |line|
                if line =~ /^(\w+)\s+(.+)$/
                    user = $1
                    id = $2.sub(/\s+$/, '')
                    if user == name
                        if id =~ /^[-0-9]+$/
                            return Integer(id)
                        else
                            return id
                        end
                    end
                else
                    raise "Could not match %s" % line
                end
            }

            return nil
        end

        def remove(user)
            system("niutil -destroy / /users/%s" % user)
        end
    else
        def missing?(user)
            begin
                obj = Etc.getpwnam(user)
                return false
            rescue ArgumentError
                return true
            end
        end

        def current?(param, name)
            state = Puppet::Type::User.states.find { |st|
                st.name == param
            }

            assert_nothing_raised {
                obj = Etc.getpwnam(name)
                return obj.send(state.posixmethod)
            }

            return nil
        end

        def remove(user)
            system("userdel %s" % user)
        end
    end

    def findshell(old = nil)
        %w{/bin/sh /bin/bash /sbin/sh /bin/ksh /bin/zsh /bin/csh /bin/tcsh
            /usr/bin/sh /usr/bin/bash /usr/bin/ksh /usr/bin/zsh /usr/bin/csh
            /usr/bin/tcsh}.find { |shell|
                if old
                    FileTest.exists?(shell) and shell != old
                else
                    FileTest.exists?(shell)
                end
        }
    end

    def mkuser(name)
        user = nil
        assert_nothing_raised {
            user = Puppet::Type::User.create(
                :name => name,
                :comment => "Puppet Testing User",
                :gid => Process.gid,
                :shell => findshell(),
                :home => "/home/%s" % name
            )
        }

        return user
    end

    def attrtest_comment(user)
        old = user.is(:comment)
        user[:comment] = "A different comment"

        comp = newcomp("commenttest", user)

        trans = assert_events(comp, [:user_modified], "user")

        assert_equal("A different comment", current?(:comment, user[:name]),
            "Comment was not changed")

        assert_rollback_events(trans, [:user_modified], "user")

        assert_equal(old, current?(:comment, user[:name]),
            "Comment was not reverted")
    end

    def attrtest_home(user)
        obj = nil
        comp = newcomp("hometest", user)

        old = current?(:home, user[:name])
        user[:home] = old

        trans = assert_events(comp, [], "user")

        user[:home] = "/tmp"

        trans = assert_events(comp, [:user_modified], "user")

        assert_equal("/tmp", current?(:home, user[:name]), "Home was not changed")

        assert_rollback_events(trans, [:user_modified], "user")

        assert_equal(old, current?(:home, user[:name]), "Home was not reverted")
    end

    def attrtest_shell(user)
        old = current?(:shell, user[:name])
        comp = newcomp("shelltest", user)

        user[:shell] = old

        trans = assert_events(comp, [], "user")

        newshell = findshell(old)

        unless newshell
            $stderr.puts "Cannot find alternate shell; skipping shell test"
            return
        end

        user[:shell] = newshell

        trans = assert_events(comp, [:user_modified], "user")

        assert_equal(newshell, current?(:shell, user[:name]),
            "Shell was not changed")

        assert_rollback_events(trans, [:user_modified], "user")

        assert_equal(old, current?(:shell, user[:name]), "Shell was not reverted")
    end

    def attrtest_gid(user)
        obj = nil
        old = current?(:gid,user.name)
        comp = newcomp("gidtest", user)

        user.retrieve

        user[:gid] = old

        trans = assert_events(comp, [], "user")

        newgid = %w{nogroup nobody staff users daemon}.find { |gid|
                begin
                    group = Etc.getgrnam(gid)
                rescue ArgumentError => detail
                    next
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

        user.retrieve

        assert_events(comp, [], "user")

        assert_equal(newgid, current?(:gid,user[:name]), "GID was not changed")

        assert_rollback_events(trans, [:user_modified], "user")

        assert_equal(old, current?(:gid,user[:name]), "GID was not reverted")
    end

    def attrtest_uid(user)
        obj = nil
        comp = newcomp("uidtest", user)

        old = current?(:uid, user[:name])
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

        assert_equal(newuid, current?(:uid, user[:name]), "UID was not changed")

        assert_rollback_events(trans, [:user_modified], "user")

        assert_equal(old, current?(:uid, user[:name]), "UID was not reverted")
    end

    # Disabled, because this is testing too much internal implementation
    def disabled_test_eachmethod
        obj = Etc.getpwuid(Process.uid)

        assert(obj, "Could not retrieve test group object")

        Puppet::Type::User.validstates.each { |name|
            assert_nothing_raised {
                method = state.posixmethod
                assert(method, "State %s has no infomethod" % name)
                assert(obj.respond_to?(method),
                    "State %s has an invalid method %s" %
                    [name, method])
            }
        }
    end

    def test_checking
        require 'etc'

        name = nil
        assert_nothing_raised {
            name = Etc.getpwuid(Process.uid).name
        }
        user = nil
        assert_nothing_raised {
            checks = Puppet::Type::User.validstates
            user = Puppet::Type::User.create(
                :name => name,
                :check => checks
            )
        }

        assert_nothing_raised {
            user.retrieve
        }

        assert_equal(Process.uid, user.is(:uid), "Retrieved UID does not match")
    end

    if Process.uid == 0
        def test_simpleuser
            name = "pptest"

            assert(missing?(name), "User %s is present" % name)

            user = mkuser(name)

            @@tmpusers << name

            comp = newcomp("usercomp", user)

            trans = assert_events(comp, [:user_created], "user")

            assert_equal("Puppet Testing User", current?(:comment, user[:name]),
                "Comment was not set")

            assert_rollback_events(trans, [:user_deleted], "user")

            assert(missing?(user[:name]))
        end

        def test_allstates
            user = nil
            name = "pptest"

            assert(missing?(name), "User %s is present" % name)

            user = mkuser(name)

            @@tmpusers << name

            comp = newcomp("usercomp", user)

            trans = assert_events(comp, [:user_created], "user")

            assert_equal("Puppet Testing User", current?(:comment, user[:name]),
                "Comment was not set")

            tests = Puppet::Type::User.validstates

            user.retrieve
            tests.each { |test|
                if self.respond_to?("attrtest_%s" % test)
                    self.send("attrtest_%s" % test, user)
                else
                    $stderr.puts "Not testing attr %s of user" % test
                end
            }
        end
    else
        $stderr.puts "Not root; skipping user creation/modification tests"
    end
end
