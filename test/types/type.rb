#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet/type'
require 'puppettest'

class TestType < Test::Unit::TestCase
	include PuppetTest
    def test_typemethods
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

            assert_nothing_raised {
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

        # Verify our adding ourselves as an alias isn't an error.
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
        assert_equal(name, file.title)

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

    # Verify that objects can't be their own children.
    def test_object_recursion
        comp = Puppet.type(:component).create(:name => "top")

        file = Puppet.type(:file).create(:path => tempfile, :ensure => :file)

        assert_raise(Puppet::DevError) do
            comp.push(comp)
        end

        assert_raise(Puppet::DevError) do
            file.push(file)
        end

        assert_raise(Puppet::DevError) do
            comp.parent = comp
        end

        assert_raise(Puppet::DevError) do
            file.parent = file
        end

        assert_nothing_raised {
            comp.push(file)
        }

        assert_raise(Puppet::DevError) do
            file.push(comp)
        end

        assert_raise(Puppet::DevError) do
            comp.parent = file
        end
    end

    def test_loadplugins
        names = %w{loadedplugin1 loadplugin2 loadplugin3}
        dirs = []
        3.times { dirs << tempfile() }
        # Set plugindest to something random
        Puppet[:plugindest] = tempfile()

        Puppet[:pluginpath] = dirs.join(":")

        names.each do |name|
            dir = dirs.shift
            Dir.mkdir(dir)

            # Create an extra file for later
            [name, name + "2ness"].each do |n|
                file = File.join(dir, n + ".rb")
                File.open(file, "w") do |f|
                    f.puts %{Puppet::Type.newtype('#{n}') do
    newparam(:argument) do
        isnamevar
    end
end
}
                end
            end

            assert(Puppet::Type.type(name),
                "Did not get loaded plugin")

            assert_nothing_raised {
                Puppet::Type.type(name).create(
                    :name => "myname"
                )
            }
        end

        # Now make sure the plugindest got added to our pluginpath
        assert(Puppet[:pluginpath].split(":").include?(Puppet[:plugindest]),
            "Plugin dest did not get added to plugin path")

        # Now make sure it works with just a single path, using the extra files
        # created above.
        Puppet[:pluginpath] = Puppet[:pluginpath].split(":")[0]
        assert(Puppet::Type.type("loadedplugin12ness"),
            "Did not get loaded plugin")

    end

    def test_newtype_methods
        assert_nothing_raised {
            Puppet::Type.newtype(:mytype) do
                newparam(:wow) do isnamevar end
            end
        }

        assert(Puppet::Type.respond_to?(:newmytype),
            "new<type> method did not get created")

        obj = nil
        assert_nothing_raised {
            obj = Puppet::Type.newmytype(:wow => "yay")
        }

        assert(obj.is_a?(Puppet::Type.type(:mytype)),
            "Obj is not the correct type")

        # Now make the type again, just to make sure it works on refreshing.
        assert_nothing_raised {
            Puppet::Type.newtype(:mytype) do
                newparam(:yay) do isnamevar end
            end
        }

        obj = nil
        # Make sure the old class was thrown away and only the new one is sitting
        # around.
        assert_raise(Puppet::Error) {
            obj = Puppet::Type.newmytype(:wow => "yay")
        }
        assert_nothing_raised {
            obj = Puppet::Type.newmytype(:yay => "yay")
        }

        # Now make sure that we don't replace existing, non-type methods
        parammethod = Puppet::Type.method(:newparam)

        assert_nothing_raised {
            Puppet::Type.newtype(:param) do
                newparam(:rah) do isnamevar end
            end
        }
        assert_equal(parammethod, Puppet::Type.method(:newparam),
            "newparam method got replaced by newtype")
    end

    def test_newstate_options
        # Create a type with a fake provider
        providerclass = Class.new do
            def method_missing(method, *args)
                return method
            end
        end
        self.class.const_set("ProviderClass", providerclass)

        type = Puppet::Type.newtype(:mytype) do
            newparam(:name) do
                isnamevar
            end
            def provider
                @provider ||= ProviderClass.new

                @provider
            end
        end

        # Now make a state with no options.
        state = nil
        assert_nothing_raised do
            state = type.newstate(:noopts) do
            end
        end

        # Now create an instance
        obj = type.create(:name => :myobj)

        inst = state.new(:parent => obj)

        # And make sure it's correctly setting @is
        ret = nil
        assert_nothing_raised {
            ret = inst.retrieve
        }

        assert_equal(:noopts, inst.is)

        # Now create a state with a different way of doing it
        state = nil
        assert_nothing_raised do
            state = type.newstate(:setretrieve, :retrieve => :yayness)
        end

        inst = state.new(:parent => obj)

        # And make sure it's correctly setting @is
        ret = nil
        assert_nothing_raised {
            ret = inst.retrieve
        }

        assert_equal(:yayness, inst.is)
    end

    def test_name_vs_title
        path = tempfile()

        trans = nil

        assert_nothing_raised {
            trans = Puppet::TransObject.new(path, :file)
        }

        file = nil
        assert_nothing_raised {
            file = Puppet::Type.newfile(trans)
        }

        assert(file.respond_to?(:title),
            "No 'title' method")

        assert(file.respond_to?(:name),
            "No 'name' method")

        assert_equal(file.title, file.name,
            "Name and title were not marked equal")

        assert_nothing_raised {
            file.title = "My file"
        }

        assert_equal("My file", file.title)
        assert_equal(path, file.name)
    end

    # Make sure the title is sufficiently differentiated from the namevar.
    def test_title_at_creation_with_hash
        file = nil
        fileclass = Puppet::Type.type(:file) 

        path = tempfile()
        assert_nothing_raised do
            file = fileclass.create(
                :title => "Myfile",
                :path => path
            )
        end

        assert_equal("Myfile", file.title, "Did not get correct title")
        assert_equal(path, file[:name], "Did not get correct name")

        file = nil
        Puppet::Type.type(:file).clear

        # Now make sure we can specify both and still get the right answers
        assert_nothing_raised do
            file = fileclass.create(
                :title => "Myfile",
                :name => path
            )
        end

        assert_instance_of(fileclass, file)

        assert_equal("Myfile", file.title, "Did not get correct title")
        assert_equal(path, file[:name], "Did not get correct name")
    end

    # Make sure the "create" class method behaves appropriately.
    def test_class_create
        title = "Myfile"
        validate = proc do |element|
            assert(element, "Did not create file")
            assert_instance_of(Puppet::Type.type(:file), element)
            assert_equal(title, element.title, "Title is not correct")
        end
        type = :file
        args = {:path => tempfile(), :owner => "root"}

        trans = Puppet::TransObject.new(title, type)
        args.each do |name, val| trans[name] = val end

        # First call it on the appropriate typeclass
        obj = nil
        assert_nothing_raised do
            obj = Puppet::Type.type(:file).create(trans)
        end

        validate.call(obj)

        # Now try it using the class method on Type
        oldid = obj.object_id
        obj = nil
        Puppet::Type.type(:file).clear

        assert_nothing_raised {
            obj = Puppet::Type.create(trans)
        }

        validate.call(obj)
        assert(oldid != obj.object_id, "Got same object back")

        # Now try the same things with hashes instead of a transobject
        oldid = obj.object_id
        obj = nil
        Puppet::Type.type(:file).clear
        hash = {
            :type => :file,
            :title => "Myfile",
            :path => tempfile(),
            :owner => "root"
        }

        # First call it on the appropriate typeclass
        obj = nil
        assert_nothing_raised do
            obj = Puppet::Type.type(:file).create(hash)
        end

        validate.call(obj)
        assert_equal(:file, obj.should(:type),
            "Type param did not pass through")

        assert(oldid != obj.object_id, "Got same object back")

        # Now try it using the class method on Type
        oldid = obj.object_id
        obj = nil
        Puppet::Type.type(:file).clear

        assert_nothing_raised {
            obj = Puppet::Type.create(hash)
        }

        validate.call(obj)
        assert(oldid != obj.object_id, "Got same object back")
        assert_nil(obj.should(:type),
            "Type param passed through")
    end

    def test_multiplenames
        obj = nil
        path = tempfile()
        assert_raise ArgumentError do
            obj = Puppet::Type.type(:file).create(
                :name => path,
                :path => path
            )
        end
    end

    def test_title_and_name
        obj = nil
        path = tempfile()
        fileobj = Puppet::Type.type(:file)

        assert_nothing_raised do
            obj = fileobj.create(
                :title => "myfile",
                :path => path
            )
        end

        assert_equal(obj, fileobj["myfile"],
            "Could not retrieve obj by title")

        assert_equal(obj, fileobj[path],
            "Could not retrieve obj by name")
    end

    # Make sure default providers behave correctly
    def test_defaultproviders
        # Make a fake type
        type = Puppet::Type.newtype(:defaultprovidertest) do
            newparam(:name) do end
        end

        basic = type.provide(:basic) do
            defaultfor :operatingsystem => :somethingelse,
                :operatingsystemrelease => :yayness
        end

        assert_equal(basic, type.defaultprovider)
        type.defaultprovider = nil

        greater = type.provide(:greater) do
            defaultfor :operatingsystem => Facter.value("operatingsystem")
        end

        assert_equal(greater, type.defaultprovider)
    end

    # Make sure that we can have multiple isomorphic objects with the same name,
    # but not with non-isomorphic objects.
    def test_isomorphic_names
        # First do execs, since they're not isomorphic.
        echo = Puppet::Util.binary "echo"
        exec1 = exec2 = nil
        assert_nothing_raised do
            exec1 = Puppet::Type.type(:exec).create(
                :title => "exec1",
                :command => "#{echo} funtest"
            )
        end
        assert_nothing_raised do
            exec2 = Puppet::Type.type(:exec).create(
                :title => "exec2",
                :command => "#{echo} funtest"
            )
        end

        assert_apply(exec1, exec2)

        # Now do files, since they are. This should fail.
        file1 = file2 = nil
        path = tempfile()
        assert_nothing_raised do
            file1 = Puppet::Type.type(:file).create(
                :title => "file1",
                :path => path,
                :content => "yayness"
            )
        end

        # This will fail, but earlier systems will catch it.
        assert_raise(Puppet::Error) do
            file2 = Puppet::Type.type(:file).create(
                :title => "file2",
                :path => path,
                :content => "rahness"
            )
        end

        assert(file1, "Did not create first file")
        assert_nil(file2, "Incorrectly created second file")
    end

    def test_tags
        obj = Puppet::Type.type(:file).create(:path => tempfile())

        tags = [:some, :test, :tags]

        obj.tags = tags

        assert_equal(tags + [:file], obj.tags)
    end

    def disabled_test_list
        Puppet::Type.loadall

        Puppet::Type.eachtype do |type|
            next if type.name == :symlink
            next if type.name == :component
            next if type.name == :tidy
            assert(type.respond_to?(:list), "%s does not respond to list" % type.name)
        end
    end

    def test_to_hash
        file = Puppet::Type.newfile :path => tempfile(), :owner => "luke",
            :recurse => true, :loglevel => "warning"

        hash = nil
        assert_nothing_raised do
            hash = file.to_hash
        end

        [:path, :owner, :recurse, :loglevel].each do |param|
            assert(hash[param], "Hash did not include %s" % param)
        end
    end

    # Make sure that classes behave like hashes.
    def test_class_hash_behaviour
        path = tempfile()

        filetype = Puppet::Type.type(:file)
        one = Puppet::Type.newfile :path => path

        assert_equal(one, filetype[path], "Did not get file back")

        assert_raise(Puppet::Error) do
            filetype[path] = one
        end
    end

    def test_ref
        path = tempfile()
        file = Puppet::Type.newfile(:path => path)
        assert_equal("file[#{path}]", file.ref)

        exec = Puppet::Type.newexec(:title => "yay", :command => "/bin/echo yay")
        assert_equal("exec[yay]", exec.ref)
    end
end

# $Id$
