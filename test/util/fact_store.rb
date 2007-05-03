#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-05-02.
#  Copyright (c) 2007. All rights reserved.

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet/util/fact_store'

class TestFactStore < Test::Unit::TestCase
	include PuppetTest
	
	def test_new_fact_store
        klass = nil
        assert_nothing_raised("Could not create fact store") do
            klass = Puppet::Util::FactStore.newstore(:yay) do
            end
        end

        assert_equal(klass, Puppet::Util::FactStore.store(:yay), "Did not get created store back by name")
    end

    def test_yaml_store
        yaml = Puppet::Util::FactStore.store(:yaml)
        assert(yaml, "Could not retrieve yaml store")

        name = "node"
        facts = {"a" => :b, :c => "d", :e => :f, "g" => "h"}

        store = nil
        assert_nothing_raised("Could not create YAML store instance") do
            store = yaml.new 
        end

        assert_nothing_raised("Could not store host facts") do
            store.set(name, facts)
        end

        dir = Puppet[:yamlfactdir]

        file = File.join(dir, name + ".yaml")
        assert(FileTest.exists?(file), "Did not create yaml file for node")

        text = File.read(file)
        newfacts = nil
        assert_nothing_raised("Could not deserialize yaml") do
            newfacts = YAML::load(text)
        end

        # Don't directly compare the hashes, because there might be extra
        # data stored in the client hash
        facts.each do |var, value|
            assert_equal(value, newfacts[var], "Value for %s changed during storage" % var)
        end

        # Now make sure the facts get retrieved correctly
        assert_nothing_raised("Could not retrieve facts") do
            newfacts = store.get(name)
        end

        # Now make sure the hashes are equal, since internal facts should not be returned.
        assert_equal(facts, newfacts, "Retrieved facts are not equal")
    end
end

# $Id$
