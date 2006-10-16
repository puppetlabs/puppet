#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/rails'
require 'puppettest'
require 'puppettest/railstesting'
require 'puppettest/resourcetesting'

class TestRailsResource < Test::Unit::TestCase
    include PuppetTest::RailsTesting
    include PuppetTest::ResourceTesting
    
    # Don't do any tests w/out this class
    if defined? ActiveRecord::Base
    # Create a resource param from a rails parameter
    def test_to_resource
        railsinit
        
        # We need a host for resources
        host = Puppet::Rails::Host.new(:name => "myhost")

        # Now build a resource
        resource = host.rails_resources.build(
            :title => "/tmp/to_resource", :restype => "file",
            :exported => true
        )

        # Now add some params
        {"owner" => "root", "mode" => "644"}.each do |param, value|
            resource.rails_parameters.build(
                :name => param, :value => value
            )
        end

        # Now save the whole thing
        host.save

        # Now, try to convert our resource to a real resource

        # We need a scope
        interp, scope, source = mkclassframing

        res = nil
        assert_nothing_raised do
            res = resource.to_resource(scope)
        end

        assert_instance_of(Puppet::Parser::Resource, res)

        assert_equal("root", res[:owner])
        assert_equal("644", res[:mode])
        assert_equal("/tmp/to_resource", res.title)
        assert_equal(source, res.source)
    end
    else
        $stderr.puts "Install Rails for Rails and Caching tests"
    end
end

# $Id$
