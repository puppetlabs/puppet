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
        super
        @@tmpusers = []
    end

    def teardown
        @@tmpusers.each { |user|
            unless missing?(user)
                remove(user)
            end
        }
        super
        #Puppet.type(:user).clear
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
            state = Puppet.type(:user).states.find { |st|
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
            state = Puppet.type(:user).states.find { |st|
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
            user = Puppet.type(:user).create(
                :name => name,
                :comment => "Puppet Testing User",
                :gid => Process.gid,
                :shell => findshell(),
                :home => "/home/%s" % name
            )
        }

        return user
    end

    def attrtest_ensure(user)
        old = user.is(:ensure)
        user[:ensure] = :absent

        comp = newcomp("ensuretest", user)
        assert_apply(user)
        assert(missing?(user.name), "User is still present")
        user[:ensure] = :present
        assert_events([:user_created], comp)
        assert(!missing?(user.name), "User is absent")
        user[:ensure] = :absent
        trans = assert_events([:user_removed], comp)

        assert_rollback_events(trans, [:user_created], "user")

        user[:ensure] = old
        assert_apply(user)
    end

    def attrtest_comment(user)
        old = user.is(:comment)
        user[:comment] = "A different comment"

        comp = newcomp("commenttest", user)

        trans = assert_events([:user_modified], comp, "user")

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

        trans = assert_events([], comp, "user")

        user[:home] = "/tmp"

        trans = assert_events([:user_modified], comp, "user")

        assert_equal("/tmp", current?(:home, user[:name]), "Home was not changed")

        assert_rollback_events(trans, [:user_modified], "user")

        assert_equal(old, current?(:home, user[:name]), "Home was not reverted")
    end

    def attrtest_shell(user)
        old = current?(:shell, user[:name])
        comp = newcomp("shelltest", user)

        user[:shell] = old

        trans = assert_events([], comp, "user")

        newshell = findshell(old)

        unless newshell
            $stderr.puts "Cannot find alternate shell; skipping shell test"
            return
        end

        user[:shell] = newshell

        trans = assert_events([:user_modified], comp, "user")

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

        trans = assert_events([], comp, "user")

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

        trans = assert_events([:user_modified], comp, "user")

        # then by id
        newgid = Etc.getgrnam(newgid).gid

        assert_nothing_raised("Failed to specify group by id") {
            user[:gid] = newgid
        }

        user.retrieve

        assert_events([], comp, "user")

        assert_equal(newgid, current?(:gid,user[:name]), "GID was not changed")

        assert_rollback_events(trans, [:user_modified], "user")

        assert_equal(old, current?(:gid,user[:name]), "GID was not reverted")
    end

    def attrtest_uid(user)
        obj = nil
        comp = newcomp("uidtest", user)

        old = current?(:uid, user[:name])
        user[:uid] = old

        trans = assert_events([], comp, "user")

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

        trans = assert_events([:user_modified], comp, "user")

        assert_equal(newuid, current?(:uid, user[:name]), "UID was not changed")

        assert_rollback_events(trans, [:user_modified], "user")

        assert_equal(old, current?(:uid, user[:name]), "UID was not reverted")
    end

    def attrtest_groups(user)
        Etc.setgrent
        max = 0
        while group = Etc.getgrent
            if group.gid > max and group.gid < 5000
                max = group.gid
            end
        end

        groups = []
        main = []
        extra = []
        5.times do |i|
            i += 1
            name = "pptstgr%s" % i
            groups << Puppet.type(:group).create(
                :name => name,
                :gid => max + i
            )

            if i < 3
                main << name
            else
                extra << name
            end
        end

        # Create our test groups
        assert_apply(*groups)

        assert(user[:membership] == :minimum, "Membership did not default correctly")

        assert_nothing_raised {
            user.retrieve
        }

        # Now add some of them to our user
        assert_nothing_raised {
            user[:groups] = extra
        }
        assert_nothing_raised {
            user.retrieve
        }

        assert(user.state(:groups).is, "Did not retrieve group list")

        assert(!user.insync?, "User is incorrectly in sync")

        assert_events([:user_modified], user)

        assert_nothing_raised {
            user.retrieve
        }

        list = user.state(:groups).is
        assert_equal(extra.sort, list.sort, "Group list is not equal")

        # Now set to our main list of groups
        assert_nothing_raised {
            user[:groups] = main
        }

        assert_equal((main + extra).sort.join(","), user.state(:groups).should)

        assert_nothing_raised {
            user.retrieve
        }

        assert(!user.insync?, "User is incorrectly in sync")

        assert_events([:user_modified], user)

        assert_nothing_raised {
            user.retrieve
        }

        # We're not managing inclusively, so it should keep the old group
        # memberships and add the new ones
        list = user.state(:groups).is
        assert_equal((main + extra).sort, list.sort, "Group list is not equal")

        assert_nothing_raised {
            user[:membership] = :inclusive
        }
        assert_nothing_raised {
            user.retrieve
        }

        assert(!user.insync?, "User is incorrectly in sync")

        assert_events([:user_modified], user)
        assert_nothing_raised {
            user.retrieve
        }

        list = user.state(:groups).is
        assert_equal(main.sort, list.sort, "Group list is not equal")

        # Now delete our groups
        groups.each do |group|
            group[:ensure] = :absent
        end

        user.delete(:groups)

        assert_apply(*groups)
    end

    # Disabled, because this is testing too much internal implementation
    def disabled_test_eachmethod
        obj = Etc.getpwuid(Process.uid)

        assert(obj, "Could not retrieve test group object")

        Puppet.type(:user).validstates.each { |name|
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
            checks = Puppet.type(:user).validstates
            user = Puppet.type(:user).create(
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

            trans = assert_events([:user_created], comp, "user")

            assert_equal("Puppet Testing User", current?(:comment, user[:name]),
                "Comment was not set")

            assert_rollback_events(trans, [:user_removed], "user")

            assert(missing?(user[:name]))
        end

        def test_allstates
            user = nil
            name = "pptest"

            assert(missing?(name), "User %s is present" % name)

            user = mkuser(name)

            @@tmpusers << name

            comp = newcomp("usercomp", user)

            trans = assert_events([:user_created], comp, "user")

            user.retrieve
            assert_equal("Puppet Testing User", current?(:comment, user[:name]),
                "Comment was not set")

            tests = Puppet.type(:user).validstates

            tests.each { |test|
                if self.respond_to?("attrtest_%s" % test)
                    self.send("attrtest_%s" % test, user)
                else
                    Puppet.err "Not testing attr %s of user" % test
                end
            }

            user[:ensure] = :absent
            assert_apply(user)
        end

        def test_autorequire
            file = tempfile()
            user = Puppet.type(:user).create(
                :name => "pptestu",
                :home => file,
                :gid => "pptestg"
            )
            home = Puppet.type(:file).create(
                :path => file,
                :ensure => "directory"
            )
            group = Puppet.type(:group).create(
                :name => "pptestg"
            )
            comp = newcomp(user, group)
            comp.finalize
            comp.retrieve

            assert(user.requires?(group), "User did not require group")
            assert(user.requires?(home), "User did not require home dir")
        end
    else
        $stderr.puts "Not root; skipping user creation/modification tests"
    end
end
