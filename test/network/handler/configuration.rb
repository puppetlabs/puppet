#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet/network/handler/configuration'

class TestHandlerConfiguration < Test::Unit::TestCase
	include PuppetTest

    Config = Puppet::Network::Handler.handler(:configuration)

    # Check all of the setup stuff.
    def test_initialize
        config = nil
        assert_nothing_raised("Could not create local config") do
            config = Config.new(:Local => true)
        end

        assert(config.local?, "Config is not considered local after being started that way")
    end

    # Test creation/returning of the interpreter
    def test_interpreter
        config = Config.new

        # First test the defaults
        config.expects(:create_interpreter).returns(:interp)
        assert_equal(:interp, config.send(:interpreter), "Did not return the interpreter")

        # Now run it again and make sure we get the same thing
        assert_equal(:interp, config.send(:interpreter), "Did not cache the interpreter")
    end

    def test_create_interpreter
        config = Config.new(:Local => false)
        args = {}

        # Try it first with defaults.
        Puppet::Parser::Interpreter.expects(:new).returns(:interp)
        assert_equal(:interp, config.send(:create_interpreter), "Did not return the interpreter")
    end

    # Make sure node objects get appropriate data added to them.
    def test_add_node_data
        # First with no classes
        config = Config.new

        fakenode = Object.new
        # Set the server facts to something
        config.instance_variable_set("@server_facts", :facts)
        fakenode.expects(:merge).with(:facts)
        config.send(:add_node_data, fakenode)

        # Now try it with classes.
        config.classes = %w{a b}
        list = []
        fakenode = Object.new
        fakenode.expects(:merge).with(:facts)
        fakenode.expects(:classes).returns(list).times(2)
        config.send(:add_node_data, fakenode)
        assert_equal(%w{a b}, list, "Did not add classes to node")
    end

    def test_compile
        config = Config.new

        # First do a local
        node = mock 'node'
        node.stubs(:name).returns(:mynode)
        node.stubs(:environment).returns(:myenv)

        interp = mock 'interpreter'
        interp.stubs(:environment)
        interp.expects(:compile).with(node).returns(:config)
        config.expects(:interpreter).returns(interp)

        Puppet.expects(:notice) # The log message from benchmarking

        assert_equal(:config, config.send(:compile, node), "Did not return config")
        
        # Now try it non-local
        node = mock 'node'
        node.stubs(:name).returns(:mynode)
        node.stubs(:environment).returns(:myenv)

        interp = mock 'interpreter'
        interp.stubs(:environment)
        interp.expects(:compile).with(node).returns(:config)

        config = Config.new(:Local => true)
        config.expects(:interpreter).returns(interp)

        assert_equal(:config, config.send(:compile, node), "Did not return config")
    end

    def test_set_server_facts
        config = Config.new
        assert_nothing_raised("Could not call :set_server_facts") do
            config.send(:set_server_facts)
        end
        facts = config.instance_variable_get("@server_facts")
        %w{servername serverversion serverip}.each do |fact|
            assert(facts.include?(fact), "Config did not set %s fact" % fact)
        end
    end

    def test_translate
        # First do a local config
        config = Config.new(:Local => true)
        assert_equal(:plain, config.send(:translate, :plain), "Attempted to translate local config")

        # Now a non-local
        config = Config.new(:Local => false)
        assert(! config.local?, "Config wrongly thinks it's local")
        obj = mock 'dumpee'
        yamld = mock 'yaml'
        obj.expects(:to_yaml).with(:UseBlock => true).returns(yamld)
        CGI.expects(:escape).with(yamld).returns(:translated)
        assert_equal(:translated, config.send(:translate, obj), "Did not return translated config")
    end

    # Check that we're storing the node freshness into the rails db.  Hackilicious.
    def test_update_node_check
        # This is stupid.
        config = Config.new
        node = Object.new
        node.expects(:name).returns(:hostname)
        now = Object.new
        Time.expects(:now).returns(now)
        host = Object.new
        host.expects(:last_freshcheck=).with(now)
        host.expects(:save)

        # Only test the case where rails is there
        Puppet[:storeconfigs] = true
        Puppet.features.expects(:rails?).returns(true)
        Puppet::Rails.expects(:connect)
        Puppet::Rails::Host.expects(:find_or_create_by_name).with(:hostname).returns(host)

        config.send(:update_node_check, node)
    end

    def test_version
        # First try the case where we can't look up the node
        config = Config.new
        node = Object.new
        Puppet::Node.stubs(:search).with(:client).returns(false, node)
        interp = Object.new
        assert_instance_of(Bignum, config.version(:client), "Did not return configuration version")

        # And then when we find the node.
        config = Config.new
        config.expects(:update_node_check).with(node)
        interp = Object.new
        interp.expects(:configuration_version).returns(:version)
        config.expects(:interpreter).returns(interp)
        assert_equal(:version, config.version(:client), "Did not return configuration version")
    end
end
