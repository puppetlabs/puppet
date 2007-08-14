#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'mocha'
require 'puppettest'
require 'puppettest/resourcetesting'
require 'puppettest/parsertesting'
require 'puppettest/servertest'
require 'puppet/network/handler/node'

module NodeTesting
    include PuppetTest
    Node = Puppet::Network::Handler::Node
    SimpleNode = Puppet::Network::Handler::Node::SimpleNode
    
    def mk_node_mapper
        # First, make sure our nodesearch command works as we expect
        # Make a nodemapper
        mapper = tempfile()
        ruby = %x{which ruby}.chomp
        File.open(mapper, "w") { |f|
            f.puts "#!#{ruby}
            require 'yaml'
            name = ARGV.last.chomp
            result = {}

            if name =~ /a/
                result[:parameters] = {'one' => ARGV.last + '1', 'two' => ARGV.last + '2'}
            end

            if name =~ /p/
                result['classes'] = [1,2,3].collect { |n| ARGV.last + n.to_s }
            end

            puts YAML.dump(result)
            "
        }    
        File.chmod(0755, mapper)
        mapper
    end

    def mk_searcher(name)
        searcher = Object.new
        searcher.extend(Node.node_source(name))
    end
end

class TestNodeInterface < Test::Unit::TestCase
    def setup
        super
    end

    def teardown
    end

    def test_node
        raise "Failing, yo"
    end

    def test_environment
        raise "still failing"
    end

    def test_parameters
        raise "still failing"
    end

    def test_classes
        raise "still failing"
    end
end

