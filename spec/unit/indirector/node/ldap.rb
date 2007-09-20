#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'yaml'
require 'puppet/indirector'

describe Puppet::Indirector.terminus(:node, :ldap), " when searching for nodes" do
    require 'puppet/node'

    def setup
        Puppet.config[:external_nodes] = "/yay/ness"
        @searcher = Puppet::Indirector.terminus(:node, :ldap).new
        nodetable = {}
        @nodetable = nodetable
        # Override the ldapsearch definition, so we don't have to actually set it up.
        @searcher.meta_def(:ldapsearch) do |name|
            nodetable[name]
        end
    end

    it "should return nil for hosts that cannot be found" do
        @searcher.find("foo").should be_nil
    end

    it "should return Puppet::Node instances" do
        @nodetable["foo"] = [nil, %w{}, {}]
        @searcher.find("foo").should be_instance_of(Puppet::Node)
    end

    it "should set the node name" do
        @nodetable["foo"] = [nil, %w{}, {}]
        @searcher.find("foo").name.should == "foo"
    end

    it "should set the classes" do
        @nodetable["foo"] = [nil, %w{one two}, {}]
        @searcher.find("foo").classes.should == %w{one two}
    end

    it "should set the parameters" do
        @nodetable["foo"] = [nil, %w{}, {"one" => "two"}]
        @searcher.find("foo").parameters.should == {"one" => "two"}
    end

    it "should set classes and parameters from the parent node" do
        @nodetable["foo"] = ["middle", %w{one two}, {"one" => "two"}]
        @nodetable["middle"] = [nil, %w{three four}, {"three" => "four"}]
        node = @searcher.find("foo")
        node.classes.sort.should == %w{one two three four}.sort
        node.parameters.should == {"one" => "two", "three" => "four"}
    end

    it "should prefer child parameters to parent parameters" do
        @nodetable["foo"] = ["middle", %w{}, {"one" => "two"}]
        @nodetable["middle"] = [nil, %w{}, {"one" => "four"}]
        @searcher.find("foo").parameters["one"].should == "two"
    end

    it "should recurse indefinitely through parent relationships" do
        @nodetable["foo"] = ["middle", %w{one two}, {"one" => "two"}]
        @nodetable["middle"] = ["top", %w{three four}, {"three" => "four"}]
        @nodetable["top"] = [nil, %w{five six}, {"five" => "six"}]
        node = @searcher.find("foo")
        node.parameters.should == {"one" => "two", "three" => "four", "five" => "six"}
        node.classes.sort.should == %w{one two three four five six}.sort
    end

    # This can stay in the main test suite because it doesn't actually use ldapsearch,
    # it just overrides the method so it behaves as though it were hitting ldap.
    def test_ldap_nodesearch

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

describe Puppet::Indirector.terminus(:node, :ldap), " when interacting with ldap" do
    confine "LDAP is not available" => Puppet.features.ldap?
    confine "No LDAP test data for networks other than Luke's" => Facter.value(:domain) == "madstop.com"

    def ldapconnect

        @ldap = LDAP::Conn.new("ldap", 389)
        @ldap.set_option( LDAP::LDAP_OPT_PROTOCOL_VERSION, 3 )
        @ldap.simple_bind("", "")

        return @ldap
    end

    def ldaphost(name)
        node = Puppet::Node.new(name)
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

    it "should have tests" do
        raise ArgumentError
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

describe Puppet::Indirector.terminus(:node, :ldap), " when connecting to ldap" do
    confine "Not running on culain as root" => (Puppet::Util::SUIDManager.uid == 0 and Facter.value("hostname") == "culain")

    it "should have tests" do
        raise ArgumentError
    end

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
