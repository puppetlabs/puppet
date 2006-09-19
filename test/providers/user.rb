require 'puppettest'
require 'puppet'
require 'facter'

class TestUserProvider < Test::Unit::TestCase
    include PuppetTest::FileTesting

    def setup
        super
        setme()
        @@tmpusers = []
        @provider = nil
        assert_nothing_raised {
            @provider = Puppet::Type.type(:user).defaultprovider
        }

        assert(@provider, "Could not find default user provider")

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

        def current?(param, user)
            state = Puppet.type(:user).states.find { |st|
                st.name == param
            }

            output = %x{nireport / /users name #{state.netinfokey}}
            output.split("\n").each { |line|
                if line =~ /^(\w+)\s+(.+)$/
                    username = $1
                    id = $2.sub(/\s+$/, '')
                    if username == user.name
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

        def current?(param, user)
            state = Puppet.type(:user).states.find { |st|
                st.name == param
            }

            assert_nothing_raised {
                obj = Etc.getpwnam(user.name)
                return obj.send(user.posixmethod(param))
            }

            return nil
        end

        def remove(user)
            system("userdel %s" % user)
        end
    end


    def eachstate
        Puppet::Type.type(:user).validstates.each do |state|
            yield state
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

    def fakedata(name, param)
        case param
        when :name: name
        when :ensure: :present
        when :comment: "Puppet Testing User %s" % name
        when :gid: nonrootgroup.name
        when :shell: findshell()
        when :home: "/home/%s" % name
        else
            return nil
        end
    end

    def mkuser(name)
        fakemodel = fakemodel(:user, name)
        user = nil
        assert_nothing_raised {
            user = @provider.new(fakemodel)
        }
        assert(user, "Could not create provider user")

        return user
    end

    def test_list
        names = nil
        assert_nothing_raised {
            names = @provider.listbyname
        }

        assert(names.length > 0, "Listed no users")

        # Now try it by object
        assert_nothing_raised {
            names = @provider.list
        }
        assert(names.length > 0, "Listed no users as objects")

        names.each do |obj|
            assert_instance_of(Puppet::Type.type(:user), obj)
            assert(obj[:provider], "Provider was not set")
        end
    end

    def test_infocollection
        fakemodel = fakemodel(:user, @me)

        user = nil
        assert_nothing_raised {
            user = @provider.new(fakemodel)
        }
        assert(user, "Could not create user provider")

        Puppet::Type.type(:user).validstates.each do |state|
            next if state == :ensure
            val = nil
            assert_nothing_raised {
                val = user.send(state)
            }

            assert(val != :absent,
                   "State %s is missing" % state)

            assert(val, "Did not get value for %s" % state)
        end
    end

    def test_exists
        user = mkuser("nosuchuserok")

        assert(! user.exists?,
               "Fake user exists?")

        user = mkuser(@me)
        assert(user.exists?,
               "I don't exist?")
    end

    def attrtest_ensure(user)
        old = user.ensure
        assert_nothing_raised {
            user.ensure = :absent
        }

        assert(missing?(user.name), "User is still present")
        assert_nothing_raised {
            user.ensure = :present
        }
        assert(!missing?(user.name), "User is absent")
        assert_nothing_raised {
            user.ensure = :absent
        }

        unless old == :absent
            user.ensure = old
        end
    end

    def attrtest_comment(user)
        old = user.comment

        assert_nothing_raised {
            user.comment = "A different comment"
        }

        assert_equal("A different comment", current?(:comment, user),
            "Comment was not changed")

        assert_nothing_raised {
            user.comment = old
        }

        assert_equal(old, current?(:comment, user),
            "Comment was not reverted")
    end

    def attrtest_home(user)
        old = current?(:home, user)

        assert_nothing_raised {
            user.home = "/tmp"
        }

        assert_equal("/tmp", current?(:home, user), "Home was not changed")
        assert_nothing_raised {
            user.home = old
        }

        assert_equal(old, current?(:home, user), "Home was not reverted")
    end

    def attrtest_shell(user)
        old = current?(:shell, user)

        newshell = findshell(old)

        unless newshell
            $stderr.puts "Cannot find alternate shell; skipping shell test"
            return
        end

        assert_nothing_raised {
            user.shell = newshell
        }

        assert_equal(newshell, current?(:shell, user),
            "Shell was not changed")

        assert_nothing_raised {
            user.shell = old
        }

        assert_equal(old, current?(:shell, user), "Shell was not reverted")
    end

    def attrtest_gid(user)
        old = current?(:gid, user)

        newgroup = %w{nogroup nobody staff users daemon}.find { |gid|
                begin
                    group = Etc.getgrnam(gid)
                rescue ArgumentError => detail
                    next
                end
                old != group.gid
        }
        group = Etc.getgrnam(newgroup)

        unless newgroup
            $stderr.puts "Cannot find alternate group; skipping gid test"
            return
        end

        assert_raise(ArgumentError, "gid allowed a non-integer value") do
            user.gid = group.name
        end

        assert_nothing_raised("Failed to specify group by id") {
            user.gid = group.gid
        }

        assert_equal(group.gid, current?(:gid,user), "GID was not changed")

        assert_nothing_raised("Failed to change back to old gid") {
            user.gid = old
        }
    end

    def attrtest_uid(user)
        old = current?(:uid, user)

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
            user.uid = newuid
        }

        assert_equal(newuid, current?(:uid, user), "UID was not changed")

        assert_nothing_raised("Failed to change user id") {
            user.uid = old
        }
        assert_equal(old, current?(:uid, user), "UID was not changed back")
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
            tmpgroup = Puppet.type(:group).create(
                :name => name,
                :gid => max + i
            )

            groups << tmpgroup

            cleanup do
                tmpgroup.provider.delete if tmpgroup.provider.exists?
            end

            if i < 3
                main << name
            else
                extra << name
            end
        end

        # Create our test groups
        assert_apply(*groups)

        # Now add some of them to our user
        assert_nothing_raised {
            user.model[:groups] = extra.join(",")
        }

        # Some tests to verify that groups work correctly startig from nothing
        # Remove our user
        user.ensure = :absent

        # And add it again
        user.ensure = :present

        # Make sure that the group list is added at creation time.
        # This is necessary because we don't have default fakedata for groups.
        assert(user.groups, "Did not retrieve group list")

        list = user.groups.split(",")
        assert_equal(extra.sort, list.sort, "Group list was not set at creation time")

        # Now set to our main list of groups
        assert_nothing_raised {
            user.groups = main.join(",")
        }

        list = user.groups.split(",")
        assert_equal(main.sort, list.sort, "Group list is not equal")
    end

    if Process.uid == 0
        def test_simpleuser
            name = "pptest"

            assert(missing?(name), "User %s is present" % name)

            user = mkuser(name)

            eachstate do |state|
                if val = fakedata(user.name, state)
                    user.model[state] = val
                end
            end

            @@tmpusers << name

            assert_nothing_raised {
                user.create
            }

            assert_equal("Puppet Testing User pptest",
                 user.comment,
                "Comment was not set")

            assert_nothing_raised {
                user.delete
            }

            assert(missing?(user.name), "User was not deleted")
        end

        def test_alluserstates
            user = nil
            name = "pptest"

            assert(missing?(name), "User %s is present" % name)

            user = mkuser(name)

            eachstate do |state|
                if val = fakedata(user.name, state)
                    user.model[state] = val
                end
            end

            @@tmpusers << name

            assert_nothing_raised {
                user.create
            }
            assert_equal("Puppet Testing User pptest", user.comment,
                "Comment was not set")

            tests = Puppet::Type.type(:user).validstates

            just = nil
            tests.each { |test|
                next unless test == :groups
                if self.respond_to?("attrtest_%s" % test)
                    self.send("attrtest_%s" % test, user)
                else
                    Puppet.err "Not testing attr %s of user" % test
                end
            }

            assert_nothing_raised {
                user.delete
            }
        end

        # This is a weird method that shows how annoying the interface between
        # types and providers is.  Grr.
        def test_duplicateIDs
            user1 = mkuser("user1")
            user1.create
            user1.uid = 125
            user2 = mkuser("user2")
            user2.model[:uid] = 125

            cleanup do
                user1.ensure = :absent
                user2.ensure = :absent
            end

            # Not all OSes fail here, so we can't test that it doesn't work with
            # it off, only that it does work with it on.
            assert_nothing_raised {
                user2.model[:allowdupe] = :true
            }
            assert_nothing_raised { user2.create }
            assert_equal(:present, user2.ensure,
                         "User did not get created")
        end
    else
        $stderr.puts "Not root; skipping user creation/modification tests"
    end

    # Here is where we test individual providers
    def test_useradd_flags
        useradd = nil
        assert_nothing_raised {
            useradd = Puppet::Type.type(:user).provider(:useradd)
        }
        assert(useradd, "Did not retrieve useradd provider")

        user = nil
        assert_nothing_raised {
            fakemodel = fakemodel(:user, @me)
            user = useradd.new(fakemodel)
        }

        assert_equal("-d", user.send(:flag, :home),
                    "Incorrect home flag")

        assert_equal("-s", user.send(:flag, :shell),
                    "Incorrect shell flag")
    end
end

# $Id$
