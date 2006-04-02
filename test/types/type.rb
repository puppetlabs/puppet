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

            # Skip types with no parameters or valid states
            #unless ! type.parameters.empty? or ! type.validstates.empty?
            #    next
            #end

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
                :ensure => "file",
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
                "ensure" => "file",
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
                :ensure => "file",
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

        comp = newcomp(twoobj, oneobj)

        assert_nothing_raised {
            comp.finalize
        }


        assert(twoobj.requires?(oneobj), "Requirement was not created")
    end

    # Verify that names are aliases, not equivalents
    def test_nameasalias
        file = nil
        # Create the parent dir, so we make sure autorequiring the parent dir works
        parentdir = tempfile()
        dir = Puppet.type(:file).create(
            :name => parentdir,
            :ensure => "directory"
        )
        assert_apply(dir)
        path = File.join(parentdir, "subdir")
        name = "a test file"
        transport = Puppet::TransObject.new(name, "file")
        transport[:path] = path
        transport[:ensure] = "file"
        assert_nothing_raised {
            file = transport.to_type
        }

        assert_equal(path, file[:path])
        assert_equal([name], file[:alias])

        assert_nothing_raised {
            file.retrieve
        }

        assert_apply(file)

        assert(Puppet.type(:file)[name], "Could not look up object by name")
    end

    def test_ensuredefault
        user = nil
        assert_nothing_raised {
            user = Puppet.type(:user).create(
                :name => "pptestAA",
                :check => [:uid]
            )
        }

        # make sure we don't get :ensure for unmanaged files
        assert(! user.state(:ensure), "User got an ensure state")

        assert_nothing_raised {
            user = Puppet.type(:user).create(
                :name => "pptestAA",
                :comment => "Testingness"
            )
        }
        # but make sure it gets added once we manage them
        assert(user.state(:ensure), "User did not add ensure state")

        assert_nothing_raised {
            user = Puppet.type(:user).create(
                :name => "pptestBB",
                :comment => "A fake user"
            )
        }

        # and make sure managed objects start with them
        assert(user.state(:ensure), "User did not get an ensure state")
    end

    # Make sure removal works
    def test_remove
        objects = {}
        top = Puppet.type(:component).create(:name => "top")
        objects[top.class] = top

        base = tempfile()

        # now make a two-tier, 5 piece tree
        %w{a b}.each do |letter|
            name = "comp%s" % letter
            comp = Puppet.type(:component).create(:name => name)
            top.push comp
            objects[comp.class] = comp

            5.times do |i|
                file = base + letter + i.to_s

                obj = Puppet.type(:file).create(:name => file, :ensure => "file")

                comp.push obj
                objects[obj.class] = obj
            end
        end

        assert_nothing_raised do
            top.remove
        end

        objects.each do |klass, obj|
            assert_nil(klass[obj.name], "object %s was not removed" % obj.name)
        end
    end
end

# $Id$
