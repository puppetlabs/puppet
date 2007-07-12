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

    # Make sure our node gets added to the node table.
    def test_newnode
        interp = mkinterp

        # First just try calling it directly
        assert_nothing_raised {
            interp.newnode("mynode", :code => :yay)
        }

        assert_equal(:yay, interp.nodesearch_code("mynode").code)

        # Now make sure that trying to redefine it throws an error.
        assert_raise(Puppet::ParseError) {
            interp.newnode("mynode", {})
        }

        # Now try one with no code
        assert_nothing_raised {
            interp.newnode("simplenode", :parent => :foo)
        }

        # Make sure trying to get the parentclass throws an error
        assert_raise(Puppet::ParseError) do
            interp.nodesearch_code("simplenode").parentobj
        end

        # Now define the parent node
        interp.newnode(:foo)

        # And make sure we get things back correctly
        assert_equal("foo", interp.nodesearch_code("simplenode").parentobj.classname)
        assert_nil(interp.nodesearch_code("simplenode").code)

        # Now make sure that trying to redefine it throws an error.
        assert_raise(Puppet::ParseError) {
            interp.newnode("mynode", {})
        }

        # Test multiple names
        names = ["one", "two", "three"]
        assert_nothing_raised {
            interp.newnode(names, {:code => :yay, :parent => :foo})
        }

        names.each do |name|
            assert_equal(:yay, interp.nodesearch_code(name).code)
            assert_equal("foo", interp.nodesearch_code(name).parentobj.name)
            # Now make sure that trying to redefine it throws an error.
            assert_raise(Puppet::ParseError) {
                interp.newnode(name, {})
            }
        end
    end

    def test_fqfind
        interp = mkinterp

        table = {}
        # Define a bunch of things.
        %w{a c a::b a::b::c a::c a::b::c::d a::b::c::d::e::f c::d}.each do |string|
            table[string] = string
        end

        check = proc do |namespace, hash|
            hash.each do |thing, result|
                assert_equal(result, interp.fqfind(namespace, thing, table),
                            "Could not find %s in %s" % [thing, namespace])
            end
        end

        # Now let's do some test lookups.

        # First do something really simple
        check.call "a", "b" => "a::b", "b::c" => "a::b::c", "d" => nil, "::c" => "c"

        check.call "a::b", "c" => "a::b::c", "b" => "a::b", "a" => "a"

        check.call "a::b::c::d::e", "c" => "a::b::c", "::c" => "c",
            "c::d" => "a::b::c::d", "::c::d" => "c::d"

        check.call "", "a" => "a", "a::c" => "a::c"
    end

    def test_newdefine
        interp = mkinterp

        assert_nothing_raised {
            interp.newdefine("mydefine", :code => :yay,
                :arguments => ["a", stringobj("b")])
        }

        mydefine = interp.finddefine("", "mydefine")
        assert(mydefine, "Could not find definition")
        assert_equal("mydefine", interp.finddefine("", "mydefine").classname)
        assert_equal("", mydefine.namespace)
        assert_equal("mydefine", mydefine.classname)

        assert_raise(Puppet::ParseError) do
            interp.newdefine("mydefine", :code => :yay,
                :arguments => ["a", stringobj("b")])
        end

        # Now define the same thing in a different scope
        assert_nothing_raised {
            interp.newdefine("other::mydefine", :code => :other,
                :arguments => ["a", stringobj("b")])
        }
        other = interp.finddefine("other", "mydefine")
        assert(other, "Could not find definition")
        assert(interp.finddefine("", "other::mydefine"),
            "Could not find other::mydefine")
        assert_equal(:other, other.code)
        assert_equal("other", other.namespace)
        assert_equal("other::mydefine", other.classname)
    end

    def test_newclass
        interp = mkinterp

        mkcode = proc do |ary|
            classes = ary.collect do |string|
                AST::FlatString.new(:value => string)
            end
            AST::ASTArray.new(:children => classes)
        end
        scope = Puppet::Parser::Scope.new(:interp => interp)

        # First make sure that code is being appended
        code = mkcode.call(%w{original code})

        klass = nil
        assert_nothing_raised {
            klass = interp.newclass("myclass", :code => code)
        }

        assert(klass, "Did not return class")

        assert(interp.findclass("", "myclass"), "Could not find definition")
        assert_equal("myclass", interp.findclass("", "myclass").classname)
        assert_equal(%w{original code},
             interp.findclass("", "myclass").code.evaluate(:scope => scope))

        # Now create the same class name in a different scope
        assert_nothing_raised {
            klass = interp.newclass("other::myclass",
                            :code => mkcode.call(%w{something diff}))
        }
        assert(klass, "Did not return class")
        other = interp.findclass("other", "myclass")
        assert(other, "Could not find class")
        assert(interp.findclass("", "other::myclass"), "Could not find class")
        assert_equal("other::myclass", other.classname)
        assert_equal("other::myclass", other.namespace)
        assert_equal(%w{something diff},
             interp.findclass("other", "myclass").code.evaluate(:scope => scope))

        # Newclass behaves differently than the others -- it just appends
        # the code to the existing class.
        code = mkcode.call(%w{something new})
        assert_nothing_raised do
            klass = interp.newclass("myclass", :code => code)
        end
        assert(klass, "Did not return class when appending")
        assert_equal(%w{original code something new},
            interp.findclass("", "myclass").code.evaluate(:scope => scope))

        # Make sure newclass deals correctly with nodes with no code
        klass = interp.newclass("nocode")
        assert(klass, "Did not return class")

        assert_nothing_raised do
            klass = interp.newclass("nocode", :code => mkcode.call(%w{yay test}))
        end
        assert(klass, "Did not return class with no code")
        assert_equal(%w{yay test},
            interp.findclass("", "nocode").code.evaluate(:scope => scope))

        # Then try merging something into nothing
        interp.newclass("nocode2", :code => mkcode.call(%w{foo test}))
        assert(klass, "Did not return class with no code")

        assert_nothing_raised do
            klass = interp.newclass("nocode2")
        end
        assert(klass, "Did not return class with no code")
        assert_equal(%w{foo test},
            interp.findclass("", "nocode2").code.evaluate(:scope => scope))

        # And lastly, nothing and nothing
        klass = interp.newclass("nocode3")
        assert(klass, "Did not return class with no code")

        assert_nothing_raised do
            klass = interp.newclass("nocode3")
        end
        assert(klass, "Did not return class with no code")
        assert_nil(interp.findclass("", "nocode3").code)
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
    
    # Now make sure we get appropriate behaviour with parent class conflicts.
    def test_newclass_parentage
        interp = mkinterp
        interp.newclass("base1")
        interp.newclass("one::two::three")

        # First create it with no parentclass.
        assert_nothing_raised {
            interp.newclass("sub")
        }
        assert(interp.findclass("", "sub"), "Could not find definition")
        assert_nil(interp.findclass("", "sub").parentclass)

        # Make sure we can't set the parent class to ourself.
        assert_raise(Puppet::ParseError) {
            interp.newclass("sub", :parent => "sub")
        }

        # Now create another one, with a parentclass.
        assert_nothing_raised {
            interp.newclass("sub", :parent => "base1")
        }

        # Make sure we get the right parent class, and make sure it's not an object.
        assert_equal("base1",
                    interp.findclass("", "sub").parentclass)
        assert_equal(interp.findclass("", "base1"),
                    interp.findclass("", "sub").parentobj)

        # Now make sure we get a failure if we try to conflict.
        assert_raise(Puppet::ParseError) {
            interp.newclass("sub", :parent => "one::two::three")
        }

        # Make sure that failure didn't screw us up in any way.
        assert_equal(interp.findclass("", "base1"),
                    interp.findclass("", "sub").parentobj)
        # But make sure we can create a class with a fq parent
        assert_nothing_raised {
            interp.newclass("another", :parent => "one::two::three")
        }
        assert_equal(interp.findclass("", "one::two::three"),
                    interp.findclass("", "another").parentobj)

    end

    def test_namesplit
        interp = mkinterp

        assert_nothing_raised do
            {"base::sub" => %w{base sub},
                "main" => ["", "main"],
                "one::two::three::four" => ["one::two::three", "four"],
            }.each do |name, ary|
                result = interp.namesplit(name)
                assert_equal(ary, result, "%s split to %s" % [name, result])
            end
        end
    end

    # Make sure you can't have classes and defines with the same name in the
    # same scope.
    def test_classes_beat_defines
        interp = mkinterp

        assert_nothing_raised {
            interp.newclass("yay::funtest")
        }

        assert_raise(Puppet::ParseError) do
            interp.newdefine("yay::funtest")
        end

        assert_nothing_raised {
            interp.newdefine("yay::yaytest")
        }

        assert_raise(Puppet::ParseError) do
            interp.newclass("yay::yaytest")
        end
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
    
    def mk_node_mapper
        # First, make sure our nodesearch command works as we expect
        # Make a nodemapper
        mapper = tempfile()
        ruby = %x{which ruby}.chomp
        File.open(mapper, "w") { |f|
            f.puts "#!#{ruby}
            require 'yaml'
            name = ARGV[0].chomp
            result = {}

            if name =~ /a/
                result[:parameters] = {'one' => ARGV[0] + '1', 'two' => ARGV[0] + '2'}
            end

            if name =~ /p/
                result['classes'] = [1,2,3].collect { |n| ARGV[0] + n.to_s }
            end

            puts YAML.dump(result)
            "
        }    
        File.chmod(0755, mapper)
        mapper
    end
    
    def test_nodesearch_external
        interp = mkinterp
        
        mapper = mk_node_mapper
        # Make sure it gives the right response
        assert_equal({'classes' => %w{apple1 apple2 apple3}, :parameters => {"one" => "apple1", "two" => "apple2"}},
            YAML.load(%x{#{mapper} apple}))
        
        # First make sure we get nil back by default
        assert_nothing_raised {
            assert_nil(interp.nodesearch_external("apple"),
                "Interp#nodesearch_external defaulted to a non-nil response")
        }
        assert_nothing_raised { Puppet[:external_nodes] = mapper }
        
        node = nil
        # Both 'a' and 'p', so we get classes and parameters
        assert_nothing_raised { node = interp.nodesearch_external("apple") }
        assert_equal("apple", node.name, "node name was not set correctly for apple")
        assert_equal(%w{apple1 apple2 apple3}, node.classes, "node classes were not set correctly for apple")
        assert_equal( {"one" => "apple1", "two" => "apple2"}, node.parameters, "node parameters were not set correctly for apple")
        
        # A 'p' but no 'a', so we only get classes
        assert_nothing_raised { node = interp.nodesearch_external("plum") }
        assert_equal("plum", node.name, "node name was not set correctly for plum")
        assert_equal(%w{plum1 plum2 plum3}, node.classes, "node classes were not set correctly for plum")
        assert_equal({}, node.parameters, "node parameters were not set correctly for plum")
        
        # An 'a' but no 'p', so we only get parameters.
        assert_nothing_raised { node = interp.nodesearch_external("guava")} # no p's, thus no classes
        assert_equal("guava", node.name, "node name was not set correctly for guava")
        assert_equal([], node.classes, "node classes were not set correctly for guava")
        assert_equal({"one" => "guava1", "two" => "guava2"}, node.parameters, "node parameters were not set correctly for guava")
        
        assert_nothing_raised { node = interp.nodesearch_external("honeydew")} # neither, thus nil
        assert_nil(node)
    end
    
    # A wrapper test, to make sure we're correctly calling the external search method.
    def test_nodesearch_external_functional
        mapper = mk_node_mapper
        
        Puppet[:external_nodes] = mapper
        interp = mkinterp
        
        node = nil
        assert_nothing_raised do
            node = interp.nodesearch("apple")
        end
        assert_instance_of(NodeDef, node, "did not create node")
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

    # This can stay in the main test suite because it doesn't actually use ldapsearch,
    # it just overrides the method so it behaves as though it were hitting ldap.
    def test_ldapnodes
        interp = mkinterp

        nodetable = {}

        # Override the ldapsearch definition, so we don't have to actually set it up.
        interp.meta_def(:ldapsearch) do |name|
            nodetable[name]
        end

        # Make sure we get nothing for nonexistent hosts
        node = nil
        assert_nothing_raised do
            node = interp.nodesearch_ldap("nosuchhost")
        end

        assert_nil(node, "Got a node for a non-existent host")

        # Now add a base node with some classes and parameters
        nodetable["base"] = [nil, %w{one two}, {"base" => "true"}]

        assert_nothing_raised do
            node = interp.nodesearch_ldap("base")
        end

        assert_instance_of(NodeDef, node, "Did not get node from ldap nodesearch")
        assert_equal("base", node.name, "node name was not set")

        assert_equal(%w{one two}, node.classes, "node classes were not set")
        assert_equal({"base" => "true"}, node.parameters, "node parameters were not set")

        # Now use a different with this as the base
        nodetable["middle"] = ["base", %w{three}, {"center" => "boo"}]
        assert_nothing_raised do
            node = interp.nodesearch_ldap("middle")
        end

        assert_instance_of(NodeDef, node, "Did not get node from ldap nodesearch")
        assert_equal("middle", node.name, "node name was not set")

        assert_equal(%w{one two three}.sort, node.classes.sort, "node classes were not set correctly with a parent node")
        assert_equal({"base" => "true", "center" => "boo"}, node.parameters, "node parameters were not set correctly with a parent node")

        # And one further, to make sure we fully recurse
        nodetable["top"] = ["middle", %w{four five}, {"master" => "far"}]
        assert_nothing_raised do
            node = interp.nodesearch_ldap("top")
        end

        assert_instance_of(NodeDef, node, "Did not get node from ldap nodesearch")
        assert_equal("top", node.name, "node name was not set")

        assert_equal(%w{one two three four five}.sort, node.classes.sort, "node classes were not set correctly with the top node")
        assert_equal({"base" => "true", "center" => "boo", "master" => "far"}, node.parameters, "node parameters were not set correctly with the top node")
    end

    # Setup a module.
    def mk_module(name, files = {})
        mdir = File.join(@dir, name)
        mandir = File.join(mdir, "manifests")
        FileUtils.mkdir_p mandir

        if defs = files[:define]
            files.delete(:define)
        end
        Dir.chdir(mandir) do
            files.each do |file, classes|
                File.open("%s.pp" % file, "w") do |f|
                    classes.each { |klass|
                        if defs
                            f.puts "define %s {}" % klass
                        else
                            f.puts "class %s {}" % klass
                        end
                    }
                end
            end
        end
    end

    # #596 - make sure classes and definitions load automatically if they're in modules, so we don't have to manually load each one.
    def test_module_autoloading
        @dir = tempfile
        Puppet[:modulepath] = @dir

        FileUtils.mkdir_p @dir

        interp = mkinterp

        # Make sure we fail like normal for actually missing classes
        assert_nil(interp.findclass("", "nosuchclass"), "Did not return nil on missing classes")

        # test the simple case -- the module class itself
        name = "simple"
        mk_module(name, :init => [name])

        # Try to load the module automatically now
        klass = interp.findclass("", name)
        assert_instance_of(AST::HostClass, klass, "Did not autoload class from module init file")
        assert_equal(name, klass.classname, "Incorrect class was returned")

        # Try loading the simple module when we're in something other than the base namespace.
        interp = mkinterp
        klass = interp.findclass("something::else", name)
        assert_instance_of(AST::HostClass, klass, "Did not autoload class from module init file")
        assert_equal(name, klass.classname, "Incorrect class was returned")

        # Now try it with a definition as the base file
        name = "simpdef"
        mk_module(name, :define => true, :init => [name])

        klass = interp.finddefine("", name)
        assert_instance_of(AST::Component, klass, "Did not autoload class from module init file")
        assert_equal(name, klass.classname, "Incorrect class was returned")

        # Now try it with namespace classes where both classes are in the init file
        interp = mkinterp
        modname = "both"
        name = "sub"
        mk_module(modname, :init => %w{both both::sub})

        # First try it with a namespace
        klass = interp.findclass("both", name)
        assert_instance_of(AST::HostClass, klass, "Did not autoload sub class from module init file with a namespace")
        assert_equal("both::sub", klass.classname, "Incorrect class was returned")

        # Now try it using the fully qualified name
        interp = mkinterp
        klass = interp.findclass("", "both::sub")
        assert_instance_of(AST::HostClass, klass, "Did not autoload sub class from module init file with no namespace")
        assert_equal("both::sub", klass.classname, "Incorrect class was returned")


        # Now try it with the class in a different file
        interp = mkinterp
        modname = "separate"
        name = "sub"
        mk_module(modname, :init => %w{separate}, :sub => %w{separate::sub})

        # First try it with a namespace
        klass = interp.findclass("separate", name)
        assert_instance_of(AST::HostClass, klass, "Did not autoload sub class from separate file with a namespace")
        assert_equal("separate::sub", klass.classname, "Incorrect class was returned")

        # Now try it using the fully qualified name
        interp = mkinterp
        klass = interp.findclass("", "separate::sub")
        assert_instance_of(AST::HostClass, klass, "Did not autoload sub class from separate file with no namespace")
        assert_equal("separate::sub", klass.classname, "Incorrect class was returned")

        # Now make sure we don't get a failure when there's no module file
        interp = mkinterp
        modname = "alone"
        name = "sub"
        mk_module(modname, :sub => %w{alone::sub})

        # First try it with a namespace
        assert_nothing_raised("Could not autoload file when module file is missing") do
            klass = interp.findclass("alone", name)
        end
        assert_instance_of(AST::HostClass, klass, "Did not autoload sub class from alone file with a namespace")
        assert_equal("alone::sub", klass.classname, "Incorrect class was returned")

        # Now try it using the fully qualified name
        interp = mkinterp
        klass = interp.findclass("", "alone::sub")
        assert_instance_of(AST::HostClass, klass, "Did not autoload sub class from alone file with no namespace")
        assert_equal("alone::sub", klass.classname, "Incorrect class was returned")
    end
end

class LdapNodeTest < PuppetTest::TestCase
	include PuppetTest
    include PuppetTest::ServerTest
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
    AST = Puppet::Parser::AST
    NodeDef = Puppet::Parser::Interpreter::NodeDef
    confine "LDAP is not available" => Puppet.features.ldap?
    confine "No LDAP test data for networks other than Luke's" => Facter.value(:domain) == "madstop.com"
    def ldapconnect

        @ldap = LDAP::Conn.new("ldap", 389)
        @ldap.set_option( LDAP::LDAP_OPT_PROTOCOL_VERSION, 3 )
        @ldap.simple_bind("", "")

        return @ldap
    end

    def ldaphost(name)
        node = NodeDef.new(:name => name)
        parent = nil
        found = false
        @ldap.search( "ou=hosts, dc=madstop, dc=com", 2,
            "(&(objectclass=puppetclient)(cn=%s))" % name
        ) do |entry|
            node.classes = entry.vals("puppetclass") || []
            node.parameters = entry.to_hash.inject({}) do |hash, ary|
                if ary[1].length == 1
                    hash[ary[0]] = ary[1].shift
                else
                    hash[ary[0]] = ary[1]
                end
                hash
            end
            parent = node.parameters["parentnode"]
            found = true
        end
        raise "Could not find node %s" % name unless found

        return node, parent
    end

    def test_ldapsearch
        Puppet[:ldapbase] = "ou=hosts, dc=madstop, dc=com"
        Puppet[:ldapnodes] = true

        ldapconnect()

        interp = mkinterp :NodeSources => [:ldap, :code]

        # Make sure we get nil and nil back when we search for something missing
        parent, classes, parameters = nil
        assert_nothing_raised do
            parent, classes, parameters = interp.ldapsearch("nosuchhost")
        end

        assert_nil(parent, "Got a parent for a non-existent host")
        assert_nil(classes, "Got classes for a non-existent host")

        # Make sure we can find 'culain' in ldap
        assert_nothing_raised do
            parent, classes, parameters = interp.ldapsearch("culain")
        end

        node, realparent = ldaphost("culain")
        assert_equal(realparent, parent, "did not get correct parent node from ldap")
        assert_equal(node.classes, classes, "did not get correct ldap classes from ldap")
        assert_equal(node.parameters, parameters, "did not get correct ldap parameters from ldap")

        # Now compare when we specify the attributes to get.
        Puppet[:ldapattrs] = "cn"
        assert_nothing_raised do
            parent, classes, parameters = interp.ldapsearch("culain")
        end
        assert_equal(realparent, parent, "did not get correct parent node from ldap")
        assert_equal(node.classes, classes, "did not get correct ldap classes from ldap")

        list = %w{cn puppetclass parentnode dn}
        should = node.parameters.inject({}) { |h, a| h[a[0]] = a[1] if list.include?(a[0]); h }
        assert_equal(should, parameters, "did not get correct ldap parameters from ldap")
    end
end

class LdapReconnectTests < PuppetTest::TestCase
	include PuppetTest
    include PuppetTest::ServerTest
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
    AST = Puppet::Parser::AST
    NodeDef = Puppet::Parser::Interpreter::NodeDef
    confine "Not running on culain as root" => (Puppet::Util::SUIDManager.uid == 0 and Facter.value("hostname") == "culain")

    def test_ldapreconnect
        Puppet[:ldapbase] = "ou=hosts, dc=madstop, dc=com"
        Puppet[:ldapnodes] = true

        interp = nil
        assert_nothing_raised {
            interp = Puppet::Parser::Interpreter.new(
                :Manifest => mktestmanifest()
            )
        }
        hostname = "culain.madstop.com"

        # look for our host
        assert_nothing_raised {
            parent, classes = interp.nodesearch_ldap(hostname)
        }

        # Now restart ldap
        system("/etc/init.d/slapd restart 2>/dev/null >/dev/null")
        sleep(1)

        # and look again
        assert_nothing_raised {
            parent, classes = interp.nodesearch_ldap(hostname)
        }

        # Now stop ldap
        system("/etc/init.d/slapd stop 2>/dev/null >/dev/null")
        cleanup do
            system("/etc/init.d/slapd start 2>/dev/null >/dev/null")
        end

        # And make sure we actually fail here
        assert_raise(Puppet::Error) {
            parent, classes = interp.nodesearch_ldap(hostname)
        }
    end
end

# $Id$
