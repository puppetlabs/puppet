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

class TestGroup < TestPuppet
    def setup
        @@tmpgroups = []
        super
    end

    def teardown
        Puppet::Type::Group.clear
        if Facter["operatingsystem"].value == "Darwin"
            Puppet::State::GroupNInfo.flush()
        end
        @@tmpgroups.each { |group|
            unless missing?(group)
                remove(group)
            end
        }
        super
    end

    case Facter["operatingsystem"].value
    when "Darwin":
        def missing?(group)
            output = %x{nidump -r /groups/#{group} / 2>/dev/null}.chomp

            if output == ""
                return true
            else
                return false
            end

            assert_equal("", output, "Group %s is present:\n%s" % [group, output])
        end

        def gid(name)
            %x{nireport / /groups name gid}.split("\n").each { |line|
                group, id = line.chomp.split(/\s+/)
                if group == name
                    return Integer(id)
                end
            }

            return nil
        end

        def remove(group)
            system("niutil -destroy / /groups/%s" % group)
        end
    else
        def missing?(group)
            begin
                obj = Etc.getgrnam(group)
                return false
            rescue ArgumentError
                return true
            end
        end

        def gid(name)
            assert_nothing_raised {
                obj = Etc.getgrnam(name)
                return obj.gid
            }

            return nil
        end

        def remove(group)
            system("groupdel %s" % group)
        end
    end

    def groupnames
        %x{groups}.chomp.split(/ /)
    end

    def groupids
        Process.groups
    end

    def attrtest_gid(group)
        obj = nil
        #assert_nothing_raised {
        #    obj = Etc.getgrnam(group[:name])
        #}
        group.retrieve
        old = gid(group[:name])
        comp = newcomp("gidtest", group)

        group[:gid] = old

        trans = assert_events(comp, [], "group")

        newgid = old
        while true
            newgid += 1

            if newgid - old > 1000
                $stderr.puts "Could not find extra test UID"
                return
            end
            begin
                Etc.getgrgid(newgid)
            rescue ArgumentError => detail
                break
            end
        end

        assert_nothing_raised("Failed to change group id") {
            group[:gid] = newgid
        }

        trans = assert_events(comp, [:group_modified], "group")

        curgid = nil
        assert_nothing_raised {
            curgid = gid(group[:name])
        }

        assert_equal(newgid, curgid, "GID was not changed")

        assert_rollback_events(trans, [:group_modified], "group")

        assert_nothing_raised {
            curgid = gid(group[:name])
        }

        assert_equal(old, curgid, "UID was not reverted")
    end

    def test_eachmethod
        obj = Etc.getgrnam(groupnames()[0])

        assert(obj, "Could not retrieve test group object")

        Puppet::Type::Group.validstates.each { |name, state|
            assert_nothing_raised {
                method = state.infomethod
                assert(method, "State %s has no infomethod" % name)
                assert(obj.respond_to?(method),
                    "State %s has an invalid method %s" %
                    [name, method]
                )
            }

            assert_nothing_raised {
                method = state.infomethod
                assert(method, "State %s has no infomethod" % name)
                assert(obj.respond_to?(method),
                    "State %s has an invalid method %s" %
                    [name, method]
                )
            }
        }
    end

    def test_owngroups
        groupnames().each { |group|
            gobj = nil
            comp = nil
            assert_nothing_raised {
                gobj = Puppet::Type::Group.new(
                    :name => group,
                    :check => [:gid]
                )

                comp = newcomp("grouptest %s" % group, gobj)
            }

            trans = nil
            assert_nothing_raised {
                trans = comp.evaluate
            }

            assert(gobj.is(:gid), "Failed to retrieve gid")
        }
    end

    if Process.uid == 0
        def test_mkgroup
            gobj = nil
            comp = nil
            name = "pptestgr"

            os = Facter["operatingsystem"].value

            #if os == "Darwin"
            #    obj = nil
            #    assert_nothing_raised {
            #        obj = Etc.getgrnam(name)
            #    }
            #    assert_equal(-2, obj.gid, "Darwin GID is not -2")
            #else
                #assert_raise(ArgumentError) {
                #    obj = Etc.getgrnam(name)
                #}
            #end
            assert(missing?(name), "Group %s is still present" % name)

            assert_nothing_raised {
                gobj = Puppet::Type::Group.new(
                    :name => name
                )

                comp = newcomp("groupmaker %s" % name, gobj)
            }

            @@tmpgroups << name
            case Facter["operatingsystem"].value
            when "Darwin":
                trans = assert_events(comp, [:group_created, :group_modified],
                    "group")
            else
                trans = assert_events(comp, [:group_created],
                    "group")
            end

            obj = nil
            assert_nothing_raised {
                obj = Etc.getgrnam(name)
            }
            assert(!missing?(name), "Group %s is missing" % name)

            tests = Puppet::Type::Group.validstates.collect { |sname, state|
                state.name
            }

            gobj.retrieve
            tests.each { |test|
                if self.respond_to?("attrtest_%s" % test)
                    self.send("attrtest_%s" % test, gobj)
                else
                    #$stderr.puts "Not testing attr %s of group" % test
                end
            }

            assert_rollback_events(trans, [:group_deleted], "group")

            assert(missing?(name), "Group %s is still present" % name)
        end
    else
        $stderr.puts "Not running as root; skipping group creation tests."
    end
end
