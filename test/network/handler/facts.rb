#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'mocha'
require 'puppet/network/handler/facts'

class TestFactsHandler < Test::Unit::TestCase
    include PuppetTest::ServerTest

    def setup
        super

        @class = Puppet::Network::Handler.handler(:facts)

        @@client_facts = {}

        unless Puppet::Util::FactStore.store(:testing)
            Puppet::Util::FactStore.newstore(:testing) do
                def get(node)
                    @@client_facts[node]
                end

                def set(node, facts)
                    @@client_facts[node] = facts
                end
            end
        end

        Puppet[:factstore] = :testing

        @handler = @class.new

        @facts = {:a => :b, :c => :d}
        @name = "foo"

        @backend = @handler.instance_variable_get("@backend")
    end

    def teardown
        @@client_facts.clear
    end

    def test_strip_internal
        @facts[:_puppet_one] = "yay"
        @facts[:_puppet_two] = "boo"
        @facts[:_puppetthree] = "foo"

        newfacts = nil
        assert_nothing_raised("Could not call strip_internal") do
            newfacts = @handler.send(:strip_internal, @facts)
        end

        [:_puppet_one, :_puppet_two, :_puppetthree].each do |name|
            assert(@facts.include?(name), "%s was removed in strip_internal from original hash" % name)
        end
        [:_puppet_one, :_puppet_two].each do |name|
            assert(! newfacts.include?(name), "%s was not removed in strip_internal" % name)
        end
        assert_equal("foo", newfacts[:_puppetthree], "_puppetthree was removed in strip_internal")
    end

    def test_add_internal
        newfacts = nil
        assert_nothing_raised("Could not call strip_internal") do
            newfacts = @handler.send(:add_internal, @facts)
        end

        assert_instance_of(Time, newfacts[:_puppet_timestamp], "Did not set timestamp in add_internal")
        assert(! @facts.include?(:_puppet_timestamp), "Modified original hash in add_internal")
    end

    def test_set
        newfacts = @facts.dup
        newfacts[:_puppet_timestamp] = Time.now
        @handler.expects(:add_internal).with(@facts).returns(newfacts)
        @backend.expects(:set).with(@name, newfacts).returns(nil)

        assert_nothing_raised("Could not set facts") do
            assert_nil(@handler.set(@name, @facts), "handler.set did not return nil")
        end
    end

    def test_get
        prefacts = @facts.dup
        prefacts[:_puppet_timestamp] = Time.now
        @@client_facts[@name] = prefacts
        @handler.expects(:strip_internal).with(prefacts).returns(@facts)
        @backend.expects(:get).with(@name).returns(prefacts)

        assert_nothing_raised("Could not retrieve facts") do
            assert_equal(@facts,  @handler.get(@name), "did not get correct answer from handler.get")
        end

        @handler = @class.new
        assert_nothing_raised("Failed to call 'get' with no stored facts") do
            @handler.get("nosuchname")
        end
    end

    def test_store_date
        time = Time.now
        @facts[:_puppet_timestamp] = time

        @handler.expects(:get).with(@name).returns(@facts)

        assert_equal(time.to_i, @handler.store_date(@name), "Did not retrieve timestamp correctly")
    end
end

# $Id$
