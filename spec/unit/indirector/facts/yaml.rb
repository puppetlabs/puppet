#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector'
require 'puppet/node/facts'
require 'puppettest'

describe Puppet::Indirector.terminus(:facts, :yaml), " when managing facts" do
    # For cleanup mechanisms.
    include PuppetTest

    # LAK:FIXME It seems like I really do have to hit the filesystem
    # here, since, like, that's what I'm testing.  Is there another/better
    # way to do this?
    before do
        @store = Puppet::Indirector.terminus(:facts, :yaml).new
        setup # Grr, stupid rspec
        Puppet[:yamlfactdir] = tempfile
        Dir.mkdir(Puppet[:yamlfactdir])
    end

    it "should store facts in YAML in the yamlfactdir" do
        values = {"one" => "two", "three" => "four"}
        facts = Puppet::Node::Facts.new("node", values)
        @store.save(facts)

        # Make sure the file exists
        path = File.join(Puppet[:yamlfactdir], facts.name) + ".yaml"
        File.exists?(path).should be_true

        # And make sure it's right
        newvals = YAML.load(File.read(path))

        # We iterate over them, because the store might add extra values.
        values.each do |name, value|
            newvals[name].should == value
        end
    end

    it "should retrieve values from disk" do
        values = {"one" => "two", "three" => "four"}

        # Create the file.
        path = File.join(Puppet[:yamlfactdir], "node") + ".yaml"
        File.open(path, "w") do |f|
            f.print values.to_yaml
        end

        facts = Puppet::Node::Facts.find('node')
        facts.should be_instance_of(Puppet::Node::Facts)

        # We iterate over them, because the store might add extra values.
        values.each do |name, value|
            facts.values[name].should == value
        end
    end

    after do
        teardown
    end
end