# Test our configuration object.
class TestNodeSources < Test::Unit::TestCase
    include NodeTesting

    def test_node_sources
        mod = nil
        assert_nothing_raised("Could not add new search type") do
            mod = Node.newnode_source(:testing) do
                def nodesearch(name)
                end
            end
        end
        assert_equal(mod, Node.node_source(:testing), "Did not get node_source back")

        cleanup do
            Node.rm_node_source(:testing)
        end
    end
    
    def test_external_node_source
        mapper = mk_node_mapper
        searcher = mk_searcher(:external)

        # Make sure it gives the right response
        assert_equal({'classes' => %w{apple1 apple2 apple3}, :parameters => {"one" => "apple1", "two" => "apple2"}},
            YAML.load(%x{#{mapper} apple}))
        
        # First make sure we get nil back by default
        assert_nothing_raised {
            assert_nil(searcher.nodesearch("apple"),
                "Interp#nodesearch_external defaulted to a non-nil response")
        }
        assert_nothing_raised { Puppet[:external_nodes] = mapper }
        
        node = nil
        # Both 'a' and 'p', so we get classes and parameters
        assert_nothing_raised { node = searcher.nodesearch("apple") }
        assert_equal("apple", node.name, "node name was not set correctly for apple")
        assert_equal(%w{apple1 apple2 apple3}, node.classes, "node classes were not set correctly for apple")
        assert_equal( {"one" => "apple1", "two" => "apple2"}, node.parameters, "node parameters were not set correctly for apple")
        
        # A 'p' but no 'a', so we only get classes
        assert_nothing_raised { node = searcher.nodesearch("plum") }
        assert_equal("plum", node.name, "node name was not set correctly for plum")
        assert_equal(%w{plum1 plum2 plum3}, node.classes, "node classes were not set correctly for plum")
        assert_equal({}, node.parameters, "node parameters were not set correctly for plum")
        
        # An 'a' but no 'p', so we only get parameters.
        assert_nothing_raised { node = searcher.nodesearch("guava")} # no p's, thus no classes
        assert_equal("guava", node.name, "node name was not set correctly for guava")
        assert_equal([], node.classes, "node classes were not set correctly for guava")
        assert_equal({"one" => "guava1", "two" => "guava2"}, node.parameters, "node parameters were not set correctly for guava")
        
        assert_nothing_raised { node = searcher.nodesearch("honeydew")} # neither, thus nil
        assert_nil(node)
    end
    
    # Make sure a nodesearch with arguments works
    def test_nodesearch_external_arguments
        mapper = mk_node_mapper
        Puppet[:external_nodes] = "#{mapper} -s something -p somethingelse"
        searcher = mk_searcher(:external)
        node = nil
        assert_nothing_raised do
            node = searcher.nodesearch("apple")
        end
        assert_instance_of(SimpleNode, node, "did not create node")
    end
    
    # A wrapper test, to make sure we're correctly calling the external search method.
    def test_nodesearch_external_functional
        mapper = mk_node_mapper
        searcher = mk_searcher(:external)
        
        Puppet[:external_nodes] = mapper
        
        node = nil
        assert_nothing_raised do
            node = searcher.nodesearch("apple")
        end
        assert_instance_of(SimpleNode, node, "did not create node")
    end

    # This can stay in the main test suite because it doesn't actually use ldapsearch,
    # it just overrides the method so it behaves as though it were hitting ldap.
    def test_ldap_nodesearch
        searcher = mk_searcher(:ldap)

        nodetable = {}

        # Override the ldapsearch definition, so we don't have to actually set it up.
        searcher.meta_def(:ldapsearch) do |name|
            nodetable[name]
        end

        # Make sure we get nothing for nonexistent hosts
        node = nil
        assert_nothing_raised do
            node = searcher.nodesearch("nosuchhost")
        end

        assert_nil(node, "Got a node for a non-existent host")

        # Now add a base node with some classes and parameters
        nodetable["base"] = [nil, %w{one two}, {"base" => "true"}]

        assert_nothing_raised do
            node = searcher.nodesearch("base")
        end

        assert_instance_of(SimpleNode, node, "Did not get node from ldap nodesearch")
        assert_equal("base", node.name, "node name was not set")

        assert_equal(%w{one two}, node.classes, "node classes were not set")
        assert_equal({"base" => "true"}, node.parameters, "node parameters were not set")

        # Now use a different with this as the base
        nodetable["middle"] = ["base", %w{three}, {"center" => "boo"}]
        assert_nothing_raised do
            node = searcher.nodesearch("middle")
        end

        assert_instance_of(SimpleNode, node, "Did not get node from ldap nodesearch")
        assert_equal("middle", node.name, "node name was not set")

        assert_equal(%w{one two three}.sort, node.classes.sort, "node classes were not set correctly with a parent node")
        assert_equal({"base" => "true", "center" => "boo"}, node.parameters, "node parameters were not set correctly with a parent node")

        # And one further, to make sure we fully recurse
        nodetable["top"] = ["middle", %w{four five}, {"master" => "far"}]
        assert_nothing_raised do
            node = searcher.nodesearch("top")
        end

        assert_instance_of(SimpleNode, node, "Did not get node from ldap nodesearch")
        assert_equal("top", node.name, "node name was not set")

        assert_equal(%w{one two three four five}.sort, node.classes.sort, "node classes were not set correctly with the top node")
        assert_equal({"base" => "true", "center" => "boo", "master" => "far"}, node.parameters, "node parameters were not set correctly with the top node")
    end
end

class LdapNodeTest < PuppetTest::TestCase
    include NodeTesting
    include PuppetTest::ServerTest
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
    AST = Puppet::Parser::AST
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

        searcher = Object.new
        searcher.extend(Node.node_source(:ldap))

        ldapconnect()

        # Make sure we get nil and nil back when we search for something missing
        parent, classes, parameters = nil
        assert_nothing_raised do
            parent, classes, parameters = searcher.ldapsearch("nosuchhost")
        end

        assert_nil(parent, "Got a parent for a non-existent host")
        assert_nil(classes, "Got classes for a non-existent host")

        # Make sure we can find 'culain' in ldap
        assert_nothing_raised do
            parent, classes, parameters = searcher.ldapsearch("culain")
        end

        node, realparent = ldaphost("culain")
        assert_equal(realparent, parent, "did not get correct parent node from ldap")
        assert_equal(node.classes, classes, "did not get correct ldap classes from ldap")
        assert_equal(node.parameters, parameters, "did not get correct ldap parameters from ldap")

        # Now compare when we specify the attributes to get.
        Puppet[:ldapattrs] = "cn"
        assert_nothing_raised do
            parent, classes, parameters = searcher.ldapsearch("culain")
        end
        assert_equal(realparent, parent, "did not get correct parent node from ldap")
        assert_equal(node.classes, classes, "did not get correct ldap classes from ldap")

        list = %w{cn puppetclass parentnode dn}
        should = node.parameters.inject({}) { |h, a| h[a[0]] = a[1] if list.include?(a[0]); h }
        assert_equal(should, parameters, "did not get correct ldap parameters from ldap")
    end
end

class LdapReconnectTests < PuppetTest::TestCase
    include NodeTesting
    include PuppetTest::ServerTest
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
    AST = Puppet::Parser::AST
    confine "Not running on culain as root" => (Puppet::Util::SUIDManager.uid == 0 and Facter.value("hostname") == "culain")

    def test_ldapreconnect
        Puppet[:ldapbase] = "ou=hosts, dc=madstop, dc=com"
        Puppet[:ldapnodes] = true

        searcher = Object.new
        searcher.extend(Node.node_source(:ldap))
        hostname = "culain.madstop.com"

        # look for our host
        assert_nothing_raised {
            parent, classes = searcher.nodesearch(hostname)
        }

        # Now restart ldap
        system("/etc/init.d/slapd restart 2>/dev/null >/dev/null")
        sleep(1)

        # and look again
        assert_nothing_raised {
            parent, classes = searcher.nodesearch(hostname)
        }

        # Now stop ldap
        system("/etc/init.d/slapd stop 2>/dev/null >/dev/null")
        cleanup do
            system("/etc/init.d/slapd start 2>/dev/null >/dev/null")
        end

        # And make sure we actually fail here
        assert_raise(Puppet::Error) {
            parent, classes = searcher.nodesearch(hostname)
        }
    end
end
