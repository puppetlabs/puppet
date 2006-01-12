if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet/type'
require 'puppettest'
require 'test/unit'

class TestType < Test::Unit::TestCase
	include TestPuppet
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
        path = tempfile()
        assert_nothing_raised() {
            system("rm -f %s" % path)
            file = Puppet.type(:file).create(
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
            file.evaluate
        }
        Puppet.type(:file).clear
        assert_nothing_raised() {
            system("rm -f %s" % path)
            file = Puppet.type(:file).create(
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
            file.evaluate
        }
    end

    # This was supposed to test objects whose name was a state, but that
    # fundamentally doesn't make much sense, and we now don't have any such
    # types.
    def disabled_test_nameasstate
        # currently groups are the only objects with the namevar as a state
        group = nil
        assert_nothing_raised {
            group = Puppet.type(:group).create(
                :name => "testing"
            )
        }

        assert_equal("testing", group.name, "Could not retrieve name")
    end

    # Verify that values get merged correctly
    def test_mergestatevalues
        file = tempfile()

        # Create the first version
        assert_nothing_raised {
            Puppet.type(:file).create(
                :path => file,
                :owner => ["root", "bin"]
            )
        }

        # Make sure no other statements are allowed
        assert_raise(Puppet::Error) {
            Puppet.type(:file).create(
                :path => file,
                :group => "root"
            )
        }
    end

    # Verify that aliasing works
    def test_aliasing
        file = tempfile()

        baseobj = nil
        assert_nothing_raised {
            baseobj = Puppet.type(:file).create(
                :name => file,
                :create => true,
                :alias => ["funtest"]
            )
        }

        # Verify we adding ourselves as an alias isn't an error.
        assert_nothing_raised {
            baseobj[:alias] = file
        }

        assert_instance_of(Puppet.type(:file), Puppet.type(:file)["funtest"],
            "Could not retrieve alias")

    end

    # Verify that requirements don't depend on file order
    def test_prereqorder
        one = tempfile()
        two = tempfile()

        twoobj = nil
        oneobj = nil
        assert_nothing_raised("Could not create prereq that doesn't exist yet") {
            twoobj = Puppet.type(:file).create(
                :name => two,
                :require => [:file, one]
            )
        }

        assert_nothing_raised {
            oneobj = Puppet.type(:file).create(
                :name => one
            )
        }

        assert_nothing_raised {
            Puppet::Type.finalize
        }


        assert(twoobj.requires?(oneobj), "Requirement was not created")
    end
end

# $Id$
