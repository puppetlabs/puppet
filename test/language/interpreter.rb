#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'facter'

require 'puppet'
require 'puppet/parser/interpreter'
require 'puppet/parser/parser'
require 'puppet/client'
require 'puppet/rails'
require 'puppettest'
require 'puppettest/resourcetesting'
require 'puppettest/parsertesting'
require 'puppettest/servertest'
require 'puppettest/railstesting'
require 'timeout'

class TestInterpreter < Test::Unit::TestCase
	include PuppetTest
    include PuppetTest::ServerTest
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
    include PuppetTest::RailsTesting
    AST = Puppet::Parser::AST

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

    if Puppet.features.rails?
    def test_hoststorage
        assert_nothing_raised {
            Puppet[:storeconfigs] = true
        }

        file = tempfile()
        File.open(file, "w") { |f|
            f.puts "file { \"/etc\": owner => root }"
        }

        interp = nil
        assert_nothing_raised {
            interp = Puppet::Parser::Interpreter.new(
                :Manifest => file,
                :UseNodes => false,
                :ForkSave => false
            )
        }

        facts = {}
        Facter.each { |fact, val| facts[fact] = val }

        objects = nil
        assert_nothing_raised {
            objects = interp.run(facts["hostname"], facts)
        }

        obj = Puppet::Rails::Host.find_by_name(facts["hostname"])
        assert(obj, "Could not find host object")
    end
    else
        $stderr.puts "No ActiveRecord -- skipping collection tests"
    end

    if Facter["domain"].value == "madstop.com"

    # Only test ldap stuff on luke's network, since that's the only place we
    # have data for.
    if Puppet.features.ldap?
    def ldapconnect

        @ldap = LDAP::Conn.new("ldap", 389)
        @ldap.set_option( LDAP::LDAP_OPT_PROTOCOL_VERSION, 3 )
        @ldap.simple_bind("", "")

        return @ldap
    end

    def ldaphost(node)
        parent = nil
        classes = nil
        @ldap.search( "ou=hosts, dc=madstop, dc=com", 2,
            "(&(objectclass=puppetclient)(cn=%s))" % node
        ) do |entry|
            parent = entry.vals("parentnode").shift
            classes = entry.vals("puppetclass") || []
        end

        return parent, classes
    end

    def test_ldapsearch
        Puppet[:ldapbase] = "ou=hosts, dc=madstop, dc=com"
        Puppet[:ldapnodes] = true

        ldapconnect()

        interp = mkinterp :NodeSources => [:ldap, :code]

        # Make sure we get nil and nil back when we search for something missing
        parent, classes = nil
        assert_nothing_raised do
            parent, classes = interp.ldapsearch("nosuchhost")
        end

        assert_nil(parent, "Got a parent for a non-existent host")
        assert_nil(classes, "Got classes for a non-existent host")

        # Make sure we can find 'culain' in ldap
        assert_nothing_raised do
            parent, classes = interp.ldapsearch("culain")
        end

        realparent, realclasses = ldaphost("culain")
        assert_equal(realparent, parent)
        assert_equal(realclasses, classes)
    end

    def test_ldapnodes
        Puppet[:ldapbase] = "ou=hosts, dc=madstop, dc=com"
        Puppet[:ldapnodes] = true

        ldapconnect()

        interp = mkinterp :NodeSources => [:ldap, :code]

        # culain uses basenode, so create that
        basenode = interp.newnode([:basenode])[0]

        # Make sure we get nothing for nonexistent hosts
        none = nil
        assert_nothing_raised do
            none = interp.nodesearch_ldap("nosuchhost")
        end

        assert_nil(none, "Got a node for a non-existent host")

        # Make sure we can find 'culain' in ldap
        culain = nil
        assert_nothing_raised do
            culain = interp.nodesearch_ldap("culain")
        end

        assert(culain, "Did not find culain in ldap")

        assert_nothing_raised do
            assert_equal(basenode.fqname.to_s, culain.parentclass.fqname.to_s,
                "Did not get parent class")
        end
    end

    if Puppet::Util::SUIDManager.uid == 0 and Facter["hostname"].value == "culain"
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
    else
        $stderr.puts "Run as root for ldap reconnect tests"
    end
    end
    else
        $stderr.puts "Not in madstop.com; skipping ldap tests"
    end

    # Test that node info and default node info in different sources isn't
    # bad.
    def test_multiple_nodesources

        # Create another node source
        Puppet::Parser::Interpreter.send(:define_method, :nodesearch_multi) do |*names|
            if names[0] == "default"
                gennode("default", {:facts => {}})
            else
                nil
            end
        end

        interp = mkinterp :NodeSources => [:multi, :code]

        interp.newnode(["node"])

        obj = nil
        assert_nothing_raised do
            obj = interp.nodesearch("node")
        end
        assert(obj, "Did not find node")
        assert_equal("node", obj.fqname)
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
            assert_equal("default", default.fqname)
        end

        # Now make sure the longest match always wins
        node = interp.nodesearch(*%w{node2 node2.domain.com})

        assert(node, "Did not find node2")
        assert_equal("node2.domain.com", node.fqname,
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
            interp.nodesearch_code("simplenode").parentclass
        end

        # Now define the parent node
        interp.newnode(:foo)

        # And make sure we get things back correctly
        assert_equal("foo", interp.nodesearch_code("simplenode").parentclass.fqname)
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
            assert_equal("foo", interp.nodesearch_code(name).parentclass.name)
            # Now make sure that trying to redefine it throws an error.
            assert_raise(Puppet::ParseError) {
                interp.newnode(name, {})
            }
        end
    end

    # Make sure we're correctly generating a node definition.
    def test_gennode
        interp = mkinterp

        interp.newnode "base"
        interp.newclass "yaytest"

        # Go through the different iterations:
        [
         [nil, "yaytest"],
         [nil, ["yaytest"]],
         [nil, nil],
         [nil, []],
         ["base", nil],
         ["base", []],
         ["base", "yaytest"],
         ["base", ["yaytest"]]
        ].each do |parent, classes|
            node = nil
            assert_nothing_raised {
                node = interp.gennode("nodeA", :classes => classes,
                    :parentnode => parent)
            }

            assert_instance_of(Puppet::Parser::AST::Node, node)

            assert_equal("nodeA", node.name)

            scope = mkscope :interp => interp

            assert_nothing_raised do
                node.evaluate :scope => scope
            end

            # If there's a parent, make sure it got evaluated
            if parent
                assert(scope.classlist.include?("base"),
                    "Did not evaluate parent node")
            end

            # If there are classes make sure they got evaluated
            if classes == ["yaytest"] or classes == "yaytest"
                assert(scope.classlist.include?("yaytest"),
                    "Did not evaluate class")
            end
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
        assert_equal("mydefine", interp.finddefine("", "mydefine").type)
        assert_equal("", mydefine.namespace)
        assert_equal("mydefine", mydefine.type)

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
        assert_equal("mydefine", other.type)
        assert_equal("other::mydefine", other.fqname)
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
        assert_equal("myclass", interp.findclass("", "myclass").type)
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
        assert_equal("other::myclass", other.fqname)
        assert_equal("other::myclass", other.namespace)
        assert_equal("myclass", other.type)
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

        # Make sure we get the right parent class, and make sure it's an object.
        assert_equal(interp.findclass("", "base1"),
                    interp.findclass("", "sub").parentclass)

        # Now make sure we get a failure if we try to conflict.
        assert_raise(Puppet::ParseError) {
            interp.newclass("sub", :parent => "one::two::three")
        }

        # Make sure that failure didn't screw us up in any way.
        assert_equal(interp.findclass("", "base1"),
                    interp.findclass("", "sub").parentclass)
        # But make sure we can create a class with a fq parent
        assert_nothing_raised {
            interp.newclass("another", :parent => "one::two::three")
        }
        assert_equal(interp.findclass("", "one::two::three"),
                    interp.findclass("", "another").parentclass)

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

        three = Puppet::Parser::Resource.new(
            :type => "three", :title => "/tmp/yayness",
            :scope => scope, :source => source,
            :params => paramify(source, :owner => "root")
        )

        scope.setresource(three)

        ret = nil
        assert_nothing_raised do
            ret = scope.unevaluated
        end


        assert_instance_of(Array, ret)
        assert(1, ret.length)
        assert_equal([three], ret)

        assert(ret.detect { |r| r.ref == "Three[/tmp/yayness]"},
            "Did not get three back as unevaluated")

        # Now translate the whole tree
        assert_nothing_raised do
            interp.evaliterate(scope)
        end

        # Now make sure we've got our file
        file = scope.findresource "File[/tmp/yayness]"
        assert(file, "Could not find file")

        assert_equal("root", file[:owner])
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

    if Puppet.features.rails?
    # We need to make sure finished objects are stored in the db.
    def test_finish_before_store
        railsinit
        interp = mkinterp

        node = interp.newnode ["myhost"], :code => AST::ASTArray.new(:children => [
            resourcedef("file", "/tmp/yay", :group => "root"),
            defaultobj("file", :owner => "root")
        ])

        interp.newclass "myclass", :code => AST::ASTArray.new(:children => [
        ])

        interp.newclass "sub", :parent => "myclass",
            :code => AST::ASTArray.new(:children => [
                resourceoverride("file", "/tmp/yay", :owner => "root")
            ]
        )

        # Now do the rails crap
        Puppet[:storeconfigs] = true

        interp.evaluate("myhost", {})

        # And then retrieve the object from rails
        res = Puppet::Rails::Resource.find_by_restype_and_title("file", "/tmp/yay")

        assert(res, "Did not get resource from rails")

        param = res.param_names.find_by_name("owner", :include => :param_values)

        assert(param, "Did not find owner param")

        pvalue = param.param_values.find_by_value("root")
        assert_equal("root", pvalue[:value])
    end
    end
    
    def mk_node_mapper
        # First, make sure our nodesearch command works as we expect
        # Make a nodemapper
        mapper = tempfile()
        ruby = %x{which ruby}.chomp
        File.open(mapper, "w") { |f|
            f.puts "#!#{ruby}
            name = ARGV[0]
            if name =~ /a/
                puts ARGV[0].gsub('a', 'b')
            else
                puts ''
            end
            if name =~ /p/
                puts [1,2,3].collect { |n| ARGV[0] + n.to_s }.join(' ')
            else
                puts ''
            end
            "
        }    
        File.chmod(0755, mapper)
        mapper
    end
    
    def test_nodesearch_external
        interp = mkinterp
        
        # Make a fake gennode method
        class << interp
            def gennode(name, args)
                args[:name] = name
                return args
            end
        end
        
        mapper = mk_node_mapper
        # Make sure it gives the right response
        assert_equal("bpple\napple1 apple2 apple3\n",
            %x{#{mapper} apple})
        
        # First make sure we get nil back by default
        assert_nothing_raised {
            assert_nil(interp.nodesearch_external("apple"),
                "Interp#nodesearch_external defaulted to a non-nil response")
        }
        assert_nothing_raised { Puppet[:external_nodes] = mapper }
        
        node = nil
        assert_nothing_raised { node = interp.nodesearch_external("apple") }
        
        assert_equal({:name => "apple", :classes => %w{apple1 apple2 apple3}, :parentnode => "bpple"},
            node)
        
        assert_nothing_raised { node = interp.nodesearch_external("plum")} # no a's, thus no parent
        assert_equal({:name => "plum", :classes => %w{plum1 plum2 plum3}},
            node)
        
        assert_nothing_raised { node = interp.nodesearch_external("guava")} # no p's, thus no classes
        assert_equal({:name => "guava", :parentnode => "gubvb"},
            node)
        
        assert_nothing_raised { node = interp.nodesearch_external("honeydew")} # neither, thus nil
        assert_nil(node)
    end
    
    def test_nodesearch_external_functional
        mapper = mk_node_mapper
        
        Puppet[:external_nodes] = mapper
        interp = mkinterp
        
        node = nil
        assert_nothing_raised do
            node = interp.nodesearch("apple")
        end
        assert_instance_of(Puppet::Parser::AST::Node, node, "did not create node")
    end
end

# $Id$
