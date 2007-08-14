#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'facter'

require 'puppet'
require 'puppet/parser/interpreter'
require 'puppet/parser/parser'
require 'puppet/network/client'
require 'puppettest'
require 'puppettest/resourcetesting'
require 'puppettest/parsertesting'
require 'puppettest/servertest'
require 'timeout'

class TestInterpreter < PuppetTest::TestCase
	include PuppetTest
    include PuppetTest::ServerTest
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
    AST = Puppet::Parser::AST
    NodeDef = Puppet::Parser::Interpreter::NodeDef

    # create a simple manifest that uses nodes to create a file
    def mknodemanifest(node, file)
        createdfile = tempfile()

        File.open(file, "w") { |f|
            f.puts "node %s { file { \"%s\": ensure => file, mode => 755 } }\n" %
                [node, createdfile]
        }

        return [file, createdfile]
    end

    def test_simple
        file = tempfile()
        File.open(file, "w") { |f|
            f.puts "file { \"/etc\": owner => root }"
        }
        assert_nothing_raised {
            Puppet::Parser::Interpreter.new(:Manifest => file)
        }
    end

    def test_reloadfiles
        hostname = Facter["hostname"].value

        file = tempfile()

        # Create a first version
        createdfile = mknodemanifest(hostname, file)

        interp = nil
        assert_nothing_raised {
            interp = Puppet::Parser::Interpreter.new(:Manifest => file)
        }

        config = nil
        assert_nothing_raised {
            config = interp.run(hostname, {})
        }
        sleep(1)

        # Now create a new file
        createdfile = mknodemanifest(hostname, file)

        newconfig = nil
        assert_nothing_raised {
            newconfig = interp.run(hostname, {})
        }

        assert(config != newconfig, "Configs are somehow the same")
    end

    # Make sure searchnode behaves as we expect.
    def test_nodesearch
        # We use two sources here to catch a weird bug where the default
        # node is used if the host isn't in the first source.
        interp = mkinterp

        # Make some nodes
        names = %w{node1 node2 node2.domain.com}
        interp.newnode names
        interp.newnode %w{default}

        nodes = {}
        # Make sure we can find them all, using the direct method
        names.each do |name|
            nodes[name] = interp.nodesearch_code(name)
            assert(nodes[name], "Could not find %s" % name)
            nodes[name].file = __FILE__
        end

        # Now let's try it with the nodesearch method
        names.each do |name|
            node = interp.nodesearch(name)
            assert(node, "Could not find #{name} via nodesearch")
        end

        # Make sure we find the default node when we search for nonexistent nodes
        assert_nothing_raised do
            default = interp.nodesearch("nosuchnode")
            assert(default, "Did not find default node")
            assert_equal("default", default.classname)
        end

        # Now make sure the longest match always wins
        node = interp.nodesearch(*%w{node2 node2.domain.com})

        assert(node, "Did not find node2")
        assert_equal("node2.domain.com", node.classname,
            "Did not get longest match")
    end

    def test_parsedate
        Puppet[:filetimeout] = 0
        main = tempfile()
        sub = tempfile()
        mainfile = tempfile()
        subfile = tempfile()
        count = 0
        updatemain = proc do
            count += 1
            File.open(main, "w") { |f|
                f.puts "import '#{sub}'
                    file { \"#{mainfile}\": content => #{count} }
                    "
            }
        end
        updatesub = proc do
            count += 1
            File.open(sub, "w") { |f|
                f.puts "file { \"#{subfile}\": content => #{count} }
                "
            }
        end

        updatemain.call
        updatesub.call

        interp = Puppet::Parser::Interpreter.new(
            :Manifest => main,
            :Local => true
        )

        date = interp.parsedate

        # Now update the site file and make sure we catch it
        sleep 1
        updatemain.call
        newdate = interp.parsedate
        assert(date != newdate, "Parsedate was not updated")
        date = newdate

        # And then the subfile
        sleep 1
        updatesub.call
        newdate = interp.parsedate
        assert(date != newdate, "Parsedate was not updated")
    end
    
    # Make sure class, node, and define methods are case-insensitive
    def test_structure_case_insensitivity
        interp = mkinterp
        
        result = nil
        assert_nothing_raised do
            result = interp.newclass "Yayness"
        end
        assert_equal(result, interp.findclass("", "yayNess"))
        
        assert_nothing_raised do
            result = interp.newdefine "FunTest"
        end
        assert_equal(result, interp.finddefine("", "fUntEst"),
            "%s was not matched" % "fUntEst")
        
        assert_nothing_raised do
            result = interp.newnode("MyNode").shift
        end
        assert_equal(result, interp.nodesearch("mYnOde"),
            "mYnOde was not matched")
        
        assert_nothing_raised do
            result = interp.newnode("YayTest.Domain.Com").shift
        end
        assert_equal(result, interp.nodesearch("yaYtEst.domAin.cOm"),
            "yaYtEst.domAin.cOm was not matched")
    end

    # Make sure our whole chain works.
    def test_evaluate
        interp, scope, source = mkclassframing

        # Create a define that we'll be using
        interp.newdefine("wrapper", :code => AST::ASTArray.new(:children => [
            resourcedef("file", varref("name"), "owner" => "root")
        ]))

        # Now create a resource that uses that define
        define = mkresource(:type => "wrapper", :title => "/tmp/testing",
            :scope => scope, :source => source, :params => :none)

        scope.setresource define

        # And a normal resource
        scope.setresource mkresource(:type => "file", :title => "/tmp/rahness",
            :scope => scope, :source => source,
            :params => {:owner => "root"})

        # Now evaluate everything
        objects = nil
        interp.usenodes = false
        assert_nothing_raised do
            objects = interp.evaluate(nil, {})
        end

        assert_instance_of(Puppet::TransBucket, objects)
    end

    # Test evaliterate.  It's a very simple method, but it's pretty tough
    # to test.  It iterates over collections and instances of defined types
    # until there's no more work to do.
    def test_evaliterate
        interp, scope, source = mkclassframing

        # Create a top-level definition that creates a builtin object
        interp.newdefine("one", :arguments => [%w{owner}],
            :code => AST::ASTArray.new(:children => [
                resourcedef("file", varref("name"),
                    "owner" => varref("owner")
                )
            ])
        )

        # Create another definition to call that one
        interp.newdefine("two", :arguments => [%w{owner}],
            :code => AST::ASTArray.new(:children => [
                resourcedef("one", varref("name"),
                    "owner" => varref("owner")
                )
            ])
        )

        # And then a third
        interp.newdefine("three", :arguments => [%w{owner}],
            :code => AST::ASTArray.new(:children => [
                resourcedef("two", varref("name"),
                    "owner" => varref("owner")
                )
            ])
        )

        # And create a definition that creates a virtual resource
        interp.newdefine("virtualizer", :arguments => [%w{owner}],
            :code => AST::ASTArray.new(:children => [
                virt_resourcedef("one", varref("name"),
                    "owner" => varref("owner")
                )
            ])
        )

        # Now create an instance of three
        three = Puppet::Parser::Resource.new(
            :type => "three", :title => "one",
            :scope => scope, :source => source,
            :params => paramify(source, :owner => "root")
        )
        scope.setresource(three)

        # An instance of the virtualizer
        virt = Puppet::Parser::Resource.new(
            :type => "virtualizer", :title => "two",
            :scope => scope, :source => source,
            :params => paramify(source, :owner => "root")
        )
        scope.setresource(virt)

        # And a virtual instance of three
        virt_three = Puppet::Parser::Resource.new(
            :type => "three", :title => "three",
            :scope => scope, :source => source,
            :params => paramify(source, :owner => "root")
        )
        virt_three.virtual = true
        scope.setresource(virt_three)

        # Create a normal, virtual resource
        plainvirt = Puppet::Parser::Resource.new(
            :type => "user", :title => "five",
            :scope => scope, :source => source,
            :params => paramify(source, :uid => "root")
        )
        plainvirt.virtual = true
        scope.setresource(plainvirt)

        # Now create some collections for our virtual resources
        %w{Three[three] One[two]}.each do |ref|
            coll = Puppet::Parser::Collector.new(scope, "file", nil, nil, :virtual)
            coll.resources = [ref]
            scope.newcollection(coll)
        end

        # And create a generic user collector for our plain resource
        coll = Puppet::Parser::Collector.new(scope, "user", nil, nil, :virtual)
        scope.newcollection(coll)

        ret = nil
        assert_nothing_raised do
            ret = scope.unevaluated
        end


        assert_instance_of(Array, ret)
        assert_equal(3, ret.length,
            "did not get the correct number of unevaled resources")

        # Now translate the whole tree
        assert_nothing_raised do
            Timeout::timeout(2) do
                interp.evaliterate(scope)
            end
        end

        # Now make sure we've got all of our files
        %w{one two three}.each do |name|
            file = scope.findresource("File[%s]" % name)
            assert(file, "Could not find file %s" % name)

            assert_equal("root", file[:owner])
            assert(! file.virtual?, "file %s is still virtual" % name)
        end

        # Now make sure we found the user
        assert(! plainvirt.virtual?, "user was not realized")
    end

    # Make sure we fail if there are any leftover overrides to perform.
    # This would normally mean that someone is trying to override an object
    # that does not exist.
    def test_failonleftovers
        interp, scope, source = mkclassframing

        # Make sure we don't fail, since there are no overrides
        assert_nothing_raised do
            interp.failonleftovers(scope)
        end

        # Add an override, and make sure it causes a failure
        over1 = mkresource :scope => scope, :source => source,
                :params => {:one => "yay"}

        scope.setoverride(over1)

        assert_raise(Puppet::ParseError) do
            interp.failonleftovers(scope)
        end

        # Make a new scope to test leftover collections
        scope = mkscope :interp => interp
        interp.meta_def(:check_resource_collections) do
            raise ArgumentError, "yep"
        end

        assert_raise(ArgumentError, "did not call check_resource_colls") do
            interp.failonleftovers(scope)
        end
    end

    def test_evalnode
        interp = mkinterp
        interp.usenodes = false
        scope = Parser::Scope.new(:interp => interp)
        facts = Facter.to_hash

        # First make sure we get no failures when client is nil
        assert_nothing_raised do
            interp.evalnode(nil, scope, facts)
        end

        # Now define a node
        interp.newnode "mynode", :code => AST::ASTArray.new(:children => [
            resourcedef("file", "/tmp/testing", "owner" => "root")
        ])

        # Eval again, and make sure it does nothing
        assert_nothing_raised do
            interp.evalnode("mynode", scope, facts)
        end

        assert_nil(scope.findresource("File[/tmp/testing]"),
            "Eval'ed node with nodes off")

        # Now enable usenodes and make sure it works.
        interp.usenodes = true
        assert_nothing_raised do
            interp.evalnode("mynode", scope, facts)
        end
        file = scope.findresource("File[/tmp/testing]")

        assert_instance_of(Puppet::Parser::Resource, file,
            "Could not find file")
    end

    # This is mostly used for the cfengine module
    def test_specificclasses
        interp = mkinterp :Classes => %w{klass1 klass2}, :UseNodes => false

        # Make sure it's not a failure to be missing classes, since
        # we're using the cfengine class list, which is huge.
        assert_nothing_raised do
            interp.evaluate(nil, {})
        end

        interp.newclass("klass1", :code => AST::ASTArray.new(:children => [
            resourcedef("file", "/tmp/klass1", "owner" => "root")
        ]))
        interp.newclass("klass2", :code => AST::ASTArray.new(:children => [
            resourcedef("file", "/tmp/klass2", "owner" => "root")
        ]))

        ret = nil
        assert_nothing_raised do
            ret = interp.evaluate(nil, {})
        end

        found = ret.flatten.collect do |res| res.name end

        assert(found.include?("/tmp/klass1"), "Did not evaluate klass1")
        assert(found.include?("/tmp/klass2"), "Did not evaluate klass2")
    end

    def test_check_resource_collections
        interp = mkinterp
        scope = mkscope :interp => interp
        coll = Puppet::Parser::Collector.new(scope, "file", nil, nil, :virtual)
        coll.resources = ["File[/tmp/virtual1]", "File[/tmp/virtual2]"]
        scope.newcollection(coll)

        assert_raise(Puppet::ParseError, "Did not fail on remaining resource colls") do
            interp.check_resource_collections(scope)
        end
    end

    def test_nodedef
        interp = mkinterp
        interp.newclass("base")
        interp.newclass("sub", :parent => "base")
        interp.newclass("other")

        node = nil
        assert_nothing_raised("Could not create a node definition") do
            node = NodeDef.new :name => "yay", :classes => "sub", :parameters => {"one" => "two", "three" => "four"}
        end

        scope = mkscope :interp => interp
        assert_nothing_raised("Could not evaluate the node definition") do
            node.evaluate(:scope => scope)
        end

        assert_equal("two", scope.lookupvar("one"), "NodeDef did not set variable")
        assert_equal("four", scope.lookupvar("three"), "NodeDef did not set variable")

        assert(scope.classlist.include?("sub"), "NodeDef did not evaluate class")
        assert(scope.classlist.include?("base"), "NodeDef did not evaluate base class")

        # Now try a node def with multiple classes
        assert_nothing_raised("Could not create a node definition") do
            node = NodeDef.new :name => "yay", :classes => %w{sub other base}, :parameters => {"one" => "two", "three" => "four"}
        end

        scope = mkscope :interp => interp
        assert_nothing_raised("Could not evaluate the node definition") do
            node.evaluate(:scope => scope)
        end

        assert_equal("two", scope.lookupvar("one"), "NodeDef did not set variable")
        assert_equal("four", scope.lookupvar("three"), "NodeDef did not set variable")

        assert(scope.classlist.include?("sub"), "NodeDef did not evaluate class")
        assert(scope.classlist.include?("other"), "NodeDef did not evaluate other class")

        # And a node def with no params
        assert_nothing_raised("Could not create a node definition with no params") do
            node = NodeDef.new :name => "yay", :classes => %w{sub other base}
        end

        scope = mkscope :interp => interp
        assert_nothing_raised("Could not evaluate the node definition") do
            node.evaluate(:scope => scope)
        end

        assert(scope.classlist.include?("sub"), "NodeDef did not evaluate class")
        assert(scope.classlist.include?("other"), "NodeDef did not evaluate other class")

        # Now make sure nodedef doesn't fail when some classes are not defined (#687).
        assert_nothing_raised("Could not create a node definition with some invalid classes") do
            node = NodeDef.new :name => "yay", :classes => %w{base unknown}
        end

        scope = mkscope :interp => interp
        assert_nothing_raised("Could not evaluate the node definition with some invalid classes") do
            node.evaluate(:scope => scope)
        end

        assert(scope.classlist.include?("base"), "NodeDef did not evaluate class")
    end

    # Make sure that reparsing is atomic -- failures don't cause a broken state, and we aren't subject
    # to race conditions if someone contacts us while we're reparsing.
    def test_atomic_reparsing
        Puppet[:filetimeout] = -10
        file = tempfile
        File.open(file, "w") { |f| f.puts %{file { '/tmp': ensure => directory }} }
        interp = mkinterp :Manifest => file, :UseNodes => false

        assert_nothing_raised("Could not compile the first time") do
            interp.run("yay", {})
        end

        oldparser = interp.send(:instance_variable_get, "@parser")

        # Now add a syntax failure
        File.open(file, "w") { |f| f.puts %{file { /tmp: ensure => directory }} }
        assert_nothing_raised("Could not compile the first time") do
            interp.run("yay", {})
        end

        # And make sure the old parser is still there
        newparser = interp.send(:instance_variable_get, "@parser")
        assert_equal(oldparser.object_id, newparser.object_id, "Failed parser still replaced existing parser")
    end
end

# $Id$
