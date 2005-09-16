if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

# $Id$

require 'puppet/type'
require 'puppettest'
require 'test/unit'

class TestType < TestPuppet
    def test_typemethods
        assert_nothing_raised() {
            Puppet::Type.buildstatehash
        }

        Puppet::Type.eachtype { |type|
            name = nil
            assert_nothing_raised("Searching for name for %s caused failure" %
                type.to_s) {
                    name = type.name
            }

            assert(name, "Could not find name for %s" % type.to_s)

            assert_equal(
                type,
                Puppet::Type.type(name),
                "Failed to retrieve %s by name" % name
            )

            assert(
                type.namevar,
                "Failed to retrieve namevar for %s" % name
            )

            assert_not_nil(
                type.states,
                "States for %s are nil" % name
            )

            assert_not_nil(
                type.validstates,
                "Valid states for %s are nil" % name
            )
        }
    end

    def test_stringvssymbols
        file = nil
        path = "/tmp/testfile"
        assert_nothing_raised() {
            system("rm -f %s" % path)
            file = Puppet::Type::PFile.create(
                :path => path,
                :create => true,
                :recurse => true,
                :checksum => "md5"
            )
        }
        assert_nothing_raised() {
            file.retrieve
        }
        assert_nothing_raised() {
            file.sync
        }
        Puppet::Type::PFile.clear
        assert_nothing_raised() {
            system("rm -f %s" % path)
            file = Puppet::Type::PFile.create(
                "path" => path,
                "create" => true,
                "recurse" => true,
                "checksum" => "md5"
            )
        }
        assert_nothing_raised() {
            file.retrieve
        }
        assert_nothing_raised() {
            file[:path]
        }
        assert_nothing_raised() {
            file["path"]
        }
        assert_nothing_raised() {
            file[:recurse]
        }
        assert_nothing_raised() {
            file["recurse"]
        }
        assert_nothing_raised() {
            file.sync
        }
    end

    # This was supposed to test objects whose name was a state, but that
    # fundamentally doesn't make much sense, and we now don't have any such
    # types.
    def disabled_test_nameasstate
        # currently groups are the only objects with the namevar as a state
        group = nil
        assert_nothing_raised {
            group = Puppet::Type::Group.create(
                :name => "testing"
            )
        }

        assert_equal("testing", group.name, "Could not retrieve name")
    end
end
