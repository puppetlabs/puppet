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
        Puppet[:loglevel] = :debug if __FILE__ == $0
        @@tmpgroups = []
        super
    end

    def teardown
        @@tmpgroups.each { |group|
            begin
                obj = Etc.getgrnam(group)
                system("groupdel %s" % group)
            rescue ArgumentError => detail
                # no such group, so we're fine
            end
        }
        super
    end

    def groupnames
        %x{groups}.chomp.split(/ /)
    end

    def groupids
        Process.groups
    end

    def test_eachmethod
        obj = Etc.getgrnam(groupnames()[0])

        assert(obj, "Could not retrieve test group object")

        Puppet::Type::Group.validstates.each { |name, state|
            assert_nothing_raised {
                method = state.infomethod
                assert(method, "State %s has no infomethod" % name)
                assert(obj.respond_to?(method), "State %s has an invalid method %s" %
                    [name, method])
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

            assert_raise(ArgumentError) {
                obj = Etc.getgrnam(name)
            }
            assert_nothing_raised {
                gobj = Puppet::Type::Group.new(
                    :name => name
                )

                comp = newcomp("groupmaker %s" % name, gobj)
            }

            trans = assert_events(comp, [:group_created], "group")
            @@tmpgroups << name

            obj = nil
            assert_nothing_raised {
                obj = Etc.getgrnam(name)
            }

            assert_rollback_events(trans, [:group_deleted], "group")

            assert_raise(ArgumentError) {
                obj = Etc.getgrnam(name)
            }
        end
    else
        $stderr.puts "Not running as root; skipping group creation tests."
    end
end
