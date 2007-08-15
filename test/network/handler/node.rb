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
        searcher.meta_def(:newnode) do |name, *args|
            SimpleNode.new(name, *args)
        end
        searcher
    end

    def mk_node_source
        @node_info = {}
        @node_source = Node.newnode_source(:testing, :fact_merge => true) do
            def nodesearch(key)
                if info = @node_info[key]
                    SimpleNode.new(info)
                else
                    nil
                end
            end
        end
        Puppet[:node_source] = "testing"

        cleanup { Node.rm_node_source(:testing) }
    end
end

class TestNodeHandler < Test::Unit::TestCase
    include NodeTesting

    def setup
        super
        mk_node_source
    end

    # Make sure that the handler includes the appropriate
    # node source.
    def test_initialize
        # First try it when passing in the node source
        handler = nil
        assert_nothing_raised("Could not specify a node source") do
            handler = Node.new(:Source => :testing)
        end
        assert(handler.metaclass.included_modules.include?(@node_source), "Handler did not include node source")

        # Now use the Puppet[:node_source]
        Puppet[:node_source] = "testing"
        assert_nothing_raised("Could not specify a node source") do
            handler = Node.new()
        end
        assert(handler.metaclass.included_modules.include?(@node_source), "Handler did not include node source")

        # And make sure we throw an exception when an invalid node source is used
        assert_raise(ArgumentError, "Accepted an invalid node source") do
            handler = Node.new(:Source => "invalid")
        end
    end

    # Make sure we can find and we cache a fact handler.
    def test_fact_handler
        handler = Node.new
        fhandler = nil
        assert_nothing_raised("Could not retrieve the fact handler") do
            fhandler = handler.send(:fact_handler)
        end
        assert_instance_of(Puppet::Network::Handler::Facts, fhandler, "Did not get a fact handler back")

        # Now call it again, making sure we're caching the value.
        fhandler2 = nil
        assert_nothing_raised("Could not retrieve the fact handler") do
            fhandler2 = handler.send(:fact_handler)
        end
        assert_instance_of(Puppet::Network::Handler::Facts, fhandler2, "Did not get a fact handler on the second run")
        assert_equal(fhandler.object_id, fhandler2.object_id, "Did not cache fact handler")
    end

    # Make sure we can get node facts from the fact handler.
    def test_node_facts
        # Check the case where we find the node.
        handler = Node.new
        fhandler = handler.send(:fact_handler)
        fhandler.expects(:get).with("present").returns("a" => "b")

        result = nil
        assert_nothing_raised("Could not get facts from fact handler") do
            result = handler.send(:node_facts, "present")
        end
        assert_equal({"a" => "b"}, result, "Did not get correct facts back")

        # Now try the case where the fact handler knows nothing about our host
        fhandler.expects(:get).with('missing').returns(nil)
        result = nil
        assert_nothing_raised("Could not get facts from fact handler when host is missing") do
            result = handler.send(:node_facts, "missing")
        end
        assert_equal({}, result, "Did not get empty hash when no facts are known")
    end

    # Test our simple shorthand
    def test_newnode
        SimpleNode.expects(:new).with("stuff")
        handler = Node.new
        handler.send(:newnode, "stuff")
    end

    # Make sure we can build up the correct node names to search for
    def test_node_names
        handler = Node.new

        # Verify that the handler asks for the facts if we don't pass them in
        handler.expects(:node_facts).with("testing").returns({})
        handler.send(:node_names, "testing")

        handler = Node.new
        # Test it first with no parameters
        assert_equal(%w{testing}, handler.send(:node_names, "testing"), "Node names did not default to an array including just the node name")

        # Now test it with a fully qualified name
        assert_equal(%w{testing.domain.com testing}, handler.send(:node_names, "testing.domain.com"),
            "Fully qualified names did not get turned into multiple names, longest first")

        # And try it with a short name + domain fact
        assert_equal(%w{testing host.domain.com host}, handler.send(:node_names, "testing", "domain" => "domain.com", "hostname" => "host"),
            "The domain fact was not used to build up an fqdn")

        # And with an fqdn
        assert_equal(%w{testing host.domain.com host}, handler.send(:node_names, "testing", "fqdn" => "host.domain.com"),
            "The fqdn was not used")

        # And make sure the fqdn beats the domain
        assert_equal(%w{testing host.other.com host}, handler.send(:node_names, "testing", "domain" => "domain.com", "fqdn" => "host.other.com"),
            "The domain was used in preference to the fqdn")
    end

    # Make sure we can retrieve a whole node by name.
    def test_details_when_we_find_nodes
        handler = Node.new

        # Make sure we get the facts first
        handler.expects(:node_facts).with("host").returns(:facts)

        # Find the node names
        handler.expects(:node_names).with("host", :facts).returns(%w{a b c})

        # Iterate across them
        handler.expects(:nodesearch).with("a").returns(nil)
        handler.expects(:nodesearch).with("b").returns(nil)

        # Create an example node to return
        node = SimpleNode.new("host")

        # Make sure its source is set
        node.expects(:source=).with(handler.source)

        # And that the names are retained
        node.expects(:names=).with(%w{a b c})

        # And make sure we actually get it back
        handler.expects(:nodesearch).with("c").returns(node)

        handler.expects(:fact_merge?).returns(true)

        # Make sure we merge the facts with the node's parameters.
        node.expects(:fact_merge).with(:facts)

        # Now call the method
        result = nil
        assert_nothing_raised("could not call 'details'") do
            result = handler.details("host")
        end
        assert_equal(node, result, "Did not get correct node back")
    end

    # But make sure we pass through to creating default nodes when appropriate.
    def test_details_using_default_node
        handler = Node.new

        # Make sure we get the facts first
        handler.expects(:node_facts).with("host").returns(:facts)

        # Find the node names
        handler.expects(:node_names).with("host", :facts).returns([])

        # Create an example node to return
        node = SimpleNode.new("host")

        # Make sure its source is set
        node.expects(:source=).with(handler.source)

        # And make sure we actually get it back
        handler.expects(:nodesearch).with("default").returns(node)

        # This time, have it return false
        handler.expects(:fact_merge?).returns(false)

        # And because fact_merge was false, we don't merge them.
        node.expects(:fact_merge).never

        # Now call the method
        result = nil
        assert_nothing_raised("could not call 'details'") do
            result = handler.details("host")
        end
        assert_equal(node, result, "Did not get correct node back")
    end

    # Make sure our handler behaves rationally when it comes to getting environment data.
    def test_environment
        # What happens when we can't find the node
        handler = Node.new
        handler.expects(:details).with("fake").returns(nil)

        result = nil
        assert_nothing_raised("Could not call 'Node.environment'") do
            result = handler.environment("fake")
        end
        assert_nil(result, "Got an environment for a node we could not find")

        # Now for nodes we can find
        handler = Node.new
        node = SimpleNode.new("fake")
        handler.expects(:details).with("fake").returns(node)
        node.expects(:environment).returns("dev")

        result = nil
        assert_nothing_raised("Could not call 'Node.environment'") do
            result = handler.environment("fake")
        end
        assert_equal("dev", result, "Did not get environment back")
    end

    # Make sure our handler behaves rationally when it comes to getting parameter data.
    def test_parameters
        # What happens when we can't find the node
        handler = Node.new
        handler.expects(:details).with("fake").returns(nil)

        result = nil
        assert_nothing_raised("Could not call 'Node.parameters'") do
            result = handler.parameters("fake")
        end
        assert_nil(result, "Got parameters for a node we could not find")

        # Now for nodes we can find
        handler = Node.new
        node = SimpleNode.new("fake")
        handler.expects(:details).with("fake").returns(node)
        node.expects(:parameters).returns({"a" => "b"})

        result = nil
        assert_nothing_raised("Could not call 'Node.parameters'") do
            result = handler.parameters("fake")
        end
        assert_equal({"a" => "b"}, result, "Did not get parameters back")
    end

    def test_classes
        # What happens when we can't find the node
        handler = Node.new
        handler.expects(:details).with("fake").returns(nil)

        result = nil
        assert_nothing_raised("Could not call 'Node.classes'") do
            result = handler.classes("fake")
        end
        assert_nil(result, "Got classes for a node we could not find")

        # Now for nodes we can find
        handler = Node.new
        node = SimpleNode.new("fake")
        handler.expects(:details).with("fake").returns(node)
        node.expects(:classes).returns(%w{yay foo})

        result = nil
        assert_nothing_raised("Could not call 'Node.classes'") do
            result = handler.classes("fake")
        end
        assert_equal(%w{yay foo}, result, "Did not get classes back")
    end

    # We reuse the filetimeout for the node caching timeout.
    def test_node_caching
        handler = Node.new

        node = Object.new
        node.metaclass.instance_eval do
            attr_accessor :time, :name
        end
        node.time = Time.now
        node.name = "yay"

        # Make sure caching works normally
        assert_nothing_raised("Could not cache node") do
            handler.send(:cache, node)
        end
        assert_equal(node.object_id, handler.send(:cached?, "yay").object_id, "Did not get node back from the cache")

        # Now set the node's time to be a long time ago
        node.time = Time.now - 50000
        assert(! handler.send(:cached?, "yay"), "Timed-out node was returned from cache")
    end
end

class TestSimpleNode < Test::Unit::TestCase
    include NodeTesting

    # Make sure we get all the defaults correctly.
    def test_simplenode_initialize
        node = nil
        assert_nothing_raised("could not create a node without classes or parameters") do
            node = SimpleNode.new("testing")
        end
        assert_equal("testing", node.name, "Did not set name correctly")
        assert_equal({}, node.parameters, "Node parameters did not default correctly")
        assert_equal([], node.classes, "Node classes did not default correctly")
        assert_instance_of(Time, node.time, "Did not set the creation time")

        # Now test it with values for both
        params = {"a" => "b"}
        classes = %w{one two}
        assert_nothing_raised("could not create a node with classes and parameters") do
            node = SimpleNode.new("testing", :parameters => params, :classes => classes)
        end
        assert_equal("testing", node.name, "Did not set name correctly")
        assert_equal(params, node.parameters, "Node parameters did not get set correctly")
        assert_equal(classes, node.classes, "Node classes did not get set correctly")

        # And make sure a single class gets turned into an array
        assert_nothing_raised("could not create a node with a class as a string") do
            node = SimpleNode.new("testing", :classes => "test")
        end
        assert_equal(%w{test}, node.classes, "A node class string was not converted to an array")

        # Make sure we get environments
        assert_nothing_raised("could not create a node with an environment") do
            node = SimpleNode.new("testing", :environment => "test")
        end
        assert_equal("test", node.environment, "Environment was not set")

        # Now make sure we get the default env
        Puppet[:environment] = "prod"
        assert_nothing_raised("could not create a node with no environment") do
            node = SimpleNode.new("testing")
        end
        assert_equal("prod", node.environment, "Did not get default environment")

        # But that it stays nil if there's no default env set
        Puppet[:environment] = ""
        assert_nothing_raised("could not create a node with no environment and no default env") do
            node = SimpleNode.new("testing")
        end
        assert_nil(node.environment, "Got a default env when none was set")

    end

    # Verify that the node source wins over facter.
    def test_fact_merge
        node = SimpleNode.new("yay", :parameters => {"a" => "one", "b" => "two"})

        assert_nothing_raised("Could not merge parameters") do
            node.fact_merge("b" => "three", "c" => "yay")
        end
        params = node.parameters
        assert_equal("one", params["a"], "Lost nodesource parameters in parameter merge")
        assert_equal("two", params["b"], "Overrode nodesource parameters in parameter merge")
        assert_equal("yay", params["c"], "Did not get facts in parameter merge")
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
            assert(! Node.const_defined?("Testing"), "Did not remove constant")
        end
    end
    
    def test_external_node_source
        source = Node.node_source(:external)
        assert(source, "Could not find external node source")
        mapper = mk_node_mapper
        searcher = mk_searcher(:external)
        assert(searcher.fact_merge?, "External node source does not merge facts")

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
        source = Node.node_source(:ldap)
        assert(source, "Could not find ldap node source")
        searcher = mk_searcher(:ldap)
        assert(searcher.fact_merge?, "LDAP node source does not merge facts")

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

    # Make sure we always get a node back from the 'none' nodesource.
    def test_nodesource_none
        source = Node.node_source(:none)
        assert(source, "Could not find 'none' node source")
        searcher = mk_searcher(:none)
        assert(searcher.fact_merge?, "'none' node source does not merge facts")

        # Run a couple of node names through it
        node = nil
        %w{192.168.0.1 0:0:0:3:a:f host host.domain.com}.each do |name|
            assert_nothing_raised("Could not create an empty node with name '%s'" % name) do
                node = searcher.nodesearch(name)
            end
            assert_instance_of(SimpleNode, node, "Did not get a simple node back for %s" % name)
            assert_equal(name, node.name, "Name was not set correctly")
        end
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
